import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/dashboard_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/election_provider.dart';
import '../../widgets/stat_card.dart';
import '../login/login_screen.dart';
import '../reports/results_screen.dart';
import '../dashboard/voter_list_screen.dart';
import '../dashboard/candidate_list_screen.dart';
import '../dashboard/add_candidate_screen.dart';

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

  Future<void> _onCreateElection() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => const _CreateElectionDialog(),
    );
    if (result == null || !mounted) return;

    final provider = context.read<ElectionProvider>();
    final created = await provider.createElection(
      name: result['name'] as String,
      description: result['description'] as String?,
      areaCode: result['areaCode'] as String?,
      constituency: result['constituency'] as String?,
      startDate: result['startDate'] as String,
      endDate: result['endDate'] as String,
      status: result['status'] as String,
    );
    if (!mounted) return;
    if (created != null) {
      // Show post-create options: view voters, or publish & view voters
      await _showPostCreateOptions(created);
      await _loadStats();
    } else {
      _showError(provider.error ?? 'Failed to create election');
    }
  }

  Future<void> _showPostCreateOptions(Map<String, dynamic> election) async {
    final id = election['election_id'] as int?;
    if (id == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Palette.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: Palette.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Election created',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: const Text(
          'What would you like to do next?',
          style: TextStyle(color: Palette.inkMuted, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'close'),
            child: const Text('Close'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, 'view'),
            child: const Text('View Voters'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Palette.gold,
              foregroundColor: Palette.navyDeep,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, 'publish'),
            child: const Text('Publish & Show'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'view') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VoterListScreen(electionId: id)),
      );
      return;
    }

    if (choice == 'publish') {
      final provider = context.read<ElectionProvider>();
      final ok = await provider.publishElection(id);
      if (!mounted) return;
      if (!ok) {
        _showError(provider.error ?? 'Failed to publish election');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VoterListScreen(electionId: id)),
      );
    }
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
            ? const Icon(Icons.check_circle, color: Palette.success, size: 44)
            : const Icon(Icons.warning_amber_rounded,
                color: Palette.error, size: 44),
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

    final elections =
        provider.elections.where((e) => e.status == 'Active').toList();
    if (elections.isEmpty) {
      _showError('No active elections to publish');
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        title: const Text('Select Election to Publish',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        children: elections
            .map(
              (e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.how_to_vote_outlined,
                          size: 18, color: Palette.gold),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.name)),
                    ],
                  ),
                ),
              ),
            )
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

  Future<void> _onShowCandidates() async {
    final provider = context.read<DashboardProvider>();
    await provider.fetchElections();
    if (!mounted) return;

    final elections = provider.elections.toList();
    if (elections.isEmpty) {
      _showError('No elections found');
      return;
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Election'),
        children: elections
            .map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e.electionId),
                  child: Text(e.name),
                ))
            .toList(),
      ),
    );
    if (selected == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CandidateListScreen(electionId: selected)),
    );
  }

  void _showResultDialog(
      String title, String summary, Widget icon, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Palette.hairline.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(height: 16),
            Text(
              summary,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.inkMuted, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.navy,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Palette.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
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
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor == Colors.transparent
                        ? Colors.white
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Palette.gold),
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Verifying votes…',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
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
      backgroundColor: const Color(0xFFF5F6F9),
      body: Stack(
        children: [
          body,
          // Logout button
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
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
          expandedHeight: 150,
          pinned: true,
          backgroundColor: Palette.navyDeep,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: 0.3,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(gradient: Palette.navyGradient),
              child: Stack(
                children: [
                  Positioned(
                    left: -30,
                    bottom: -40,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 50, right: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Palette.gold.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const CircleAvatar(
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
                  const Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 44),
                      child: Text(
                        'Election oversight & analytics',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.insights_rounded,
              title: 'Overview',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                    for (int i = 0; i < 4; i++) const _ShimmerCard()
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
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.bolt_rounded,
              title: 'Quick Actions',
            ),
          ),
        ),
        // Action buttons
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 900 ? 4 : (width >= 560 ? 3 : 2);
                final spacing = 12.0;
                final itemWidth =
                    (width - (spacing * (columns - 1))) / columns;

                final actions = <_ActionSpec>[
                  _ActionSpec(
                    icon: Icons.verified_outlined,
                    label: 'Verify Integrity',
                    onTap: _onVerifyIntegrity,
                    color: Palette.success,
                  ),
                  _ActionSpec(
                    icon: Icons.publish_outlined,
                    label: 'Publish Results',
                    onTap: _onPublishResults,
                    color: Palette.gold,
                  ),
                  _ActionSpec(
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
                  _ActionSpec(
                    icon: Icons.group,
                    label: 'Manage Voters',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoterListScreen()),
                      );
                    },
                    color: Palette.indigo,
                  ),
                  _ActionSpec(
                    icon: Icons.how_to_vote_outlined,
                    label: 'Show Candidates',
                    onTap: _onShowCandidates,
                    color: Palette.indigo,
                  ),
                  _ActionSpec(
                    icon: Icons.person_add,
                    label: 'Add Candidate',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddCandidateScreen()),
                      );
                    },
                    color: Palette.success,
                  ),
                  _ActionSpec(
                    icon: Icons.add_rounded,
                    label: 'Create Election',
                    onTap: _onCreateElection,
                    color: Palette.success,
                  ),
                  _ActionSpec(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh Data',
                    onTap: _loadStats,
                    color: Palette.navy,
                  ),
                ];

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: actions
                      .map(
                        (a) => SizedBox(
                          width: itemWidth,
                          child: _ActionButton(
                            icon: a.icon,
                            label: a.label,
                            onTap: a.onTap,
                            color: a.color,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
}

/// Small caption-style header used above dashboard sections.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Palette.navy),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Palette.navy,
          ),
        ),
      ],
    );
  }
}

