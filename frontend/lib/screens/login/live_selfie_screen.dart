import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../providers/auth_provider.dart';
import '../election/election_screen.dart';
import 'voter_details_screen.dart';

class LiveSelfieScreen extends StatefulWidget {
  const LiveSelfieScreen({super.key, required this.nid});

  final String nid;

  @override
  State<LiveSelfieScreen> createState() => _LiveSelfieScreenState();
}

class _LiveSelfieScreenState extends State<LiveSelfieScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;

  Future<void> _captureAndVerify() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1280,
    );

    if (!mounted) return;
    if (photo == null) {
      _showError('Live image is required for verification.');
      setState(() => _loading = false);
      return;
    }

    final ok = await auth.loginVoter(nid: widget.nid, liveImage: photo);
    if (!mounted) return;

    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VoterDetailsScreen()),
      );
    } else {
      _showError(auth.error ?? 'Face verification failed.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Palette.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Live Selfie'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Step 2 of 2',
              style: TextStyle(fontSize: 14, color: Palette.inkMuted),
            ),
            const SizedBox(height: 12),
            Text(
              'National ID: ${widget.nid}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capture a live selfie so we can verify your identity and proceed to the voter details page.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loading ? null : _captureAndVerify,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(_loading ? 'Capturing…' : 'Capture live selfie'),
            ),
            const SizedBox(height: 16),
            Text(
              'If your device does not support camera capture, the app may open a file picker to select a recent selfie.',
              style: TextStyle(fontSize: 12, color: Palette.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
