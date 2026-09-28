import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../../providers/voter_provider.dart';
import 'create_voter_screen.dart';

/// Shown after a successful voter registration.
///
/// Displays the confirmation checkmark, the Voter ID, NID, full name, saved
/// face image path, and registration time, plus two actions:
///  - **Register Another Voter** — pops back and opens a fresh [CreateVoterScreen].
///  - **Close** — pops back to the previous screen (admin dashboard).
class VoterRegistrationResultScreen extends StatelessWidget {
  const VoterRegistrationResultScreen({super.key, required this.result});

  final VoterRegistrationResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.paper,
      appBar: AppBar(
        title: const Text('Registration Complete'),
        backgroundColor: Palette.navyDeep,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: Palette.cardDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Palette.success.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Palette.success,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '✓ Voter Registered Successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Palette.success,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _DetailRow(label: 'Voter ID', value: '${result.voterId ?? '-'}'),
                  const Divider(height: 1),
                  _DetailRow(label: 'NID', value: result.nid ?? '-'),
                  const Divider(height: 1),
                  _DetailRow(label: 'Full Name', value: result.fullName ?? '-'),
                  const Divider(height: 1),
                  _DetailRow(
                    label: 'Saved Image Path',
                    value: result.savedImagePath ?? '-',
                  ),
                  const Divider(height: 1),
                  _DetailRow(
                    label: 'Registration Time',
                    value: _formatTime(result.registrationTime),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateVoterScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('Register Another Voter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    return '${t.toLocal()}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Palette.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Palette.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
