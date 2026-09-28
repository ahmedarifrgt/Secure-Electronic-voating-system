import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/face_verification_result.dart';
import 'accuracy_gauge.dart';
import 'verification_stage_card.dart';

/// A bottom sheet that summarises the face-verification pipeline result.
///
/// Displays:
/// - A circular gauge showing the overall confidence score.
/// - A per-stage breakdown (image quality, liveness, anti-spoof, …).
/// - Model / detector metadata.
void showVerificationResultSheet(
  BuildContext context,
  FaceVerificationResult result,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => VerificationResultSheet(result: result),
  );
}

class VerificationResultSheet extends StatelessWidget {
  const VerificationResultSheet({super.key, required this.result});

  final FaceVerificationResult result;

  @override
  Widget build(BuildContext context) {
    // Using a DraggableScrollableSheet gives the user control over the sheet height.
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Palette.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.passed ? Icons.verified_rounded : Icons.warning_rounded,
                      color: result.passed ? Palette.success : Palette.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      result.passed ? 'Verification Passed' : 'Verification Failed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: result.passed ? Palette.success : Palette.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Gauge
              Center(
                child: AccuracyGauge(
                  percent: result.accuracyPercent,
                  size: 140,
                  label: result.passed ? 'Matched' : 'Mismatch',
                  subtitle: result.isMockMode
                      ? 'Mock mode — no DeepFace model loaded'
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Distance / confidence row
              if (result.distance != null || result.confidence != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (result.distance != null)
                        _MetaChip(label: 'Distance', value: result.distance!.toStringAsFixed(4)),
                      if (result.confidence != null)
                        _MetaChip(
                          label: 'Confidence',
                          value: '${(result.confidence! * 100).toStringAsFixed(1)}%',
                        ),
                    ],
                  ),
                ),

              // Error message
              if (result.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Error: ${result.error}',
                    style: const TextStyle(color: Palette.error, fontSize: 13),
                  ),
                ),

              // Model metadata
              _MetaRow(label: 'Model', value: result.modelLabel),
              if (result.detector != null)
                _MetaRow(label: 'Detector', value: result.detector!),
              if (result.threshold != null)
                _MetaRow(label: 'Threshold', value: result.threshold.toString()),
              if (result.mode != null)
                _MetaRow(label: 'Mode', value: result.mode!),

              const SizedBox(height: 12),

              // Per-stage breakdown
              const Text(
                'Pipeline Stages',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              if (result.stages.isEmpty)
                const Text(
                  'No pipeline details available.',
                  style: TextStyle(color: Palette.inkMuted, fontSize: 13),
                )
              else
                ...result.stages.map(
                  (stage) => VerificationStageCard(stage: stage),
                ),

              const SizedBox(height: 16),

              // Close button
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Palette.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(color: Palette.inkMuted)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Palette.inkMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Palette.navy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Palette.inkMuted, fontSize: 12),
        ),
      ],
    );
  }
}
