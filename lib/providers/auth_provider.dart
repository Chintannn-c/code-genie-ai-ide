import 'package:flutter/material.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, authenticating }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _user = await _authService.getSession();
    if (_user != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String fullName) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.register(email, password, fullName);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> googleLogin() async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.loginWithGoogle();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _error = null;
    notifyListeners();
    try {
      await _authService.forgotPassword(email);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
