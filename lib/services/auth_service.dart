import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
    try {
      print('🚀 [AuthService] Initiating Google Sign-In...');
      
      // Try silent sign-in first with a slightly longer timeout for web
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently().timeout(
          const Duration(seconds: 1),
          onTimeout: () => null,
        );
      } catch (e) {
        print('📡 [AuthService] Silent sign-in error (ignoring): $e');
      }
      
      if (googleUser == null) {
        print('📡 [AuthService] No silent session, launching popup...');
        googleUser = await _googleSignIn.signIn();
      }
      
      if (googleUser == null) {
        print('⚠️ [AuthService] Sign-in cancelled or popup closed.');
        throw Exception('Google sign-in cancelled');
      }
      
      print('✅ [AuthService] User: ${googleUser.email}');
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      print('🛡️ [AuthService] Google Authentication retrieved: ${googleAuth.idToken != null}');
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('❌ [AuthService] ID Token is NULL. Scopes: ${googleUser.authHeaders}');
        throw Exception('Failed to get ID token from Google. Please ensure you are connected to the internet and try again.');
      }

      // Send ID token to our backend
      final response = await _client.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.googleLogin}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data);
        await _saveSession(user);
        return user;
      } else {
        final error =
            jsonDecode(response.body)['detail'] ?? 'Google login failed';
        throw Exception(error);
      }
    } catch (e) {
      print('❌ [AuthService] Google Login Failed: $e');
      rethrow;
    } finally {
      _isSigningIn = false;
    }
  }

  /// Login with email and password
  Future<User> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
      headers: {'Content-Type': 'application/json'},
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
      headers: {'Content-Type': 'application/json'},
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

  /// Save session to shared preferences
  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', user.token);
    await prefs.setString('user_id', user.userId);
    await prefs.setString('email', user.email);
    if (user.fullName != null) {
      await prefs.setString('full_name', user.fullName!);
    }
    if (user.pictureUrl != null) {
      await prefs.setString('picture_url', user.pictureUrl!); // ASSET FIX: Persist picture URL
    }
  }

  /// Get current session
  Future<User?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return null;

    return User(
      userId: prefs.getString('user_id') ?? '',
      email: prefs.getString('email') ?? '',
      fullName: prefs.getString('full_name'),
      pictureUrl: prefs.getString('picture_url'), // ASSET FIX: Retrieve picture URL
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Also sign out from Google to allow switching accounts
    await _googleSignIn.signOut();
  }
}
