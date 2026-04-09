import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _productionBaseUrl =
      'https://library-book-reservation-app-3eyv.onrender.com';
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const bool hasOverrideBaseUrl = _overrideBaseUrl != '';

  static String get baseUrl {
    if (hasOverrideBaseUrl) {
      return _overrideBaseUrl;
    }
    return _productionBaseUrl;
  }

  static String normalizeBaseUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }

  static String get normalizedBaseUrl => normalizeBaseUrl(baseUrl);

  static String get apiRoot {
    final base = normalizedBaseUrl;
    return base.endsWith('/api') ? base : '$base/api';
  }

  static String apiUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$apiRoot$normalizedPath';
  }

  static String apiUrlForBase(String base, String path) {
    final normalizedBase = normalizeBaseUrl(base);
    final root = normalizedBase.endsWith('/api')
        ? normalizedBase
        : '$normalizedBase/api';
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$root$normalizedPath';
  }
}
