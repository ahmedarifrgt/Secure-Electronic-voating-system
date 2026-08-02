import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/dashboard_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/stat_card.dart';
import '../login/login_screen.dart';
import '../reports/results_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = context.read<DashboardProvider>();
    await provider.fetchStats();
  }

  Future<void> _onVerifyIntegrity() async {
    final provider = context.read<DashboardProvider>();
    final ok = await provider.verifyIntegrity();
    if (!mounted) return;
    if (ok && provider.verifyResult != null) {
      final r = provider.verifyResult!;
      _showResultDialog(
        'Integrity Verification',
        '${r.verifiedVotes} / ${r.totalVotes} votes verified',
        r.failedVotes == 0
            ? const Icon(Icons.check_circle, color: Palette.success, size: 48)
            : const Icon(Icons.warning_amber_rounded, color: Palette.error, size: 48),
        r.failedVotes > 0
            ? '${r.failedVotes} vote(s) failed integrity check'
            : 'All votes are cryptographically intact',
      );
    } else {
      _showError(provider.error ?? 'Verification failed');
    }
  }

  Future<void> _onPublishResults() async {
    // Show election picker dialog
    final provider = context.read<DashboardProvider>();
    await provider.fetchElections();
    if (!mounted) return;

    final elections = provider.elections
        .where((e) => e.status == 'Active')
        .toList();
    if (elections.isEmpty) {
      _showError('No active elections to publish');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Election to Publish'),
        children: elections
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e.name),
                  child: Text(e.name),
                ))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    final election = elections.firstWhere((e) => e.name == selected);
    final ok = await provider.publishResults(election.electionId);
    if (!mounted) return;
    if (ok) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(electionId: election.electionId),
        ),
      );
    } else {
      _showError(provider.error ?? 'Failed to publish results');
    }
  }

  void _showResultDialog(
    String title, String summary, Widget icon, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            Text(summary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(detail, style: const TextStyle(color: Palette.inkMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Palette.error),
    );
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;
    final loading = provider.loading;
    final verifying = provider.verifying;

    // Apply the overlay when verifying
    Widget body = _buildBody(stats, loading);
    if (verifying) {
      body = Stack(
        children: [
          body,
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
                        valueColor: AlwaysStoppedAnimation<Color>(Palette.gold),
                      ),
                      SizedBox(height: 16),
                      Text('Verifying votes…'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          body,
          // Logout button
          Positioned(
            top: 50,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DashboardStats? stats, bool loading) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(gradient: Palette.navyGradient),
              child: const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(top: 50, right: 20),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Palette.gold,
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: Palette.navyDeep,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildListDelegate([
                  if (stats == null)
                    for (int i = 0; i < 4; i++)
                      const _ShimmerCard()
                  else ...[
                    StatCard(
                      icon: Icons.people_alt_outlined,
                      value: '${stats.totalVoters}',
                      label: 'Total Voters',
                      accent: Palette.indigo,
                    ),
                    StatCard(
                      icon: Icons.person_pin_circle_outlined,
                      value: '${stats.activeVoters}',
                      label: 'Active Voters',
                      accent: Palette.indigo,
                    ),
                    StatCard(
                      icon: Icons.how_to_vote_outlined,
                      value: '${stats.ongoingElections}',
                      label: 'Ongoing Elections',
                      accent: Palette.gold,
                    ),
                    StatCard(
                      icon: Icons.fact_check_outlined,
                      value: '${stats.votesCast}',
                      label: 'Votes Cast',
                      accent: Palette.gold,
                    ),
                    StatCard(
                      icon: Icons.trending_up_rounded,
                      value: '${stats.turnoutPercentage.toStringAsFixed(1)}%',
                      label: 'Turnout',
                      accent: Palette.success,
                    ),
                    StatCard(
                      icon: Icons.error_outline_rounded,
                      value: '${stats.failedVerifications}',
                      label: 'Failed Verifications',
                      accent: Palette.error,
                      isAlert: true,
                    ),
                    StatCard(
                      icon: Icons.shield_outlined,
                      value: '${stats.spoofAttempts}',
                      label: 'Spoof Attempts',
                      accent: Palette.warning,
                      isAlert: true,
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
        // Action buttons
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.verified_outlined,
                        label: 'Verify Integrity',
                        onTap: _onVerifyIntegrity,
                        color: Palette.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.publish_outlined,
                        label: 'Publish Results',
                        onTap: _onPublishResults,
                        color: Palette.gold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.bar_chart_rounded,
                        label: 'View Results',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ResultsScreen(),
                            ),
                          );
                        },
                        color: Palette.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.refresh_rounded,
                        label: 'Refresh Data',
                        onTap: _loadStats,
                        color: Palette.navy,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A simple action button for the admin dashboard.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder while stats are loading.
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: Palette.cardDecoration,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38, height: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.hairline,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
          ),
          Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.hairline,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: SizedBox(width: 60, height: 24),
          ),
          SizedBox(height: 6),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.hairline,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: SizedBox(width: 80, height: 14),
          ),
        ],
      ),
    );
  }
}
