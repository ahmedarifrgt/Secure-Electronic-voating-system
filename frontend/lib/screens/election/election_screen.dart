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
      appBar: AppBar(
        title: const Text('Available Elections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Voter identity banner
          if (voter != null) _buildVoterBanner(voter),
          // Content
          Expanded(child: _buildContent(elections, loading, provider)),
        ],
      ),
    );
  }

  Widget _buildVoterBanner(Voter voter) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: Palette.navyGradient,
      ),
      child: Row(
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
                ),
                if (voter.constituency != null &&
                    voter.constituency!.isNotEmpty)
                  Text(
                    voter.constituency!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          if (voter.hasVoted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Palette.success.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Voted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && elections.isEmpty) {
      return _buildError(provider.error!, () => _load());
    }

    if (elections.isEmpty) {
      return const _EmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: elections.length,
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
            const Icon(Icons.cloud_off_outlined,
                size: 56, color: Palette.inkMuted),
            const SizedBox(height: 12),
            const Text(
              'Unable to load elections',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.inkMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote_outlined,
                size: 56, color: Palette.inkMuted),
            SizedBox(height: 12),
            Text(
              'No active elections right now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            Text(
              'Check back when an election is open in your constituency.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
