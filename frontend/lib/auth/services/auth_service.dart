import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  static Future<void> _persistAuth(Map<String, dynamic> data) async {
    await _storage.write(key: "token", value: data["token"] as String);
    await _storage.write(key: "role", value: data["role"] as String);
    await _storage.write(key: "username", value: data["username"] as String);
    await _storage.write(key: "user_id", value: data["user_id"].toString());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", data["token"] as String);
    await prefs.setString("role", data["role"] as String);
    await prefs.setString("username", data["username"] as String);
    await prefs.setString("user_id", data["user_id"].toString());
    await AppNotificationService.ensureInitialized();
  }

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
             await _persistAuth(data as Map<String, dynamic>);
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
        "Cannot reach backend at: ${baseUrls.join(', ')}.",
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException("Login failed. Please try again.");
    }
  }

  static Future<String> register({
    required String username,
    required String studentId,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.apiUrl("/auth/register/")),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": username.trim(),
              "student_id": studentId.trim(),
              "password": password,
              "confirm_password": confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 12));

      final body = _decodeJsonObject(response.body);

      if (response.statusCode == 201) {
        await _persistAuth(body);
        return body["role"] as String;
      }

      throw AuthException(
        _extractErrorMessage(
          body,
          fallback:
              "Registration failed (HTTP ${response.statusCode}). Please try again.",
        ),
      );
    } on SocketException {
      throw AuthException("Cannot reach backend. Check your internet connection.");
    } on TimeoutException {
      throw AuthException("Registration timed out. Please try again.");
    } on http.ClientException {
      throw AuthException("Could not connect to the backend service.");
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException("Registration failed. Please try again.");
    }
  }

  static String _extractErrorMessage(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    if (body["detail"] is String) {
      return body["detail"] as String;
    }
    if (body["message"] is String) {
      return body["message"] as String;
    }

    for (final entry in body.entries) {
      final value = entry.value;
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }

    return fallback;
  }

  static Map<String, dynamic> _decodeJsonObject(String rawBody) {
    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Some server errors come back as HTML; fall through to an empty body
      // so the caller can surface a useful fallback message.
    }

    return <String, dynamic>{};
  }

  static List<String> _loginBaseUrls() {
    final configured = ApiConstants.normalizedBaseUrl;
    return <String>[configured]
        .map(ApiConstants.normalizeBaseUrl)
        .toSet()
        .toList();
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
