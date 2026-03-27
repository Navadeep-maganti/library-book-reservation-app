import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import 'offline_cache_service.dart';

class DashboardAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/dashboard/summary/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getMap(
      cacheKey: "dashboard_summary",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get dashboard",
    );
  }
}

class BorrowHistoryAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/history/my_history/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getBorrowHistory() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: "borrow_history",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get history",
    );
  }
}

class ReservationAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/reservations/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getReservations() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: "reservations",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get reservations",
    );
  }

  static Future<Map<String, dynamic>> makeReservation(int bookId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse('${_endpoint}reserve/'),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"book_id": bookId}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 201) {
        final data = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to reserve');
      }
      throw Exception('Failed to reserve');
    } catch (e) {
      throw Exception("Failed to reserve: $e");
    }
  }

  static Future<void> cancelReservation(int reservationId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse("$_endpoint$reservationId/cancel/"),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        await OfflineCacheService.invalidateAllForToken(token);
        return;
      }
      throw Exception('Failed to cancel reservation');
    } catch (e) {
      throw Exception("Failed to cancel reservation: $e");
    }
  }
}

class FineAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/fines/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getFines() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: "fines",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get fines",
    );
  }

  static Future<Map<String, dynamic>> getFineSummary() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getMap(
      cacheKey: "fine_summary",
      uri: Uri.parse('${_endpoint}summary/'),
      token: token,
      failureMessage: "Failed to get fine summary",
    );
  }

  static Future<Map<String, dynamic>> payFine(
    int fineId, {
    required double amountPaid,
    String paymentMethod = "online",
    String? transactionId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse("$_endpoint$fineId/pay/"),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "amount_paid": amountPaid,
              "payment_method": paymentMethod,
              if (transactionId != null && transactionId.isNotEmpty)
                "transaction_id": transactionId,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      }
      final data = jsonDecode(response.body);
      throw Exception(data["error"] ?? "Failed to pay fine");
    } catch (e) {
      throw Exception("Failed to pay fine: $e");
    }
  }
}

class DueAlertsAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/alerts/upcoming/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<Map<String, dynamic>> getDueAlerts({int days = 7}) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getMap(
      cacheKey: "due_alerts_$days",
      uri: Uri.parse(_endpoint).replace(queryParameters: {"days": "$days"}),
      token: token,
      failureMessage: "Failed to get alerts",
    );
  }
}

class AnnouncementAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/announcements/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: "announcements",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get announcements",
    );
  }
}

class NotificationAPI {
  static const _storage = FlutterSecureStorage();
  static String get _endpoint => ApiConstants.apiUrl('/notifications/');

  static Future<String?> _getToken() async {
    return await _storage.read(key: "token");
  }

  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    return OfflineCacheService.getList(
      cacheKey: "notifications",
      uri: Uri.parse(_endpoint),
      token: token,
      failureMessage: "Failed to get notifications",
    );
  }

  static Future<Map<String, dynamic>> getUnreadCount() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      return await OfflineCacheService.getMap(
        cacheKey: "notifications_unread_count",
        uri: Uri.parse('${_endpoint}unread_count/'),
        token: token,
        failureMessage: "Failed to load unread count",
      );
    } catch (_) {
      return {"unread_count": 0};
    }
  }

  static Future<Map<String, dynamic>> markRead(int notificationId) async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse("$_endpoint$notificationId/mark_read/"),
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
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      }
      throw Exception("Failed to mark notification as read");
    } catch (e) {
      throw Exception("Failed to mark notification as read: $e");
    }
  }

  static Future<Map<String, dynamic>> markAllRead() async {
    final token = await _getToken();
    if (token == null) throw Exception("No authentication token");

    try {
      final response = await http
          .post(
            Uri.parse('${_endpoint}mark_all_read/'),
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
        await OfflineCacheService.invalidateAllForToken(token);
        return data;
      }
      throw Exception("Failed to mark all notifications as read");
    } catch (e) {
      throw Exception("Failed to mark all notifications as read: $e");
    }
  }
}
