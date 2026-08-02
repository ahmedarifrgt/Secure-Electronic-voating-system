import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/election.dart';
import '../../providers/election_provider.dart';
import '../../widgets/candidate_card.dart';
import '../voting/vote_confirmation_screen.dart';

class CandidateSelectionScreen extends StatefulWidget {
  const CandidateSelectionScreen({super.key, required this.election});

  final Election election;

  @override
  State<CandidateSelectionScreen> createState() =>
      _CandidateSelectionScreenState();
}

class _CandidateSelectionScreenState extends State<CandidateSelectionScreen> {
  int? _selectedCandidateId;

  @override
  void initState() {
    super.initState();
    context.read<ElectionProvider>().fetchCandidates(widget.election.electionId);
  }

  Future<void> _continue() async {
    if (_selectedCandidateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a candidate to continue'),
          backgroundColor: Palette.error,
        ),
      );
      return;
    }

    final candidate = context
        .read<ElectionProvider>()
        .candidates
        .firstWhere((c) => c.candidateId == _selectedCandidateId);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoteConfirmationScreen(
          election: widget.election,
          candidate: candidate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ElectionProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.election.name)),
      body: Column(
        children: [
          Expanded(child: _buildContent(provider)),
          // Bottom continue bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      _selectedCandidateId == null ? null : _continue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    _selectedCandidateId == null
                        ? 'Select a candidate'
                        : 'Continue to Review',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ElectionProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  size: 56, color: Palette.inkMuted),
              const SizedBox(height: 12),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.inkMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => context
                    .read<ElectionProvider>()
                    .fetchCandidates(widget.election.electionId),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.candidates.isEmpty) {
      return const Center(
        child: Text(
          'No candidates available for this election',
          style: TextStyle(color: Palette.inkMuted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.candidates.length,
      itemBuilder: (context, index) {
        final candidate = provider.candidates[index];
        final selected = candidate.candidateId == _selectedCandidateId;
        return CandidateCard(
          candidate: candidate,
          isSelected: selected,
          onTap: () => setState(() {
            _selectedCandidateId = candidate.candidateId;
          }),
        );
      },
    );
  }
}
