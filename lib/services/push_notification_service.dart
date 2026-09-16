import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../global/environment.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();
}

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;

  // Lee google-services.json / GoogleService-Info.plist (no versionados).
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ValueNotifier<Map<String, dynamic>?> notificationTap =
      ValueNotifier<Map<String, dynamic>?>(null);

  bool _initialized = false;
  bool _syncingToken = false;
  Timer? _tokenRetryTimer;
  static const String _pendingChatRideIdKey =
      'pending_chat_notification_ride_id';
  static const String _pendingChatCreatedAtKey =
      'pending_chat_notification_created_at';
  static const int _navigationReturnNotificationId = 91001;

  bool get _remotePushEnabled => true;

  Future<void> initialize() async {
    if (_initialized) {
      await syncTokenWithBackend();
      return;
    }

    try {
      await ensureFirebaseInitialized();
      await _configureLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      await _requestPermission();

      _messaging.onTokenRefresh.listen(_registerToken);
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _emitNotificationTap(message.data);
      });

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _emitNotificationTap(initialMessage.data);
      }

      _initialized = true;
      await syncTokenWithBackend();
    } catch (e) {
      debugPrint('[push] init error: $e');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[push] permission=${settings.authorizationStatus.name}');

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> _configureLocalNotifications() async {
    const androidChannel = AndroidNotificationChannel(
      'driversapp_driver_alerts',
      'Alertas DriversApp',
      description: 'Servicios y mensajes de viaje',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _handleNotificationPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map) {
        _emitNotificationTap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('[push] payload de notificación inválido: $e');
    }
  }

  void _emitNotificationTap(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    debugPrint('[push] notification tap data=$data');
    notificationTap.value = Map<String, dynamic>.from(data);
  }

  Future<String?> consumePendingChatNotificationRideId({
    Duration maxAge = const Duration(minutes: 15),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rideId = prefs.getString(_pendingChatRideIdKey);
    final createdAtMs = prefs.getInt(_pendingChatCreatedAtKey);

    await prefs.remove(_pendingChatRideIdKey);
    await prefs.remove(_pendingChatCreatedAtKey);

    if (rideId == null || rideId.isEmpty || createdAtMs == null) return null;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
    if (DateTime.now().difference(createdAt) > maxAge) return null;

    debugPrint('[push] pending chat notification ride_id=$rideId');
    return rideId;
  }

  Future<void> _storePendingChatNotification(String? payload) async {
    if (payload == null || payload.isEmpty) return;

    try {
      final data = jsonDecode(payload);
      if (data is! Map) return;

      final type = data['type']?.toString();
      final rideId = data['ride_id']?.toString() ??
          data['rideId']?.toString() ??
          data['id_ride']?.toString();
      if (type != 'ride_chat' || rideId == null || rideId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingChatRideIdKey, rideId);
      await prefs.setInt(
        _pendingChatCreatedAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[push] no se pudo guardar chat pendiente: $e');
    }
  }

  Future<String?> _getPushToken() async {
    if (Platform.isIOS) {
      String? apnsToken;
      for (var i = 0; i < 20; i++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          debugPrint('[push] apns token listo');
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (apnsToken == null || apnsToken.isEmpty) {
        debugPrint('[push] APNS token no disponible todavía');
        return null;
      }
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[push] FCM token vacío');
      return null;
    }

    debugPrint('[push] FCM token obtenido len=${token.length}');
    return token;
  }

  Future<void> syncTokenWithBackend() async {
    if (!_remotePushEnabled) return;
    if (_syncingToken) return;
    _syncingToken = true;

    try {
      await ensureFirebaseInitialized();
      final token = await _getPushToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      } else {
        _programarReintentoToken();
      }
    } catch (e) {
      debugPrint('[push] sync token error: $e');
    } finally {
      _syncingToken = false;
    }
  }

  void _programarReintentoToken() {
    _tokenRetryTimer?.cancel();
    _tokenRetryTimer = Timer(const Duration(seconds: 5), () {
      syncTokenWithBackend();
    });
  }

  Future<void> _registerToken(String token) async {
    if (Environment.driverToken.isEmpty) {
      debugPrint('[push] token no registrado: no hay sesion');
      return;
    }

    try {
      final response = await http
          .put(
            Uri.parse('${Environment.apiUrl}/drivers/me/push-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Environment.driverToken}',
            },
            body: jsonEncode({
              'token': token,
              'platform': Platform.isIOS ? 'ios' : 'android',
            }),
          )
          .timeout(const Duration(seconds: 8));

      debugPrint(
        '[push] token registrado status=${response.statusCode} body=${response.body}',
      );
    } catch (e) {
      debugPrint('[push] error registrando token: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'DriversApp';
    final body = notification?.body ?? message.data['body'] ?? '';

    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(message.data),
      id: message.hashCode,
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    bool ongoing = false,
  }) async {
    await _storePendingChatNotification(payload);

    final androidDetails = AndroidNotificationDetails(
      'driversapp_driver_alerts',
      'Alertas DriversApp',
      channelDescription: 'Servicios y mensajes de viaje',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: ongoing,
      autoCancel: !ongoing,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _localNotifications.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails:
          NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  Future<void> showNavigationReturnNotification({
    required String rideId,
    required bool isDestinationLeg,
  }) async {
    final body = isDestinationLeg
        ? 'Toca aqui al llegar al destino para finalizar el viaje.'
        : 'Toca aqui al llegar al origen para ingresar el codigo.';

    await showLocalNotification(
      id: _navigationReturnNotificationId,
      title: 'Volver a DriversApp',
      body: body,
      payload: jsonEncode({
        'type': 'return_to_ride',
        'ride_id': rideId,
      }),
      ongoing: true,
    );
  }

  Future<void> cancelNavigationReturnNotification() async {
    await _localNotifications.cancel(id: _navigationReturnNotificationId);
  }
}
