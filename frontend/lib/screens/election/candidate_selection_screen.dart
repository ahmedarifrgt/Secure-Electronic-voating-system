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
        SnackBar(
          content: const Text('Please select a candidate to continue'),
          backgroundColor: Palette.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
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
      backgroundColor: const Color(0xFFF5F6F9),
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: Palette.navyGradient),
        ),
        titleSpacing: 20,
        title: Text(
          widget.election.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildInstructionBanner(provider),
          Expanded(child: _buildContent(provider)),
          // Bottom continue bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.navy,
                    disabledBackgroundColor: Palette.hairline,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Palette.inkMuted,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed:
                      _selectedCandidateId == null ? null : _continue,
                  icon: Icon(
                    _selectedCandidateId == null
                        ? Icons.touch_app_outlined
                        : Icons.arrow_forward_rounded,
                  ),
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

  /// Small banner reminding the voter what to do, with a live candidate count.
  Widget _buildInstructionBanner(ElectionProvider provider) {
    if (provider.loading || provider.candidates.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Palette.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.how_to_vote_outlined,
                size: 17, color: Palette.gold),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap a candidate to select them',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Palette.navy,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Palette.hairline.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${provider.candidates.length} candidates',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Palette.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ElectionProvider provider) {
    if (provider.loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Palette.navy),
        ),
      );
    }

    if (provider.error != null && provider.candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Palette.error.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_outlined,
                    size: 40, color: Palette.error),
              ),
              const SizedBox(height: 20),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Palette.inkMuted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.navy,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context
                    .read<ElectionProvider>()
                    .fetchCandidates(widget.election.electionId),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.candidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Palette.hairline.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_outlined,
                    size: 40, color: Palette.inkMuted),
              ),
              const SizedBox(height: 20),
              const Text(
                'No candidates available for this election',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.inkMuted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: provider.candidates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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