import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config/api_config.dart';

class User {
  final String userId;
  final String email;
  final String? fullName;
  final String? pictureUrl; // ASSET FIX: Profile image URL
  final String token;

  User({
    required this.userId,
    required this.email,
    this.fullName,
    this.pictureUrl,
    required this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      email: json['email'],
      fullName: json['full_name'],
      pictureUrl: json['picture_url'], // ASSET FIX: Map from API response
      token: json['access_token'],
    );
  }
}

class AuthService {
  final http.Client _client = http.Client();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId: '782488713921-bbvrh956b8pb8vdb978uflg0tsmsk4g3.apps.googleusercontent.com',
          scopes: <String>[
            'email',
            'https://www.googleapis.com/auth/userinfo.profile',
            'openid',
          ],
        )
      : GoogleSignIn(
          // serverClientId MUST be the Web Client ID for backend verification to work on Android
          serverClientId: '782488713921-bbvrh956b8pb8vdb978uflg0tsmsk4g3.apps.googleusercontent.com',
        );

  AuthService();

  bool _isSigningIn = false;

  /// Login with Google (Direct OAuth2, no Firebase)
  Future<User> loginWithGoogle() async {
    if (_isSigningIn) {
      throw Exception('Sign-in already in progress');
    }
    
    _isSigningIn = true;
    final stopwatch = Stopwatch()..start();
    try {
      print('🚀 [AuthService] Initiating Google Sign-In...');
      
      // Try silent sign-in first with a more reasonable timeout
      GoogleSignInAccount? googleUser;
      try {
        print('📡 [AuthService] Attempting silent sign-in...');
        googleUser = await _googleSignIn.signInSilently().timeout(
          const Duration(seconds: 5), // Increased from 1s to 5s for better reliability
          onTimeout: () {
            print('📡 [AuthService] Silent sign-in timed out after 5s');
            return null;
          },
        );
      } catch (e) {
        print('📡 [AuthService] Silent sign-in error: $e');
      }
      
      if (googleUser == null) {
        print('📡 [AuthService] No silent session, launching interactive popup...');
        googleUser = await _googleSignIn.signIn();
      }
      
      if (googleUser == null) {
        print('⚠️ [AuthService] Sign-in cancelled by user.');
        throw Exception('Google sign-in cancelled');
      }
      
      print('✅ [AuthService] Google account selected (${stopwatch.elapsedMilliseconds}ms): ${googleUser.email}');
      
      final authStart = stopwatch.elapsedMilliseconds;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('🛡️ [AuthService] Google Tokens retrieved (${stopwatch.elapsedMilliseconds - authStart}ms)');
      
      final String? idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Failed to get ID token from Google.');
      }

      // Send ID token to our backend
      print('📤 [AuthService] Verifying with backend...');
      final backendStart = stopwatch.elapsedMilliseconds;
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.googleLogin}'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
          'ngrok-skip-browser-warning': 'true',
          'X-Platform': kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Desktop')),
          'X-Device-Name': kIsWeb ? 'Browser' : (defaultTargetPlatform == TargetPlatform.macOS ? 'macOS Desktop' : (defaultTargetPlatform == TargetPlatform.windows ? 'Windows Desktop' : (defaultTargetPlatform == TargetPlatform.linux ? 'Linux Desktop' : 'Native Client'))),
        },
        body: jsonEncode({'id_token': idToken}),
      ).timeout(const Duration(seconds: 15)); // Add timeout to backend call

      print('📥 [AuthService] Backend responded (${stopwatch.elapsedMilliseconds - backendStart}ms) with status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data);
        await _saveSession(user);
        print('✨ [AuthService] Login complete! Total time: ${stopwatch.elapsedMilliseconds}ms');
        return user;
      } else {
        String errorDetail;
        try {
          final data = jsonDecode(response.body);
          errorDetail = data['detail'] ?? 'Authentication failed (${response.statusCode})';
        } catch (_) {
          errorDetail = 'Backend error (${response.statusCode}). Please check server logs.';
        }
        print('❌ [AuthService] Backend Auth Error: $errorDetail');
        throw Exception(errorDetail);
      }
    } catch (e) {
      print('❌ [AuthService] Google Login Failed: $e');
      if (e.toString().contains('cancelled')) {
        throw Exception('Sign-in was cancelled.');
      }
      rethrow;
    } finally {
      _isSigningIn = false;
      stopwatch.stop();
    }
  }

  /// Login with email and password
  Future<User> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        'ngrok-skip-browser-warning': 'true',
        'X-Platform': kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Desktop')),
        'X-Device-Name': kIsWeb ? 'Browser' : (defaultTargetPlatform == TargetPlatform.macOS ? 'macOS Desktop' : (defaultTargetPlatform == TargetPlatform.windows ? 'Windows Desktop' : (defaultTargetPlatform == TargetPlatform.linux ? 'Linux Desktop' : 'Native Client'))),
      },
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = User.fromJson(data);
      await _saveSession(user);
      return user;
    } else {
      final error = jsonDecode(response.body)['detail'] ?? 'Login failed';
      throw Exception(error);
    }
  }

  /// Register new user
  Future<User> register(String email, String password, String fullName) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.register}'),
      headers: {
        'Content-Type': 'application/json',
        'Bypass-Tunnel-Reminder': 'true',
        'ngrok-skip-browser-warning': 'true',
        'X-Platform': kIsWeb ? 'Web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : (defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'Desktop')),
        'X-Device-Name': kIsWeb ? 'Browser' : (defaultTargetPlatform == TargetPlatform.macOS ? 'macOS Desktop' : (defaultTargetPlatform == TargetPlatform.windows ? 'Windows Desktop' : (defaultTargetPlatform == TargetPlatform.linux ? 'Linux Desktop' : 'Native Client'))),
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = User.fromJson(data);
      await _saveSession(user);
      return user;
    } else {
      final error =
          jsonDecode(response.body)['detail'] ?? 'Registration failed';
      throw Exception(error);
    }
  }

  /// Save session to secure storage
  Future<void> _saveSession(User user) async {
    // 1. Save sensitive token to encrypted storage
    await _secureStorage.write(key: 'token', value: user.token);
    
    // 2. Save other data to SharedPreferences for fast access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.userId);
    await prefs.setString('email', user.email);
    if (user.fullName != null) {
      await prefs.setString('full_name', user.fullName!);
    }
    if (user.pictureUrl != null) {
      await prefs.setString('picture_url', user.pictureUrl!);
    }
  }

  /// Get current session
  Future<User?> getSession() async {
    final token = await _secureStorage.read(key: 'token');
    if (token == null) return null;

    final prefs = await SharedPreferences.getInstance();
    return User(
      userId: prefs.getString('user_id') ?? '',
      email: prefs.getString('email') ?? '',
      fullName: prefs.getString('full_name'),
      pictureUrl: prefs.getString('picture_url'),
      token: token,
    );
  }

  /// Request password reset
  Future<void> forgotPassword(String email) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forgotPassword}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      final error =
          jsonDecode(response.body)['detail'] ??
          'Password reset request failed';
      throw Exception(error);
    }
  }

  /// Clear session
  Future<void> signOut() async {
    await _secureStorage.delete(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Also sign out from Google to allow switching accounts
    await _googleSignIn.signOut();
  }
}