/// A polished action tile for the admin dashboard.
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.18)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateElectionDialog extends StatefulWidget {
  const _CreateElectionDialog();

  @override
  State<_CreateElectionDialog> createState() => _CreateElectionDialogState();
}

class _CreateElectionDialogState extends State<_CreateElectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaCodeController = TextEditingController();
  final _constituencyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  String _status = 'Upcoming';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _areaCodeController.dispose();
    _constituencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      controller.text = picked.toIso8601String();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      'areaCode': _areaCodeController.text.trim().isEmpty
          ? null
          : _areaCodeController.text.trim(),
      'constituency': _constituencyController.text.trim().isEmpty
          ? null
          : _constituencyController.text.trim(),
      'startDate': _startDateController.text.trim(),
      'endDate': _endDateController.text.trim(),
      'status': _status,
    });
  }

  InputDecoration _decoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 19) : null,
      filled: true,
      fillColor: const Color(0xFFF6F7FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.navy, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Palette.error, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Palette.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded,
                color: Palette.success, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Create Election',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration:
                      _decoration('Election name', icon: Icons.badge_outlined),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Election name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _decoration('Description',
                      icon: Icons.notes_rounded),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _areaCodeController,
                        decoration: _decoration('Area code',
                            icon: Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _constituencyController,
                        decoration: _decoration('Constituency',
                            icon: Icons.location_city_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startDateController,
                        decoration: _decoration('Start date',
                            icon: Icons.calendar_today_outlined),
                        readOnly: true,
                        onTap: () => _pickDate(_startDateController),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endDateController,
                        decoration: _decoration('End date',
                            icon: Icons.event_outlined),
                        readOnly: true,
                        onTap: () => _pickDate(_endDateController),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration:
                      _decoration('Status', icon: Icons.flag_outlined),
                  items: const [
                    DropdownMenuItem(
                        value: 'Upcoming', child: Text('Upcoming')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Completed', child: Text('Completed')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Palette.navy,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
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
            width: 38,
            height: 38,
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