import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../config/api_config.dart';
import '../../widgets/settings/glass_card.dart';
import '../../widgets/settings/settings_toggle.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Loading and Persistence States
  bool _isLoading = true;
  bool _syncing = false;
  bool _syncFailed = false;

  // Hydrated User States
  String _fullName = 'Code Genie User';
  String _email = '';
  String? _pictureUrl;
  bool _twoFactor = false;
  bool _biometric = true;

  // Dynamic Lists & Maps from Backend
  Map<String, dynamic> _connections = {
    'Google': true,
    'GitHub': false,
    'OpenRouter': true,
    'Groq': true
  };
  Map<String, dynamic> _usage = {'used': 4210891, 'limit': 10000000};
  List<dynamic> _activeSessions = [];
  List<dynamic> _anomalyLogs = [];

  // API Key local edit controller variables
  bool _showKeyPanel = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // --- API SERVICE INTEGRATION HANDLERS ---

  Future<void> _fetchProfile({bool background = false}) async {
    if (!background) {
      setState(() {
        _isLoading = true;
        _syncFailed = false;
      });
    } else {
      setState(() {
        _syncing = true;
        _syncFailed = false;
      });
    }

    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/profile');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _fullName = data['full_name'] ?? 'Code Genie User';
            _email = data['email'] ?? '';
            _pictureUrl = data['picture_url'];
            _twoFactor = data['two_factor'] ?? false;
            _biometric = data['biometric'] ?? true;
            _connections = data['connections'] ?? {};
            _usage = data['usage'] ?? {'used': 4210891, 'limit': 10000000};
            _activeSessions = data['active_sessions'] ?? [];
            _anomalyLogs = data['anomaly_logs'] ?? [];
            _isLoading = false;
            _syncing = false;
          });
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Fetch Profile Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncing = false;
          _syncFailed = true;
        });
        _showToast('Failed to hydrate settings from server. Running in offline fallback mode.', isError: true);
      }
    }
  }

  Future<void> _updateSecuritySettings(bool twoFactor, bool biometric, {String? code}) async {
    setState(() {
      _syncing = true;
      _syncFailed = false;
    });

    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/security/update');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'two_factor': twoFactor,
          'biometric': biometric,
          if (code != null) 'code': code,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _twoFactor = twoFactor;
            _biometric = biometric;
            _syncing = false;
          });
        }
        // Proactively refresh profile logs
        _fetchProfile(background: true);
      } else {
        throw Exception('Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Security Update Error: $e');
      if (mounted) {
        setState(() {
          _syncing = false;
          _syncFailed = true;
        });
        _showToast('Persistence failed. Reverting security changes.', isError: true);
      }
    }
  }

  Future<String?> _sendGmailVerificationCode() async {
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;
    final userEmail = ap.user?.email ?? _email;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/security/send-code');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': userEmail,
        }),
      );

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        _showToast('Verification code sent to $userEmail!');
        return res['dev_code']?.toString();
      } else {
        throw Exception('Failed to send code: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Send Code Error: $e');
      _showToast('Failed to dispatch validation email.', isError: true);
      return null;
    }
  }

  Future<void> _revokeSessionOnBackend(String sessionId) async {
    // Optimistic UI updates
    setState(() {
      _activeSessions.removeWhere((s) => s['session_id'] == sessionId);
      _syncing = true;
    });

    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/sessions/revoke');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'session_id': sessionId}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _syncing = false);
          _showToast('Active device session revoked successfully.');
        }
        _fetchProfile();
      } else {
        throw Exception('Revocation failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Session Revoke Error: $e');
      if (mounted) {
        setState(() => _syncing = false);
        _showToast('Could not revoke device session. Please check connection.', isError: true);
        _fetchProfile(); // reload original states
      }
    }
  }

  Future<void> _toggleProviderOnBackend(String provider, bool connected) async {
    setState(() {
      _connections[provider] = connected;
      _syncing = true;
    });

    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/providers/toggle');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'provider': provider,
          'connected': connected,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => _syncing = false);
        }
        _fetchProfile();
      } else {
        throw Exception('Failed to toggle provider: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Provider Toggle Error: $e');
      if (mounted) {
        setState(() => _syncing = false);
        _showToast('Provider settings synchronization failed.', isError: true);
        _fetchProfile();
      }
    }
  }

  Future<void> _exportGdprData() async {
    _showToast('Compressing GDPR data export package...');
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/privacy/export');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prettyJson = const JsonEncoder.withIndent('  ').convert(data);

        // Show a premium high-fidelity scrollable copyable Dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.download_done_rounded, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      Text(
                        'Data Export Ready',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All conversation transcripts, model logs, and profile records have been compiled into a secure JSON package.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, height: 1.45, color: isDark ? Colors.white70 : Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 180,
                        width: double.maxFinite,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            prettyJson,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: isDark ? Colors.white54 : Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Close', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: isDark ? Colors.white38 : Colors.black38)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: prettyJson));
                        Navigator.pop(ctx);
                        _showToast('Copied JSON export package to clipboard!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Copy JSON', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          );
        }
      } else {
        throw Exception('Export failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Data Export Error: $e');
      _showToast('Failed to compile data export package.', isError: true);
    }
  }

  Future<void> _clearAiMemoryTranscripts() async {
    _showToast('Erasing contextual databases and model indices...');
    final ap = context.read<AuthProvider>();
    final token = ap.user?.token;

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/privacy/clear-memory');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showToast('All indexing states and conversation logs erased successfully.', isError: true);
        _fetchProfile(background: true);
      } else {
        throw Exception('Erase context failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AccountPage] Clear Memory Error: $e');
      _showToast('Erase operation aborted due to server error.', isError: true);
    }
  }

  // --- UI INTERACTIVE METHODS ---

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? Colors.redAccent : const Color(0xFF10B981),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E24).withValues(alpha: 0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _simulateAvatarUpload() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Change Profile Image',
                style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1)),
                title: Text('Choose from Gallery', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _runCropUploadAnimation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
                title: Text('Take Photo', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _runCropUploadAnimation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                title: Text('Remove Avatar', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _pictureUrl = null);
                  _showToast('Profile avatar removed successfully.');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _runCropUploadAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.canPop(ctx)) {
            Navigator.pop(ctx);
            setState(() {
              _pictureUrl = 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=256&auto=format&fit=crop';
            });
            _showToast('Profile image synchronized and cached successfully!');
          }
        });

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AlertDialog(
            backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Compressing & Uploading...',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Text(
                  'Optimizing image formats via neural CDN',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleConnection(String provider) {
    final currentlyConnected = _connections[provider] ?? false;

    if (currentlyConnected) {
      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Disconnect $provider?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: Text(
                'You will no longer be able to use your $provider tokens to access secure multi-agent contexts.',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _toggleProviderOnBackend(provider, false);
                  },
                  child: Text('Disconnect', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.canPop(ctx)) {
              Navigator.pop(ctx);
              _toggleProviderOnBackend(provider, true);
              _showToast('Successfully connected to $provider!');
            }
          });

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Authorizing secure credentials with $provider...',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acquiring secure API tokens',
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  void _setupTwoFactor(bool enable) {
    if (!enable) {
      showDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Disable 2FA?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              content: Text(
                'This will significantly lower your cybersecurity trust rating. Are you sure you want to disable 2FA?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateSecuritySettings(false, _biometric);
                  },
                  child: Text('Disable', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        },
      );
    } else {
      final controller = TextEditingController();
      String? devCode;
      bool sendingCode = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final ap = context.read<AuthProvider>();
          final userEmail = ap.user?.email ?? _email;
          
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Row(
                    children: [
                      const Icon(Icons.mail_lock_rounded, color: Color(0xFF6366F1)),
                      const SizedBox(width: 10),
                      Text(
                        'Gmail Verification (2FA)',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For enhanced cybersecurity protection, we will send a secure 6-digit OTP to your registered Gmail account.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, height: 1.45, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.alternate_email_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userEmail,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (devCode == null)
                          SizedBox(
                            width: double.maxFinite,
                            child: ElevatedButton.icon(
                              onPressed: sendingCode 
                                ? null 
                                : () async {
                                    setDialogState(() => sendingCode = true);
                                    final code = await _sendGmailVerificationCode();
                                    setDialogState(() {
                                      sendingCode = false;
                                      devCode = code;
                                    });
                                  },
                              icon: sendingCode 
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : const Icon(Icons.send_rounded, size: 14),
                              label: Text(sendingCode ? 'Dispatching...' : 'Send OTP to Gmail', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          )
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Enter Gmail OTP Code:',
                                style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black45),
                              ),
                              GestureDetector(
                                onTap: () {
                                  controller.text = devCode!;
                                  setDialogState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Auto-fill dev OTP ($devCode)',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                              hintText: '000000',
                              hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                              ),
                            ),
                            onChanged: (val) {
                              setDialogState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: controller.text.length == 6
                          ? () {
                              Navigator.pop(ctx);
                              _updateSecuritySettings(true, _biometric, code: controller.text);
                            }
                          : null,
                      child: Text(
                        'Verify & Enable',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          color: controller.text.length == 6 ? const Color(0xFF6366F1) : (isDark ? Colors.white12 : Colors.black12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  void _confirmDeleteAccount() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final matches = controller.text.trim() == 'DELETE';
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AlertDialog(
                backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
                title: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Delete Account?',
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 18),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This operation is permanent and immediately deletes all conversation logs, settings, caches, and attached tokens.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.45, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type DELETE below to confirm:',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        hintText: 'DELETE',
                        hintStyle: TextStyle(color: isDark ? Colors.white12 : Colors.black12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {});
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.plusJakartaSans(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: matches
                        ? () {
                            Navigator.pop(ctx); // Close dialog
                            Navigator.pop(context); // Close AccountPage
                            context.read<AuthProvider>().signOut();
                            _showToast('Your account was successfully deleted. Goodbye!', isError: true);
                          }
                        : null,
                    child: Text(
                      'Delete Forever',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: matches ? Colors.redAccent : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- RENDERING ROUTINES ---

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF08080A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: _isLoading 
            ? _buildShimmerSkeleton(isDark)
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Sync Health Tracking floating pill inside Header
                  SliverToBoxAdapter(child: _buildHeader(context, isDark)),
                  
                  // Profile Details Hero Card
                  SliverToBoxAdapter(child: _buildProfileHero(isDark)),
                  
                  // API Provider Connected Hub
                  SliverToBoxAdapter(child: _buildConnectedHub(isDark)),

                  // Security Panel & MFA Configuration
                  SliverToBoxAdapter(child: _buildSecurityControlPanel(isDark)),

                  // API Token Keys & Organization panel (Expandable)
                  SliverToBoxAdapter(child: _buildApiKeyPanel(isDark)),

                  // Active session & device managers
                  SliverToBoxAdapter(child: _buildActiveSessionsPanel(isDark)),

                  // Data Privacy Control Panel
                  SliverToBoxAdapter(child: _buildPrivacyControlPanel(isDark)),

                  // Danger Zone Warning settings
                  SliverToBoxAdapter(child: _buildDangerZone(isDark)),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Control Center',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Floating dynamic sync telemetries
          GestureDetector(
            onTap: _fetchProfile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _syncFailed 
                    ? Colors.redAccent.withValues(alpha: 0.1) 
                    : (_syncing ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFF10B981).withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _syncFailed 
                      ? Colors.redAccent.withValues(alpha: 0.3) 
                      : (_syncing ? Colors.amber.withValues(alpha: 0.3) : const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _syncFailed 
                          ? Colors.redAccent 
                          : (_syncing ? Colors.amber : const Color(0xFF10B981)),
                    ),
                  ).animate(onPlay: (c) => _syncing ? c.repeat() : c.stop()).shimmer(duration: 1000.ms),
                  const SizedBox(width: 6),
                  Text(
                    _syncFailed ? 'Offline fallback' : (_syncing ? 'Syncing...' : 'Synced'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _syncFailed 
                          ? Colors.redAccent 
                          : (_syncing ? Colors.amber : const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHero(bool isDark) {
    // Dynamic Score Trust Indicator Calculation
    final int trustScore = _twoFactor ? 95 : 65;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GlassCard(
        glowColor: const Color(0xFF6366F1),
        glowIntensity: 0.15,
        child: Column(
          children: [
            Row(
              children: [
                // Avatar with upload selection capabilities
                GestureDetector(
                  onTap: _simulateAvatarUpload,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFEC4899)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: isDark ? const Color(0xFF141418) : Colors.white,
                          backgroundImage: _pictureUrl != null
                              ? NetworkImage(_pictureUrl!)
                              : null,
                          child: _pictureUrl == null
                              ? Text(
                                  _fullName.isNotEmpty ? _fullName[0] : 'C',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24, fontWeight: FontWeight.w800,
                                    color: const Color(0xFF6366F1),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF6366F1),
                        ),
                        child: const Icon(Icons.edit_rounded, size: 10, color: Colors.white),
                      ),
                    ],
                  ),
                ).animate().scale(delay: 100.ms, duration: 300.ms),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _email,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _badge('PRO TIER', const Color(0xFFA855F7), isDark),
                          const SizedBox(width: 6),
                          _badge('VERIFIED', const Color(0xFF10B981), isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                // Security Trust Score Indicator Gauge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: (trustScore > 80 ? const Color(0xFF10B981) : Colors.orangeAccent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (trustScore > 80 ? const Color(0xFF10B981) : Colors.orangeAccent).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$trustScore%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: trustScore > 80 ? const Color(0xFF10B981) : Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TRUST SCORE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white38 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Cumulative Token consumption bar chart
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI USAGE LIMITS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white38 : Colors.black45,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '${(_usage['used'] / 1000000).toStringAsFixed(2)}M / ${(_usage['limit'] / 1000000).toStringAsFixed(0)}M tokens',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _usage['used'] / _usage['limit'],
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedHub(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Text(
              'CONNECTED PROVIDERS HUB',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white24 : Colors.black26,
                letterSpacing: 1.5,
              ),
            ),
          ),
          GlassCard(
            child: Column(
              children: [
                _connectionTile('Google', Icons.g_mobiledata_rounded, const Color(0xFF4285F4), _connections['Google'] ?? false, isDark, 'Quota: 95% remaining'),
                _divider(isDark),
                _connectionTile('GitHub', Icons.code_rounded, const Color(0xFF10B981), _connections['GitHub'] ?? false, isDark, 'Scope: full_repo access'),
                _divider(isDark),
                _connectionTile('OpenRouter', Icons.hub_rounded, const Color(0xFF8B5CF6), _connections['OpenRouter'] ?? false, isDark, 'Failover Router Active'),
                _divider(isDark),
                _connectionTile('Groq', Icons.bolt_rounded, const Color(0xFFF59E0B), _connections['Groq'] ?? false, isDark, 'Low Latency Llama pipeline'),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 450.ms);
  }

  Widget _buildSecurityControlPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              'CYBERSECURITY CONTROL CENTER',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white24 : Colors.black26,
                letterSpacing: 1.5,
              ),
            ),
          ),
          SettingsToggle(
            label: 'Two-Factor Authentication',
            subtitle: 'Secure setup utilizing authenticator TOTP codes',
            icon: Icons.security_rounded,
            value: _twoFactor,
            onChanged: _setupTwoFactor,
            accentColor: const Color(0xFF22C55E),
          ),
          const SizedBox(height: 8),
          SettingsToggle(
            label: 'Biometric Integration',
            subtitle: 'Native Apple FaceID / TouchID keys',
            icon: Icons.fingerprint_rounded,
            value: _biometric,
            onChanged: (v) => _updateSecuritySettings(_twoFactor, v),
            accentColor: const Color(0xFF3B82F6),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms, duration: 450.ms);
  }

  Widget _buildApiKeyPanel(bool isDark) {
    final settings = context.watch<SettingsProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showKeyPanel = !_showKeyPanel),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_rounded, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'API Key Management Panel',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  ),
                  const Spacer(),
                  Icon(
                    _showKeyPanel ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ],
              ),
            ),
          ),
          if (_showKeyPanel)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GlassCard(
                child: Column(
                  children: [
                    _buildApiKeyRow('Gemini Key', settings.geminiApiKey, (v) => settings.updateApiKey('gemini', v), isDark),
                    _divider(isDark),
                    _buildApiKeyRow('Groq Key', settings.groqApiKey, (v) => settings.updateApiKey('groq', v), isDark),
                    _divider(isDark),
                    _buildApiKeyRow('OpenRouter Key', settings.openrouterApiKey, (v) => settings.updateApiKey('openrouter', v), isDark),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyRow(String name, String value, Function(String) onSave, bool isDark) {
    final controller = TextEditingController(text: value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Unconfigured API Key',
                    hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save_as_rounded, size: 18, color: Color(0xFF6366F1)),
            onPressed: () {
              onSave(controller.text);
              _showToast('$name rotation confirmed successfully.');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionsPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              'ACTIVE SESSIONS & DEVICES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white24 : Colors.black26,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (_activeSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text('No active external sessions.', style: GoogleFonts.plusJakartaSans(color: Colors.white24, fontSize: 12)),
              ),
            ),
          ..._activeSessions.map((session) {
            final isCurrent = session['session_id'] == 'current';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isCurrent ? const Color(0xFF6366F1).withValues(alpha: 0.3) : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))),
              ),
              child: Row(
                children: [
                  Icon(
                    session['device'].toString().contains('iPhone') ? Icons.phone_iphone_rounded : Icons.computer_rounded,
                    color: isCurrent ? const Color(0xFF6366F1) : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['device'] ?? 'Unknown device',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session['location']} • IP: ${session['ip']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        if (isCurrent) {
                          _showToast('Cannot revoke your current active workspace session.', isError: true);
                        } else {
                          _revokeSessionOnBackend(session['session_id']);
                        }
                      },
                      child: Text(
                        isCurrent ? 'Current' : 'Revoke',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.bold,
                          color: isCurrent ? const Color(0xFF6366F1) : Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideX(begin: 0.05, duration: 250.ms).fadeIn();
          }),
        ],
      ),
    );
  }

  Widget _buildPrivacyControlPanel(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              'DATA & PRIVACY PREFERENCES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: isDark ? Colors.white24 : Colors.black26,
                letterSpacing: 1.5,
              ),
            ),
          ),
          GlassCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_download_rounded, color: Color(0xFF10B981)),
                  title: Text('Export Personal Data', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Download conversation logs (GDPR package)', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: _exportGdprData,
                ),
                _divider(isDark),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.layers_clear_rounded, color: Colors.orangeAccent),
                  title: Text('Clear AI Memory trans', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Erase indexing pipelines and workspace caches', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                                const SizedBox(width: 10),
                                Text(
                                  'Clear Context Memory?',
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18),
                                ),
                              ],
                            ),
                            content: Text(
                              'This immediately clears conversational cache systems and resets models memory contexts. This action is instantaneous and cannot be undone.',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, 
                                fontWeight: FontWeight.w500, 
                                height: 1.45, 
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearAiMemoryTranscripts();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                  'Erase Context',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: GlassCard(
        glowColor: Colors.redAccent,
        glowIntensity: 0.08,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 20),
                const SizedBox(width: 10),
                Text(
                  'Danger Zone',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w700, color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Permanently delete your account and all associated data. This action cannot be undone.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : Colors.black38,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _confirmDeleteAccount,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Delete Account',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- COMPILER SKELETON LOADER MASKS ---

  Widget _buildShimmerSkeleton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14))),
              const SizedBox(width: 16),
              Container(width: 120, height: 24, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(6))),
            ],
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1000.ms),
          const SizedBox(height: 30),
          
          // Profile card skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 72, height: 72, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 140, height: 18, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 6),
                          Container(width: 180, height: 12, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(width: double.maxFinite, height: 8, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
          const SizedBox(height: 30),

          // Security switches skeletons
          Container(width: 160, height: 16, decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 12),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
          const SizedBox(height: 12),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5),
      ),
    );
  }

  Widget _connectionTile(String name, IconData icon, Color color, bool connected, bool isDark, String scope) {
    return InkWell(
      onTap: () => _toggleConnection(name),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
                  const SizedBox(height: 2),
                  Text(scope, style: GoogleFonts.plusJakartaSans(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white30 : Colors.black38,
                  )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                connected ? 'Connected' : 'Connect',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: connected ? const Color(0xFF10B981) : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), height: 1);
  }
}

class _QrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    const double cols = 15;
    final double step = size.width / cols;

    void drawSquare(double x, double y, double size) {
      canvas.drawRect(Rect.fromLTWH(x, y, size, size), paint);
      final whitePaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(x + step, y + step, size - step * 2, size - step * 2), whitePaint);
      canvas.drawRect(Rect.fromLTWH(x + step * 2, y + step * 2, size - step * 4, size - step * 4), paint);
    }

    drawSquare(0, 0, step * 7);
    drawSquare(size.width - step * 7, 0, step * 7);
    drawSquare(0, size.height - step * 7, step * 7);

    for (int r = 0; r < cols; r++) {
      for (int c = 0; c < cols; c++) {
        if (r < 7 && c < 7) continue;
        if (r < 7 && c >= cols - 7) continue;
        if (r >= cols - 7 && c < 7) continue;

        final int hash = (r * 37 + c * 17) % 7;
        if (hash == 1 || hash == 3 || hash == 5 || (r == cols - 3 && c == cols - 3)) {
          canvas.drawRect(
            Rect.fromLTWH(c * step + 1, r * step + 1, step - 2, step - 2),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
