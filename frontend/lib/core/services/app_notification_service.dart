import "dart:convert";

import "package:firebase_core/firebase_core.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:workmanager/workmanager.dart";

import "../constants/api_constants.dart";
import "../../firebase_options.dart";

const String notificationSyncTaskName = "library-notification-sync";
const String registerPushDeviceEndpoint = "/push-devices/";
const String unregisterPushDeviceEndpoint = "/push-devices/unregister/";

@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppNotificationService.ensureInitialized(registerBackgroundTask: false);
  await AppNotificationService.syncAndDisplayNotifications();
}

@pragma("vm:entry-point")
void notificationBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await AppNotificationService.ensureInitialized(registerBackgroundTask: false);
    await AppNotificationService.syncAndDisplayNotifications();
    return Future.value(true);
  });
}

class AppNotificationService {
  static const String _channelId = "library_updates";
  static const String _channelName = "Library updates";
  static const String _channelDescription =
      "Book due dates, waiting list updates, fines, and announcements";

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static bool _isInitialized = false;
  static bool _isFirebaseInitialized = false;
  static bool _isFirebaseListenersRegistered = false;
  static bool _workmanagerRegistered = false;

  static bool get _supportsNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> ensureInitialized({
    bool registerBackgroundTask = true,
  }) async {
    if (!_supportsNotifications) {
      return;
    }

    if (!_isInitialized) {
      const androidSettings =
          AndroidInitializationSettings("@mipmap/ic_launcher");
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initializationSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(initializationSettings);

      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(androidChannel);

      _isInitialized = true;
    }

    await _hydrateSessionCache();
    await _initializePushMessaging();
    await requestPermissions();
    await _registerCurrentPushToken();
    await _primeDeliveredNotificationTracker();

    if (registerBackgroundTask &&
        !_workmanagerRegistered &&
        _supportsBackgroundTaskRegistration) {
      await Workmanager().initialize(
        notificationBackgroundDispatcher,
      );
      await Workmanager().registerPeriodicTask(
        notificationSyncTaskName,
        notificationSyncTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      _workmanagerRegistered = true;
    }
  }

  static bool get _supportsBackgroundTaskRegistration =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> requestPermissions() async {
    if (!_supportsNotifications) {
      return;
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (_supportsNotifications && _isFirebaseInitialized) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static Future<void> _hydrateSessionCache() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <String, String?>{
      "token": await _secureStorage.read(key: "token"),
      "role": await _secureStorage.read(key: "role"),
      "username": await _secureStorage.read(key: "username"),
      "user_id": await _secureStorage.read(key: "user_id"),
    };

    for (final entry in entries.entries) {
      final value = entry.value;
      if (value == null || value.isEmpty) {
        continue;
      }
      if (prefs.getString(entry.key) == value) {
        continue;
      }
      await prefs.setString(entry.key, value);
    }
  }

  static Future<void> syncAndDisplayNotifications() async {
    if (!_supportsNotifications) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShownKey = _lastShownNotificationIdKey(prefs);
    final notifications = await _fetchNotifications();
    if (notifications.isEmpty) {
      if (!prefs.containsKey(lastShownKey)) {
        await prefs.setInt(lastShownKey, 0);
      }
      return;
    }

    final latestId = notifications
        .map((item) => _toInt(item["id"]))
        .fold<int>(0, (value, element) => element > value ? element : value);
    final lastShown = prefs.getInt(lastShownKey) ?? 0;

    final freshNotifications = notifications
        .where((item) => _toInt(item["id"]) > lastShown)
        .toList()
      ..sort((a, b) => _toInt(a["id"]).compareTo(_toInt(b["id"])));

    for (final item in freshNotifications) {
      await _showLocalNotification(item);
    }

    await prefs.setInt(lastShownKey, latestId);
  }

  static Future<void> refreshRemoteRegistration() async {
    if (!_supportsNotifications) {
      return;
    }

    await _hydrateSessionCache();
    await _initializePushMessaging();
    await requestPermissions();
    await _registerCurrentPushToken();
  }

  static Future<void> _initializePushMessaging() async {
    if (!_supportsNotifications) {
      return;
    }

    if (!_isFirebaseInitialized) {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: false,
            sound: false,
          );
      _isFirebaseInitialized = true;
    }

    if (!_isFirebaseListenersRegistered) {
      FirebaseMessaging.onMessage.listen((message) async {
        await showRemoteMessage(message);
        await syncAndDisplayNotifications();
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        await syncAndDisplayNotifications();
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await _registerPushToken(token);
      });
      _isFirebaseListenersRegistered = true;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerPushToken(token);
    }
  }

  static Future<void> _primeDeliveredNotificationTracker() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownKey = _lastShownNotificationIdKey(prefs);
    if (prefs.containsKey(lastShownKey)) {
      return;
    }

    final notifications = await _fetchNotifications();
    final latestId = notifications
        .map((item) => _toInt(item["id"]))
        .fold<int>(0, (value, element) => element > value ? element : value);
    await prefs.setInt(lastShownKey, latestId);
  }

