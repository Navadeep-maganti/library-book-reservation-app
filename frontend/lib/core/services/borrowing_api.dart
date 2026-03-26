import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import 'offline_cache_service.dart';

class BorrowingAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/borrowing/');
  static const _myBooksCacheKey = "borrowing_my_books";

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getMyBooks() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: _myBooksCacheKey,
      uri: Uri.parse('${_endpoint}my_books/'),
      token: token,
      failureMessage: "Failed to get books",
    );
  }

  static Future<Map<String, dynamic>> issueBook(int bookId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse('${_endpoint}issue/'),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"book_id": bookId}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to issue book');
      }
      throw Exception('Failed to issue book');
    } catch (e) {
      throw Exception("Failed to issue book: $e");
    }
  }

  static Future<Map<String, dynamic>> returnBook(
    int issuedBookId, {
    String condition = 'good',
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse('${_endpoint}$issuedBookId/return_book/'),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"condition": condition}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      }
      throw Exception('Failed to return book');
    } catch (e) {
      throw Exception("Failed to return book: $e");
    }
  }
}
