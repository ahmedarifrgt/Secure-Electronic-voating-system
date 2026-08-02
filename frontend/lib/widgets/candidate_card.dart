import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/candidate.dart';

/// A card representing a candidate the voter can select.
///
/// [isSelected] highlights the card with the navy/gold accent.
/// [showVoteCount] optionally shows a vote count (for results display).
class CandidateCard extends StatelessWidget {
  const CandidateCard({
    super.key,
    required this.candidate,
    this.isSelected = false,
    this.onTap,
    this.showVoteCount = false,
    this.voteCount,
    this.voteRatio,
  });

  final Candidate candidate;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showVoteCount;
  final int? voteCount;
  final double? voteRatio; // 0..1 for proportional bar

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Palette.navy.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Palette.gold : Palette.hairline,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Palette.navy.withOpacity(isSelected ? 0.1 : 0.06),
              blurRadius: isSelected ? 20 : 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? Palette.goldGradient
                        : const LinearGradient(
                            colors: [Palette.indigo, Palette.navy],
                          ),
                  ),
                  child: Center(
                    child: Text(
                      candidate.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + party
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      if (candidate.party != null &&
                          candidate.party!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            candidate.party!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Palette.inkMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showVoteCount && voteCount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.navy.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$voteCount',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Palette.navy,
                      ),
                    ),
                  ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Palette.gold, size: 24),
              ],
            ),
            // Vote bar (for results)
            if (showVoteCount && voteRatio != null && voteRatio! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: voteRatio!.clamp(0.0, 1.0),
                    backgroundColor: Palette.hairline,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Palette.gold),
                    minHeight: 6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
