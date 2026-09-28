import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/face_verification_result.dart';

/// A single row for one stage of the verification pipeline.
///
/// Used inside the [VerificationResultSheet] to display each stage
/// (image quality, liveness, anti-spoof, identity match, …) with its
/// pass/fail status and optional detail text.
class VerificationStageCard extends StatelessWidget {
  const VerificationStageCard({super.key, required this.stage});

  final VerificationStage stage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            stage.passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: stage.passed ? Palette.success : Palette.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stage.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Palette.ink,
              ),
            ),
          ),
          if (stage.details.isNotEmpty) ...[
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                stage.details.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                style: const TextStyle(
                  fontSize: 11,
                  color: Palette.inkMuted,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
