import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/voter.dart';
import '../../providers/auth_provider.dart';
import '../election/election_screen.dart';

class VoterDetailsScreen extends StatelessWidget {
  const VoterDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final voter = context.read<AuthProvider>().voter;

    if (voter == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F6F9),
        appBar: AppBar(
          title: const Text('Voter Details'),
          elevation: 0,
        ),
        body: Center(
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
                  child: const Icon(Icons.person_off_outlined,
                      size: 40, color: Palette.inkMuted),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No voter data available.',
                  style: TextStyle(color: Palette.inkMuted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Voter Details'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Palette.navy,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 64, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: Palette.navyGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Palette.navy.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: Palette.goldGradient,
                          boxShadow: [
                            BoxShadow(
                              color: Palette.gold.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            voter.initials,
                            style: const TextStyle(
                              color: Palette.navyDeep,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voter.fullName ?? 'Voter',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'NID: ${voter.nid ?? '-'}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    runSpacing: 10,
                    spacing: 10,
                    children: [
                      _InfoChip(
                        label: 'Eligible',
                        value: voter.isEligible ? 'Yes' : 'No',
                        positive: voter.isEligible,
                      ),
                      _InfoChip(
                        label: 'Registered',
                        value: voter.registrationStatus ? 'Yes' : 'No',
                        positive: voter.registrationStatus,
                      ),
                      _InfoChip(
                        label: 'Voted',
                        value: voter.hasVoted ? 'Yes' : 'No',
                        positive: voter.hasVoted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: const [
                Icon(Icons.badge_outlined, size: 18, color: Palette.navy),
                SizedBox(width: 8),
                Text(
                  'Profile information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Palette.navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.hairline),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.wc_rounded,
                    label: 'Gender',
                    value: voter.gender ?? '-',
                  ),
                  const _RowDivider(),
                  _DetailRow(
                    icon: Icons.map_outlined,
                    label: 'Area code',
                    value: voter.areaCode ?? '-',
                  ),
                  const _RowDivider(),
                  _DetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'Constituency',
                    value: voter.constituency ?? '-',
                  ),
                  const _RowDivider(),
                  _DetailRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Account status',
                    value: voter.accountStatus ?? '-',
                  ),
                  const _RowDivider(),
                  _DetailRow(
                    icon: Icons.event_available_outlined,
                    label: 'Created at',
                    value: voter.createdAt ?? '-',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.navy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const ElectionScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue to Elections'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.icon,
    this.isLast = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: Palette.inkMuted),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Palette.inkMuted,
              fontSize: 13.5,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: Palette.hairline.withOpacity(0.6));
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    this.positive = true,
  });

  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 14,
            color: positive ? Palette.gold : Colors.white54,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12.5, color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}