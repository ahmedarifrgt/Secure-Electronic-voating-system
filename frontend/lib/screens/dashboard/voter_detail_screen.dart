import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../models/voter.dart';
import '../../providers/voter_provider.dart';

class VoterDetailScreen extends StatelessWidget {
  const VoterDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoterProvider>();
    final voter = provider.selectedVoter;

    if (voter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Voter Details')),
        body: Center(child: Text(provider.error ?? 'No voter selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Voter Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voter.fullName ?? 'Voter',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (voter.faceImagePath != null && voter.faceImagePath!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Builder(builder: (_) {
                          final path = voter.faceImagePath!;
                          if (path.startsWith('http')) {
                            return Image.network(path, height: 120, fit: BoxFit.cover);
                          }
                          return Text('Image path: $path');
                        }),
                      ),
                    Text('NID: ${voter.nid ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Voter ID: ${voter.voterId ?? '-'}'),
                    const SizedBox(height: 6),
                    Text('Account status: ${voter.accountStatus ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if ((voter.permanentAddress ?? '').isNotEmpty)
              _DetailRow(label: 'Permanent address', value: voter.permanentAddress ?? '-'),
            if ((voter.presentAddress ?? '').isNotEmpty)
              _DetailRow(label: 'Present address', value: voter.presentAddress ?? '-'),
            _DetailRow(label: 'Gender', value: voter.gender ?? '-'),
            _DetailRow(label: 'Date of birth', value: voter.dob ?? '-'),
            _DetailRow(label: 'Father name', value: voter.fatherName ?? '-'),
            _DetailRow(label: 'Mother name', value: voter.motherName ?? '-'),
            _DetailRow(label: 'Mobile', value: voter.mobile ?? '-'),
            _DetailRow(label: 'Email', value: voter.email ?? '-'),
            _DetailRow(label: 'Area code', value: voter.areaCode ?? '-'),
            _DetailRow(label: 'Constituency', value: voter.constituency ?? '-'),
            _DetailRow(label: 'Registered', value: voter.registrationStatus ? 'Yes' : 'No'),
            _DetailRow(label: 'Eligible', value: voter.eligibilityStatus ? 'Yes' : 'No'),
            _DetailRow(label: 'Has voted', value: voter.hasVoted ? 'Yes' : 'No'),
            _DetailRow(label: 'Created', value: voter.createdAt ?? '-'),
            _DetailRow(label: 'Last login', value: voter.lastLogin ?? '-'),
            _DetailRow(label: 'Updated', value: voter.updatedAt ?? '-'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label',
              style: const TextStyle(color: Palette.inkMuted, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
