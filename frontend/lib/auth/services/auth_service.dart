import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/api_constants.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<void> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("${ApiConstants.baseUrl}/api/auth/login/"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await _storage.write(key: "token", value: data["token"]);
      await _storage.write(key: "role", value: data["role"]);
      await _storage.write(key: "username", value: data["username"]);
      await _storage.write(key: "user_id", value: data["user_id"].toString());
    } else {
      throw Exception("Invalid credentials");
    }
  }
}
