import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  // FIX 1: Path was '/ai_workout_application/backend/api' — that subfolder
  //         doesn't exist on your server. Confirmed working path is /backend/api.
  //         Use your PC's local IP so physical devices on the same Wi-Fi can reach it.
  static const baseUrl = "http://192.168.29.86/backend/api";

  static const _timeout = Duration(seconds: 10); // FIX 2: was no timeout

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    return {
      "Content-Type": "application/json",
      if (token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // FIX 3: body was untyped Map — typed to Map<String, dynamic>
  // FIX 4: no error handling — jsonDecode throws on HTML error pages
  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(
        Uri.parse("$baseUrl$path"),
        headers: await _headers(),
        body: jsonEncode(body),
      )
          .timeout(_timeout);
      return _decode(res);
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final res = await http
          .get(Uri.parse("$baseUrl$path"), headers: await _headers())
          .timeout(_timeout);
      return _decode(res);
    } catch (e) {
      return {"error": e.toString()};
    }
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      // Backend returned a list (shouldn't happen but guard anyway)
      return {"data": decoded};
    } catch (_) {
      // PHP returned HTML (fatal error, wrong path, etc.)
      return {
        "error": "Server error (status ${res.statusCode}). Check baseUrl.",
      };
    }
  }
}