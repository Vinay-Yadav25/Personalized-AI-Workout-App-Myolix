import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class AuthProvider extends ChangeNotifier {
  String? token;
  String? userName;
  int? userId;
  bool hasProfile = false;
  String? error; // FIX: expose last error so UI can show it

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    token    = prefs.getString('token');
    userName = prefs.getString('userName');
    userId   = prefs.getInt('userId');
    hasProfile = prefs.getBool('hasProfile') ?? false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    error = null;
    try {
      final res = await Api.post('/auth/login.php', {
        'email': email,
        'password': password,
      });
      if (res['token'] != null) {
        token    = res['token'] as String;
        userName = res['user']?['name'] as String?;
        // FIX: userId from JSON is int but may come as String on some servers
        userId   = (res['user']?['id'] as num?)?.toInt();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token!);
        if (userName != null) await prefs.setString('userName', userName!);
        if (userId != null)   await prefs.setInt('userId', userId!);
        notifyListeners();
        return true;
      }
      error = res['error'] as String? ?? 'Login failed';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> signup(String name, String email, String password) async {
    error = null;
    try {
      final res = await Api.post('/auth/signup.php', {
        'name': name,
        'email': email,
        'password': password,
      });
      if (res['success'] == true) return true;
      error = res['error'] as String? ?? 'Signup failed';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> sendOtp(String email) async {
    error = null;
    try {
      final res = await Api.post('/auth/forgot_password.php', {'email': email});
      if (res.containsKey('success')) return true;
      error = res['error'] as String? ?? 'Failed to send OTP';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> resetPassword(String email, String otp, String password) async {
    error = null;
    try {
      final res = await Api.post('/auth/reset_password.php', {
        'email': email,
        'otp': otp,
        'password': password,
      });
      if (res['success'] == true) return true;
      error = res['error'] as String? ?? 'Failed to reset password';
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<void> markProfileComplete() async {
    hasProfile = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasProfile', true);
    notifyListeners();
  }

  Future<void> logout() async {
    token    = null;
    userName = null;
    userId   = null;
    hasProfile = false;
    error    = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}