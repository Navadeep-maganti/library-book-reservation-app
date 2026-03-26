import "dart:convert";

import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";

class OfflineCacheService {
  static const String _prefix = "offline_cache";

  static String _payloadKey(String cacheKey) => "$_prefix:$cacheKey:payload";
  static String _scopedCacheKey(String cacheKey, String token) =>
      "$cacheKey:${_stableTokenHash(token)}";

  static Future<void> saveJson(String cacheKey, Object data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_payloadKey(cacheKey), jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> readMap(String cacheKey) async {
    final decoded = await _readDecoded(cacheKey);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> readList(String cacheKey) async {
    final decoded = await _readDecoded(cacheKey);
    if (decoded is! List) return null;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> getMap({
    required String cacheKey,
    required Uri uri,
    required String token,
    required String failureMessage,
  }) async {
    final scopedKey = _scopedCacheKey(cacheKey, token);
    final cached = await readMap(scopedKey);

    try {
      final response = await http
          .get(
            uri,
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
        await saveJson(scopedKey, data);
        return data;
      }
      if (cached != null) return cached;
      throw Exception(failureMessage);
    } catch (e) {
      if (cached != null) return cached;
      throw Exception("$failureMessage: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> getList({
    required String cacheKey,
    required Uri uri,
    required String token,
    required String failureMessage,
  }) async {
    final scopedKey = _scopedCacheKey(cacheKey, token);
    final cached = await readList(scopedKey);

    try {
      final response = await http
          .get(
            uri,
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = (jsonDecode(response.body) as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        await saveJson(scopedKey, data);
        return data;
      }
      if (cached != null) return cached;
      throw Exception(failureMessage);
    } catch (e) {
      if (cached != null) return cached;
      throw Exception("$failureMessage: $e");
    }
  }

  static Future<dynamic> _readDecoded(String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_payloadKey(cacheKey));
    if (raw == null || raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  static Future<void> invalidateAllForToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final tokenHash = _stableTokenHash(token);
    final suffix = ":$tokenHash:payload";

    for (final key in prefs.getKeys()) {
      if (key.startsWith("$_prefix:") && key.endsWith(suffix)) {
        await prefs.remove(key);
      }
    }
  }

  static int _stableTokenHash(String token) {
    var hash = 0;
    for (final unit in token.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return hash;
  }
}
