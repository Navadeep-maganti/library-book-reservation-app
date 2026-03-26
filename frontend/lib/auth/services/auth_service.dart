import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/app_notification_service.dart';

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<String> login(String username, String password) async {
    final baseUrls = _loginBaseUrls();

    try {
      for (final baseUrl in baseUrls) {
        try {
          final response = await http
              .post(
            Uri.parse(ApiConstants.apiUrlForBase(baseUrl, "/auth/login/")),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"username": username, "password": password}),
          )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            await _storage.write(key: "token", value: data["token"]);
            await _storage.write(key: "role", value: data["role"]);
            await _storage.write(key: "username", value: data["username"]);
            await _storage.write(
              key: "user_id",
              value: data["user_id"].toString(),
            );
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString("token", data["token"] as String);
            await prefs.setString("role", data["role"] as String);
            await prefs.setString("username", data["username"] as String);
            await prefs.setString("user_id", data["user_id"].toString());
            await AppNotificationService.ensureInitialized();
            return data["role"] as String;
          }

          if (response.statusCode == 400 || response.statusCode == 401) {
            throw AuthException("Invalid credentials. Please try again.");
          }

          throw AuthException(
            "Login failed at ${ApiConstants.normalizeBaseUrl(baseUrl)} "
            "(HTTP ${response.statusCode}).",
          );
        } on SocketException {
          // Try next fallback URL.
          continue;
        } on TimeoutException {
          // Try next fallback URL.
          continue;
        } on http.ClientException {
          // Try next fallback URL.
          continue;
        }
      }

      throw AuthException(
        "Cannot reach backend at: ${baseUrls.join(', ')}. "
        "If using a real phone, run with --dart-define=API_BASE_URL=http://<PC_LAN_IP>:8000",
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException("Login failed. Please try again.");
    }
  }

  static List<String> _loginBaseUrls() {
    final configured = ApiConstants.normalizedBaseUrl;
    final urls = <String>[configured];

    if (!kIsWeb && Platform.isAndroid && !ApiConstants.hasOverrideBaseUrl) {
      urls.addAll([
        "http://127.0.0.1:8000",
        "http://localhost:8000",
      ]);
    }

    return urls.map(ApiConstants.normalizeBaseUrl).toSet().toList();
  }

  static Future<void> logout() async {
    final token = await _storage.read(key: "token");

    await AppNotificationService.unregisterCurrentDevice();

    if (token != null && token.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse(ApiConstants.apiUrl("/auth/logout/")),
              headers: {
                "Authorization": "Token $token",
                "Content-Type": "application/json",
              },
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Best effort: clear local auth state even if server cannot be reached.
      }
    }

    await _storage.delete(key: "token");
    await _storage.delete(key: "role");
    await _storage.delete(key: "username");
    await _storage.delete(key: "user_id");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("role");
    await prefs.remove("username");
    await prefs.remove("user_id");
  }

  static Future<String> getInitialRoute() async {
    final token = await _storage.read(key: "token");
    final role = await _storage.read(key: "role");

    if (token == null || token.isEmpty) return "/login";
    if (role == "librarian") return "/librarian";
    if (role == "student") return "/student";
    return "/login";
  }
  static Future<String> getUsername() async {
    final username = await _storage.read(key: "username");
    return username ?? "Unknown";
  }
}
