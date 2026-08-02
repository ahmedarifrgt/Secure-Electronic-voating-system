import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/palette.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/admin_dashboard.dart';
import '../election/election_screen.dart';
import 'live_selfie_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController nidController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isAdmin = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    nidController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _selectAndLogin() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();

    if (isAdmin) {
      await _adminLogin(auth);
    } else {
      await _voterLogin(auth);
    }
  }

  Future<void> _adminLogin(AuthProvider auth) async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      _showError('Enter username and password');
      return;
    }

    final ok = await auth.loginAdmin(
      username: username,
      password: password,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else {
      _showError(auth.error ?? 'Login failed');
    }
  }

  Future<void> _voterLogin(AuthProvider auth) async {
    final nid = nidController.text.trim();
    if (nid.isEmpty) {
      _showError('Enter your National ID');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveSelfieScreen(nid: nid),
      ),
    );
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

  Widget _roleToggle() {
    Widget segment({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Palette.navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: selected ? Palette.goldSoft : Palette.inkMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : Palette.inkMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.hairline),
      ),
      child: Row(
        children: [
          segment(
            label: 'Voter',
            icon: Icons.how_to_vote_outlined,
            selected: !isAdmin,
            onTap: () => setState(() => isAdmin = false),
          ),
          segment(
            label: 'Admin',
            icon: Icons.admin_panel_settings_outlined,
            selected: isAdmin,
            onTap: () => setState(() => isAdmin = true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Palette.navyDeep,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: Palette.navyGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSeal(),
                    const SizedBox(height: 20),
                    const Text(
                      'ELECTRONIC VOTING SYSTEM',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAdmin
                          ? 'Secure admin access'
                          : 'Verify your identity to continue',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _roleToggle(),
                          const SizedBox(height: 22),
                          if (!isAdmin) ...[
                            TextField(
                              controller: nidController,
                              keyboardType: TextInputType.number,
                              decoration: _fieldDecoration(
                                label: 'National ID',
                                icon: Icons.badge_outlined,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                  color: Palette.inkMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'You will capture a live selfie for face verification',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Palette.inkMuted.withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            TextField(
                              controller: usernameController,
                              decoration: _fieldDecoration(
                                label: 'Username',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: _fieldDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildSubmitButton(auth),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your credentials are encrypted and never shared.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeal() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: Palette.goldGradient,
        boxShadow: [
          BoxShadow(
            color: Palette.gold.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.verified_user_rounded,
        color: Palette.navyDeep,
        size: 30,
      ),
    );
  }

  Widget _buildSubmitButton(AuthProvider auth) {
    final loading = auth.loading;

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : _selectAndLogin,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Palette.goldSoft),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isAdmin ? 'Sign In' : 'Verify Identity',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Palette.goldSoft,
                  ),
                ],
              ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
    );
  }
}

