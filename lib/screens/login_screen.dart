import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                  : [const Color(0xFFF6F8FA), Colors.white],
              ),
            ),
          ),
          
          // Floating Elements (Decor)
          Positioned(
            top: -100, right: -100,
            child: _blob(200, const Color(0xFF6366F1).withValues(alpha: 0.1)),
          ),
          Positioned(
            bottom: -50, left: -50,
            child: _blob(150, const Color(0xFF06B6D4).withValues(alpha: 0.1)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
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
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      _isLogin 
                        ? 'Sign in to continue your coding journey' 
                        : 'Join the community of modern developers',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? Colors.white54 : Colors.black54,
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
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
        prefixIcon: Icon(icon, color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
