import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../providers/auth_provider.dart';
import 'dashboard/admin_dashboard.dart';
import 'election/election_screen.dart';
import 'login/login_screen.dart';

/// Entry screen shown while the persisted session is being restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final auth = context.read<AuthProvider>();
    await auth.restoreSession();

    if (!mounted) return;

    Widget next;
    if (auth.isAuthenticated && auth.isAdmin) {
      next = const AdminDashboard();
    } else if (auth.isAuthenticated && auth.isVoter) {
      next = const ElectionScreen();
    } else {
      next = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Palette.navyDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_rounded,
                size: 72, color: Palette.goldSoft),
            SizedBox(height: 20),
            Text(
              'SECURE ELECTRONIC VOTING',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Palette.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

