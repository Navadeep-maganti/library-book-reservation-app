import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'offline_cache_service.dart';

class BookAPI {
  static const _storage = FlutterSecureStorage();
  static String get _booksEndpoint => ApiConstants.apiUrl('/books/');
  static const _booksCacheKey = "books_all";

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getBooks() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: _booksCacheKey,
      uri: Uri.parse(_booksEndpoint),
      token: token,
      failureMessage: "Failed to get books",
    );
  }

  static Future<Map<String, dynamic>> searchBooks({
    String? title,
    String? author,
    String? isbn,
    String? category,
    bool availableOnly = false,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final params = {
        if (title != null) 'title': title,
        if (author != null) 'author': author,
        if (isbn != null) 'isbn': isbn,
        if (category != null) 'category': category,
        if (availableOnly) 'available_only': 'true',
      };

      final uri = Uri.parse(
        '${_booksEndpoint}search/',
      ).replace(queryParameters: params);

      final books = await OfflineCacheService.getList(
        cacheKey:
            "books_search_${title ?? ""}_${author ?? ""}_${isbn ?? ""}_${category ?? ""}_${availableOnly ? "available" : "all"}",
        uri: uri,
        token: token,
        failureMessage: "Failed to search books",
      );
      return {"books": books};
    } catch (e) {
      final books = await getBooks();
      final filtered = books.where((book) {
        final bookTitle = "${book["title"] ?? ""}".toLowerCase();
        final bookAuthor = "${book["author"] ?? ""}".toLowerCase();
        final bookIsbn = "${book["isbn"] ?? ""}".toLowerCase();
        final bookCategory = "${book["category"] ?? ""}".toLowerCase();
        final availableCopies = book["available_copies"];
        final isAvailable = availableCopies is num
            ? availableCopies > 0
            : int.tryParse("$availableCopies") != null &&
                  int.parse("$availableCopies") > 0;

        final matchesTitle =
            title == null || bookTitle.contains(title.toLowerCase());
        final matchesAuthor =
            author == null || bookAuthor.contains(author.toLowerCase());
        final matchesIsbn =
            isbn == null || bookIsbn.contains(isbn.toLowerCase());
        final matchesCategory =
            category == null || bookCategory.contains(category.toLowerCase());

        return matchesTitle &&
            matchesAuthor &&
            matchesIsbn &&
            matchesCategory &&
            (!availableOnly || isAvailable);
      }).toList();
      return {"books": filtered};
    }
  }

  static Future<Map<String, dynamic>> getBookAvailability(int bookId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getMap(
      cacheKey: "book_availability_$bookId",
      uri: Uri.parse("$_booksEndpoint$bookId/availability/"),
      token: token,
      failureMessage: "Failed to get availability",
    );
  }

  static Future<Map<String, dynamic>> getDigitalAccess(int bookId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    final response = await http.get(
      Uri.parse("$_booksEndpoint$bookId/digital-access/"),
      headers: {"Authorization": "Token $token"},
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }

    Map<String, dynamic> error = const {};
    try {
      error = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    throw Exception(error["error"] ?? "Failed to open digital copy");
  }

  static Future<Map<String, dynamic>> getReaderContent(int bookId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    final response = await http.get(
      Uri.parse("$_booksEndpoint$bookId/read-content/"),
      headers: {"Authorization": "Token $token"},
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    }

    Map<String, dynamic> error = const {};
    try {
      error = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    throw Exception(error["error"] ?? "Failed to load reader content");
  }
}
