import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A clean, minimal Splash Screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple terminal icon — no container, no border, no glow
            Icon(
              Icons.terminal_rounded,
              size: 36,
              color: const Color(0xFFA3A3A3),
            )
            .animate()
            .fadeIn(duration: 400.ms, curve: Curves.easeOut),

            const SizedBox(height: 24),

            // Clean brand name
            Text(
              'Code Genie',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA3A3A3),
                letterSpacing: -0.01 * 17,
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms, delay: 100.ms, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}