  static Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null || token.isEmpty) {
      return const [];
    }

    try {
      final response = await http
          .get(
            Uri.parse(ApiConstants.apiUrl("/notifications/")),
            headers: {
              "Authorization": "Token $token",
              "Content-Type": "application/json",
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data["title"] ?? "Library update";
    final body = notification?.body ?? message.data["body"] ?? "";
    final notificationId = _toInt(
      message.data["notification_id"] ?? DateTime.now().millisecondsSinceEpoch,
    );

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      notificationId,
      "$title",
      "$body",
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _showLocalNotification(Map<String, dynamic> item) async {
    final title = "${item["title"] ?? "Library update"}".trim();
    final body = "${item["message"] ?? ""}".trim();
    final notificationId = _toInt(item["id"]);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode({
        "notification_id": notificationId,
        "type": item["notification_type"],
      }),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse("$value") ?? 0;
  }

  static String _lastShownNotificationIdKey(SharedPreferences prefs) {
    final userId = prefs.getString("user_id");
    if (userId == null || userId.isEmpty) {
      return "last_shown_notification_id";
    }
    return "last_shown_notification_id_$userId";
  }

  static Future<void> _registerPushToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token");
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => "android",
      TargetPlatform.iOS => "ios",
      _ => "",
    };
    if (platform.isEmpty) {
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.apiUrl(registerPushDeviceEndpoint)),
            headers: {
              "Authorization": "Token $authToken",
              "Content-Type": "application/json",
            },
            body: jsonEncode({
              "token": token,
              "platform": platform,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          "Push device registration failed: ${response.statusCode} "
          "${_summarizeHttpBody(response.body)}",
        );
      }
    } catch (_) {}
  }

  static Future<void> _registerCurrentPushToken() async {
    if (!_supportsNotifications || !_isFirebaseInitialized) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        return;
      }
      await _registerPushToken(token);
    } catch (exc) {
      debugPrint("Failed to get FCM token: $exc");
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    if (!_supportsNotifications || !_isFirebaseInitialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString("token");
    if (authToken == null || authToken.isEmpty) {
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await http
          .post(
            Uri.parse(ApiConstants.apiUrl(unregisterPushDeviceEndpoint)),
            headers: {
              "Authorization": "Token $authToken",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"token": token}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  static String _summarizeHttpBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return "empty response body";
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded["error"] != null) {
        return "${decoded["error"]}";
      }
      if (decoded is Map && decoded["detail"] != null) {
        return "${decoded["detail"]}";
      }
      return "non-empty JSON response";
    } catch (_) {
      final compact = trimmed.replaceAll(RegExp(r"\s+"), " ");
      if (compact.contains("<html")) {
        return "HTML error response returned by backend";
      }
      return compact.length > 160 ? "${compact.substring(0, 160)}..." : compact;
    }
  }
}
