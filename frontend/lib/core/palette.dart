import 'package:flutter/material.dart';

/// Shared design tokens for the Secure Electronic Voting System.
///
/// A civic navy + gold palette that reads as "official institution"
/// and stays consistent across every screen of the app.
class Palette {
  Palette._();

  // ---- Brand colors -----------------------------------------------------
  static const Color navy = Color(0xFF0B2545);
  static const Color navyDeep = Color(0xFF071A33);
  static const Color indigo = Color(0xFF13315C);
  static const Color gold = Color(0xFFD4A017);
  static const Color goldSoft = Color(0xFFE9C767);
  static const Color paper = Color(0xFFF6F7FA);
  static const Color ink = Color(0xFF16213E);
  static const Color inkMuted = Color(0xFF5C6B8A);
  static const Color hairline = Color(0xFFE1E5EE);
  static const Color error = Color(0xFFC0392B);
  static const Color success = Color(0xFF1E8E5A);
  static const Color warning = Color(0xFFE67E22);

  // ---- Gradients ---------------------------------------------------------
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDeep, navy],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldSoft],
  );

  // ---- Decorations -------------------------------------------------------
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: hairline),
    boxShadow: [
      BoxShadow(
        color: navy.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

