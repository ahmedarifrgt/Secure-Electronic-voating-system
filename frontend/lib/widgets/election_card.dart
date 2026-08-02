import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../models/election.dart';

/// A card displaying an election's name, date range, and status badge.
/// Tapping the card triggers [onTap].
class ElectionCard extends StatelessWidget {
  const ElectionCard({
    super.key,
    required this.election,
    this.onTap,
    this.showVoteButton = false,
    this.onVoteTap,
    this.hasVoted = false,
  });

  final Election election;
  final VoidCallback? onTap;
  final bool showVoteButton;
  final VoidCallback? onVoteTap;
  final bool hasVoted;

  Color get _statusColor {
    switch (election.status) {
      case 'Active':
        return Palette.success;
      case 'Completed':
        return Palette.inkMuted;
      default:
        return Palette.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: Palette.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Palette.navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.how_to_vote_outlined,
                    color: Palette.navy,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        election.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      if (election.description != null &&
                          election.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            election.description!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Palette.inkMuted,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    election.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            // Date row
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Palette.inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    election.dateRangeLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Palette.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            // Vote button
            if (showVoteButton && !hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onVoteTap,
                    icon: const Icon(Icons.how_to_vote, size: 18),
                    label: const Text('Cast Your Vote'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Palette.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            if (hasVoted)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 18, color: Palette.success),
                    SizedBox(width: 6),
                    Text(
                      'You have voted in this election',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Palette.success,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
