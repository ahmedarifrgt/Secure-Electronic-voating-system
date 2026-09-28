import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../providers/auth_provider.dart';
import '../../providers/voter_provider.dart';

class VoterDetailScreen extends StatelessWidget {
  const VoterDetailScreen({super.key, this.voter});

  final dynamic voter;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoterProvider>();
    final auth = context.watch<AuthProvider>();
    final apiBaseUrl = provider.apiBaseUrl;
    final displayedVoter = voter ?? provider.selectedVoter;

    if (displayedVoter == null) {
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayedVoter.fullName ?? 'Voter',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Text('NID: ${displayedVoter.nid ?? '-'}'),
                              const SizedBox(height: 6),
                              Text('Voter ID: ${displayedVoter.voterId ?? '-'}'),
                              const SizedBox(height: 6),
                              Text('Account status: ${displayedVoter.accountStatus ?? '-'}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if ((displayedVoter.faceImageUrl ?? displayedVoter.faceImagePath ?? '').isNotEmpty)
                          _PhotoThumbnail(
                            imageUrl: _photoUrl(displayedVoter, apiBaseUrl),
                            authToken: auth.token,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if ((displayedVoter.permanentAddress ?? '').isNotEmpty)
              _DetailRow(label: 'Permanent address', value: displayedVoter.permanentAddress ?? '-'),
            if ((displayedVoter.presentAddress ?? '').isNotEmpty)
              _DetailRow(label: 'Present address', value: displayedVoter.presentAddress ?? '-'),
            _DetailRow(label: 'Gender', value: displayedVoter.gender ?? '-'),
            _DetailRow(label: 'Date of birth', value: displayedVoter.dob ?? '-'),
            _DetailRow(label: 'Father name', value: displayedVoter.fatherName ?? '-'),
            _DetailRow(label: 'Mother name', value: displayedVoter.motherName ?? '-'),
            _DetailRow(label: 'Mobile', value: displayedVoter.mobile ?? '-'),
            _DetailRow(label: 'Email', value: displayedVoter.email ?? '-'),
            _DetailRow(label: 'Area code', value: displayedVoter.areaCode ?? '-'),
            _DetailRow(label: 'Constituency', value: displayedVoter.constituency ?? '-'),
            _DetailRow(label: 'Registered', value: displayedVoter.registrationStatus ? 'Yes' : 'No'),
            _DetailRow(label: 'Eligible', value: displayedVoter.eligibilityStatus ? 'Yes' : 'No'),
            _DetailRow(label: 'Has voted', value: displayedVoter.hasVoted ? 'Yes' : 'No'),
            _DetailRow(label: 'Created', value: displayedVoter.createdAt ?? '-'),
            _DetailRow(label: 'Last login', value: displayedVoter.lastLogin ?? '-'),
            _DetailRow(label: 'Updated', value: displayedVoter.updatedAt ?? '-'),
          ],
        ),
      ),
    );
  }

  String _photoUrl(dynamic voter, String apiBaseUrl) {
    final explicitUrl = voter.faceImageUrl;
    if (explicitUrl is String && explicitUrl.isNotEmpty) {
      return explicitUrl.startsWith('http') ? explicitUrl : '$apiBaseUrl$explicitUrl';
    }
    final fallbackPath = voter.faceImagePath;
    if (fallbackPath is String && fallbackPath.startsWith('http')) {
      return fallbackPath;
    }
    final voterId = voter.voterId;
    return '$apiBaseUrl/voter/photo/$voterId';
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({required this.imageUrl, required this.authToken});

  final String imageUrl;
  final String? authToken;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 88,
        height: 88,
        color: Colors.black12,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          headers: authToken == null ? null : {'Authorization': 'Bearer $authToken'},
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.person, size: 36, color: Colors.black45),
          ),
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
              label,
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
