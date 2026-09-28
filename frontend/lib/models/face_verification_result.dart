/// Models for the face-verification pipeline result, mirroring the
/// `verification` payload the backend returns from `/auth/login`.
class FaceVerificationResult {
  final bool passed;
  final double score;
  final double? distance;
  final double? confidence;
  final String? model;
  final String? detector;
  final double? threshold;
  final List<VerificationStage> stages;
  final String? mode;
  final String? error;

  const FaceVerificationResult({
    required this.passed,
    this.score = 0.0,
    this.distance,
    this.confidence,
    this.model,
    this.detector,
    this.threshold,
    this.stages = const [],
    this.mode,
    this.error,
  });

  factory FaceVerificationResult.fromJson(Map<String, dynamic> json) {
    final rawStages = json['stages'] as List<dynamic>? ?? const [];
    return FaceVerificationResult(
      passed: json['passed'] == true,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      model: json['model'] as String?,
      detector: json['detector'] as String?,
      threshold: (json['threshold'] as num?)?.toDouble(),
      stages: rawStages
          .whereType<Map<String, dynamic>>()
          .map(VerificationStage.fromJson)
          .toList(),
      mode: json['mode'] as String?,
      error: json['error'] as String?,
    );
  }

  /// Best human-readable confidence percentage (0–100).
  int get accuracyPercent {
    if (confidence != null) return (confidence! * 100).round();
    if (score > 0) return (score * 100).round();
    return 0;
  }

  /// Label for the model used (e.g. "Facenet", "ArcFace").
  String get modelLabel => model ?? 'DeepFace';

  bool get isMockMode => mode == 'mock';
}

/// A single stage of the verification pipeline.
class VerificationStage {
  final String stage;
  final bool passed;
  final Map<String, dynamic> details;

  const VerificationStage({
    required this.stage,
    required this.passed,
    this.details = const {},
  });

  factory VerificationStage.fromJson(Map<String, dynamic> json) {
    return VerificationStage(
      stage: json['stage'] as String? ?? 'unknown',
      passed: json['passed'] == true,
      details: (json['details'] as Map<String, dynamic>?) ?? const {},
    );
  }

  String get label {
    switch (stage) {
      case 'image_quality':
        return 'Image Quality';
      case 'face_tracking':
        return 'Face Detection';
      case 'liveness':
        return 'Liveness Check';
      case 'anti_spoof':
        return 'Anti-Spoofing';
      case 'deepfake':
        return 'Deepfake Detection';
      case 'identity':
        return 'Identity Match';
      default:
        return stage;
    }
  }
}

