import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<String> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse("${ApiConstants.baseUrl}/api/auth/login/"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"username": username, "password": password}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        await _storage.write(key: "token", value: data["token"]);
        await _storage.write(key: "role", value: data["role"]);
        await _storage.write(key: "username", value: data["username"]);
        await _storage.write(key: "user_id", value: data["user_id"].toString());
        return data["role"] as String;
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        throw AuthException("Invalid credentials. Please try again.");
      }

      throw AuthException(
        "Login failed (HTTP ${response.statusCode}). Please try again.",
      );
    } on SocketException {
      throw AuthException(
        "Cannot reach backend server. Check API URL and backend runserver host.",
      );
    } on TimeoutException {
      throw AuthException(
        "Server connection timed out. Check network or backend status.",
      );
    } catch (_) {
      throw AuthException("Login failed. Please try again.");
    }
  }
}
