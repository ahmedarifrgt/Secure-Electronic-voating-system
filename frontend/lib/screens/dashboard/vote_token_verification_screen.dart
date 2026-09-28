import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../providers/dashboard_provider.dart';

class VoteTokenVerificationScreen extends StatefulWidget {
  const VoteTokenVerificationScreen({super.key});

  @override
  State<VoteTokenVerificationScreen> createState() => _VoteTokenVerificationScreenState();
}

class _VoteTokenVerificationScreenState extends State<VoteTokenVerificationScreen> {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final provider = context.read<DashboardProvider>();
    final ok = await provider.verifyVoteToken(_tokenController.text.trim());
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Unable to verify token'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final result = provider.tokenVerificationResult;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text('Verify Vote Token'),
        backgroundColor: Palette.navyDeep,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IntroCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Vote token',
                          prefixIcon: Icon(Icons.confirmation_num_outlined),
                        ),
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          final token = value?.trim() ?? '';
                          if (token.isEmpty) {
                            return 'Enter the token from the voter receipt';
                          }
                          if (token.length != 64) {
                            return 'Token must be 64 hexadecimal characters';
                          }
                          final hex = RegExp(r'^[0-9a-fA-F]{64}$');
                          if (!hex.hasMatch(token)) {
                            return 'Token format is invalid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: provider.verifyingToken ? null : _verify,
                          icon: provider.verifyingToken
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(provider.verifyingToken ? 'Verifying...' : 'Verify Token'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (result != null) _ResultCard(result: result),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Palette.navyDeep, Palette.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Token verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Paste the anonymous vote receipt token here to verify that a real vote record exists and that its integrity is valid.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final dynamic result;

  @override
  Widget build(BuildContext context) {
    final valid = result.valid == true;
    final found = result.found == true;
    final color = valid ? Palette.success : Palette.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(valid ? Icons.verified_rounded : Icons.error_outline_rounded, color: color),
                const SizedBox(width: 8),
                Text(
                  valid ? 'Token verified' : (found ? 'Token found but invalid' : 'Token not found'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row('Token', result.token ?? '-'),
            _row('Vote ID', '${result.voteId ?? '-'}'),
            _row('Election ID', '${result.electionId ?? '-'}'),
            _row('Candidate ID', '${result.candidateId ?? '-'}'),
            _row('Timestamp', result.timestamp ?? '-'),
            _row('Integrity status', result.isVerified == true ? 'Verified' : 'Not verified'),
            if ((result.reasons as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Reasons', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...((result.reasons as List).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $e'),
                  ))),
            ],
            if ((result.message as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(result.message as String, style: const TextStyle(color: Palette.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(color: Palette.inkMuted)),
          ),
          Expanded(
            flex: 5,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}