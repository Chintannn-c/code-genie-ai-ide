import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A simple, premium, and minimalistic Splash Screen in the style of ChatGPT/Gemini.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Solid premium deep space black
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minimalistic Slow-Pulsing Terminal Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0xFF0F172A), // Slate 900
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.terminal_rounded,
                  size: 36,
                  color: Color(0xFF6366F1), // Indigo accent
                ),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fade(duration: 1400.ms, begin: 0.4, end: 1.0, curve: Curves.easeInOut),

            const SizedBox(height: 24),

            // Simple, clean brand name
            Text(
              'Code Genie',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
