import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../election/election_screen.dart';

/// Shown after a vote is successfully cast.
/// Displays the anonymous vote token (receipt) the voter can keep.
class VoteSuccessScreen extends StatelessWidget {
  const VoteSuccessScreen({
    super.key,
    required this.electionName,
    required this.candidateName,
    this.voteToken,
  });

  final String electionName;
  final String candidateName;
  final String? voteToken;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.navyDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success badge
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Palette.goldGradient,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 56,
                      color: Palette.navyDeep,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'VOTE CAST SUCCESSFULLY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    electionName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Receipt card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR VOTE RECEIPT',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: Palette.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _receiptRow('Candidate', candidateName),
                        const SizedBox(height: 10),
                        if (voteToken != null) ...[
                          const Divider(),
                          const SizedBox(height: 10),
                          _receiptRow('Vote Token', voteToken!, isToken: true),
                          const SizedBox(height: 8),
                          const Text(
                            'Keep this token to verify your vote later. It is anonymous.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Palette.inkMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ElectionScreen(),
                          ),
                          (route) => route.isFirst,
                        );
                      },
                      icon: const Icon(Icons.how_to_vote_outlined),
                      label: const Text('Back to Elections'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.gold,
                        foregroundColor: Palette.navyDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isToken = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Palette.inkMuted,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: isToken ? 12.5 : 14,
              fontWeight: FontWeight.w600,
              color: Palette.ink,
              fontFamily: isToken ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}


