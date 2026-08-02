import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/election.dart';
import '../../models/voter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/election_provider.dart';
import '../../widgets/election_card.dart';
import '../login/login_screen.dart';
import 'candidate_selection_screen.dart';

class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key});

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<ElectionProvider>();
    final voterId = auth.voter?.voterId;
    if (voterId != null) {
      await provider.fetchEligibleElections(voterId);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ElectionProvider>();
    final voter = auth.voter;
    final elections = provider.elections;
    final loading = provider.loading;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: Palette.navyDeep,
            expandedHeight: voter != null ? 168 : 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: const Text(
                'Available Elections',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(gradient: Palette.navyGradient),
                child: voter != null
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(0, 56, 0, 0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _buildVoterBanner(voter),
                        ),
                      )
                    : null,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
            ],
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildContent(elections, loading, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildVoterBanner(Voter voter) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Palette.goldGradient,
              boxShadow: [
                BoxShadow(
                  color: Palette.gold.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                voter.initials,
                style: const TextStyle(
                  color: Palette.navyDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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
                  voter.fullName ?? 'Voter',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (voter.constituency != null &&
                    voter.constituency!.isNotEmpty)
                  Text(
                    voter.constituency!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (voter.hasVoted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Palette.success.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, color: Colors.white, size: 13),
                  SizedBox(width: 3),
                  Text(
                    'Voted',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<Election> elections,
    bool loading,
    ElectionProvider provider,
  ) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Palette.navy),
        ),
      );
    }

    if (provider.error != null && elections.isEmpty) {
      return _buildError(provider.error!, () => _load());
    }

    if (elections.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: Palette.navy,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: elections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final election = elections[index];
          return ElectionCard(
            election: election,
            showVoteButton: election.isActive,
            onVoteTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CandidateSelectionScreen(election: election),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Palette.error.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_outlined,
                  size: 42, color: Palette.error),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unable to load elections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.inkMuted, height: 1.4),
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
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Palette.hairline.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.how_to_vote_outlined,
                  size: 42, color: Palette.inkMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'No active elections right now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check back when an election is open in your constituency.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}