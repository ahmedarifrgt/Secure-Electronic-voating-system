import 'package:flutter/material.dart';

import '../core/palette.dart';

/// A full-screen translucent overlay with a centered spinner.
/// Useful for long-running operations (vote casting, verification).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.message = 'Loading…',
    this.opacity = 0.7,
  });

  final String message;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(opacity),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Palette.gold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
