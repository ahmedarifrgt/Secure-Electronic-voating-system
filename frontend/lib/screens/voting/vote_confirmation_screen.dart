import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/candidate.dart';
import '../../models/election.dart';
import '../../providers/election_provider.dart';
import 'vote_success_screen.dart';

class VoteConfirmationScreen extends StatefulWidget {
  const VoteConfirmationScreen({
    super.key,
    required this.election,
    required this.candidate,
  });

  final Election election;
  final Candidate candidate;

  @override
  State<VoteConfirmationScreen> createState() => _VoteConfirmationScreenState();
}

class _VoteConfirmationScreenState extends State<VoteConfirmationScreen> {
  Future<void> _confirmVote() async {
    final provider = context.read<ElectionProvider>();

    final ok = await provider.castVote(
      electionId: widget.election.electionId,
      candidateId: widget.candidate.candidateId,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VoteSuccessScreen(
            electionName: widget.election.name,
            candidateName: widget.candidate.name,
            voteToken: provider.voteToken,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to cast vote'),
          backgroundColor: Palette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.watch<ElectionProvider>().submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Your Vote')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Shield icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.gold.withOpacity(0.15),
                  ),
                  child: const Icon(
                    Icons.gpp_good_outlined,
                    size: 40,
                    color: Palette.gold,
                  ),
                ),
                const SizedBox(height: 24),

                // Election summary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: Palette.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ELECTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Palette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.election.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Palette.ink,
                        ),
                      ),
                      const Divider(height: 28),
                      const Text(
                        'YOUR SELECTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Palette.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: Palette.goldGradient,
                            ),
                            child: Center(
                              child: Text(
                                widget.candidate.initials,
                                style: const TextStyle(
                                  color: Palette.navyDeep,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.candidate.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.ink,
                                  ),
                                ),
                                if (widget.candidate.party != null &&
                                    widget.candidate.party!.isNotEmpty)
                                  Text(
                                    widget.candidate.party!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Palette.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Warning notice
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Palette.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Palette.error.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Palette.error, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your vote is encrypted and cannot be changed once submitted.',
                          style: TextStyle(
                            color: Palette.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (submitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Palette.gold),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Encrypting & casting your vote…',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: submitting ? null : _confirmVote,
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Confirm & Cast Vote'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
