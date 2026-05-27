import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (auth.sessionExpiredMessage != null) {
      final msg = auth.sessionExpiredMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        auth.clearSessionExpiredMessage();
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            color: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF),
          ),
          
          // Floating Elements (Decor)
          // Blobs removed — flat design, no decorative elements

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo — flat container, no gradient, no glow
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08),
                        ),
                      ),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 54,
                        height: 54,
                        fit: BoxFit.contain,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    Text(
                      _isLogin ? 'Code Genie' : 'Join Code Genie',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      _isLogin 
                        ? 'Sign in to continue your coding journey' 
                        : 'Join the community of modern developers',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? const Color(0xFFA3A3A3) : const Color(0xFF525252),
                      ),
                    ),
                    
                    const SizedBox(height: 48),

                    // Error Message
                    if (auth.error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                auth.error!,
                                style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Form
                    if (!_isLogin)
                      _textField(_nameCtrl, 'Full Name', Icons.person_outline, isDark),
                    
                    const SizedBox(height: 16),
                    _textField(_emailCtrl, 'Email Address', Icons.email_outlined, isDark),
                    const SizedBox(height: 16),
                    _textField(_passCtrl, 'Password', Icons.lock_outline, isDark, isPass: true),
                    
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _handleForgotPassword(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: auth.status == AuthStatus.authenticating 
                          ? null 
                          : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF8B8BF5) : const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 0,
                        ),
                        child: auth.status == AuthStatus.authenticating
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isLogin ? 'Sign In' : 'Sign Up',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Google Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: auth.status == AuthStatus.authenticating 
                          ? null 
                          : () => auth.googleLogin(),
                        icon: const Icon(Icons.login, size: 20),
                        label: Text(
                          'Continue with Google',
                          style: GoogleFonts.inter(
                            fontSize: 16, 
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Toggle
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin ? "Don't have an account? Sign Up" : "Already have an account? Sign In",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, IconData icon, bool isDark, {bool isPass = false}) {
    return TextField(
      controller: ctrl,
      obscureText: isPass,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF404040) : const Color(0xFFD4D4D4),
        ),
        prefixIcon: Icon(icon, color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFFA3A3A3)),
        filled: true,
        fillColor: isDark ? const Color(0xFF242424) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.1) : const Color(0x00000000).withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF8B8BF5) : const Color(0xFF6366F1),
            width: 1,
          ),
        ),
      ),
    );
  }


  void _submit() {
    final auth = context.read<AuthProvider>();
    if (_isLogin) {
      auth.login(_emailCtrl.text, _passCtrl.text);
    } else {
      auth.register(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    }
  }

  void _handleForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _textField(emailCtrl, 'Email Address', Icons.email_outlined, isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: isDark ? Colors.white38 : Colors.black38)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailCtrl.text.isEmpty) return;
              final auth = context.read<AuthProvider>();
              final success = await auth.forgotPassword(emailCtrl.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Reset link sent to ${emailCtrl.text}' : 'Failed to send reset link'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: success ? Colors.green : Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}
