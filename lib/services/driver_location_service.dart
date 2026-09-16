// lib/services/driver_location_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../global/environment.dart';
import 'push_notification_service.dart';

class DriverChatMessageEvent {
  final String rideId;
  final String text;
  final int unreadCount;

  const DriverChatMessageEvent({
    required this.rideId,
    required this.text,
    required this.unreadCount,
  });
}

class DriverLocationService {
  static final DriverLocationService _instance =
      DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier(false);
  bool get isTracking => isTrackingNotifier.value;

  Timer? _rastreoTimer;
  Timer? _rideTimer;
  Timer? _activeRideTimer;
  Timer? _chatTimer;
  WebSocketChannel? _chatChannel;
  StreamSubscription? _chatSubscription;

  final ValueNotifier<Map<String, dynamic>?> viajeEntrante =
      ValueNotifier(null);
  final ValueNotifier<bool> viajeCanceladoExternamente = ValueNotifier(false);
  final ValueNotifier<int> chatUnreadCount = ValueNotifier(0);
  final ValueNotifier<DriverChatMessageEvent?> chatMessagePreview =
      ValueNotifier(null);

  String? _ultimoIdentificador;
  String? _activeVehicleId;
  String? chatActivoRideId;
  String? _chatRideId;
  final Set<String> _mensajesChatVistos = {};
  bool _chatInicializado = false;

  void notificarCancelacionExterna() {
    viajeCanceladoExternamente.value = true;
    viajeEntrante.value = null;
    detenerMonitoreoViajeActivo();
  }

  void iniciarMonitoreoViajeActivo(String rideId) {
    _activeRideTimer?.cancel();
    _iniciarMonitorChat(rideId);
    _activeRideTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/ride/$rideId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Environment.driverToken}',
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'CANCELLED' || data['status'] == 'REJECTED') {
            notificarCancelacionExterna();
          }
        }
      } catch (e) {}
    });
  }

  void detenerMonitoreoViajeActivo() {
    _activeRideTimer?.cancel();
    _chatTimer?.cancel();
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _chatChannel?.sink.close();
    _chatChannel = null;
    _chatRideId = null;
    _mensajesChatVistos.clear();
    _chatInicializado = false;
    chatUnreadCount.value = 0;
  }

  void _iniciarMonitorChat(String rideId) {
    _chatTimer?.cancel();
    _chatSubscription?.cancel();
    _chatSubscription = null;
    _chatChannel?.sink.close();
    _chatChannel = null;
    _chatRideId = rideId;
    _mensajesChatVistos.clear();
    _chatInicializado = false;
    chatUnreadCount.value = 0;
    _conectarChatWebSocket(rideId);
    _consultarMensajesChat(rideId);
    _chatTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _consultarMensajesChat(rideId),
    );
  }

  void clearUnreadChat(String rideId) {
    if (_chatRideId == rideId) {
      chatUnreadCount.value = 0;
    }
  }

  void _conectarChatWebSocket(String rideId) {
    try {
      final uri = Uri.parse('${Environment.wsApiUrl}/ws/rides/$rideId/chat');
      _chatChannel = WebSocketChannel.connect(uri);
      _chatSubscription = _chatChannel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event.toString());
            if (data is Map) {
              _procesarMensajeChat(rideId, data, desdeHistorialInicial: false);
            }
          } catch (e) {
            debugPrint('[chat-monitor] websocket payload inválido: $e');
          }
        },
        onError: (error) {
          debugPrint('[chat-monitor] websocket error: $error');
        },
        onDone: () {
          debugPrint('[chat-monitor] websocket cerrado');
        },
      );
    } catch (e) {
      debugPrint('[chat-monitor] no se pudo abrir websocket: $e');
    }
  }

  Future<void> _consultarMensajesChat(String rideId) async {
    if (Environment.driverToken.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/ride/$rideId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! List) return;

      for (final item in data) {
        if (item is! Map) continue;
        await _procesarMensajeChat(
          rideId,
          item,
          desdeHistorialInicial: !_chatInicializado,
        );
      }

      _chatInicializado = true;
    } catch (e) {
      debugPrint('[chat-monitor] error: $e');
    }
  }

  Future<void> _procesarMensajeChat(
    String rideId,
    Map item, {
    required bool desdeHistorialInicial,
  }) async {
    final senderType =
        (item['senderType'] ?? item['sender_type'] ?? item['sender'])
            ?.toString()
            .toUpperCase();
    final text =
        (item['text'] ?? item['message'] ?? item['body'])?.toString().trim() ??
            '';
    final sentAt =
        (item['sentAt'] ?? item['sent_at'] ?? item['created_at'])?.toString() ??
            '';
    final id = (item['id'] ?? item['message_id'])?.toString() ?? '';
    final key = id.isNotEmpty ? id : '$senderType|$sentAt|$text';

    if (!_mensajesChatVistos.add(key)) return;
    if (desdeHistorialInicial || !_chatInicializado) return;
    if (senderType != 'CLIENT' || text.isEmpty) return;
    if (chatActivoRideId == rideId) return;

    final nextCount = chatUnreadCount.value + 1;
    chatUnreadCount.value = nextCount;
    chatMessagePreview.value = DriverChatMessageEvent(
      rideId: rideId,
      text: text,
      unreadCount: nextCount,
    );

    final appState = WidgetsBinding.instance.lifecycleState;
    final appEnPrimerPlano = appState == AppLifecycleState.resumed ||
        appState == AppLifecycleState.inactive;

    if (!appEnPrimerPlano) {
      await PushNotificationService().showLocalNotification(
        title: 'Nuevo mensaje del pasajero',
        body: text,
        payload: jsonEncode({
          'type': 'ride_chat',
          'ride_id': rideId,
        }),
      );
    }
  }

  Future<bool> iniciarJornada({required String vehicleId}) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      bool success = await updateStatus(
          lat: pos.latitude,
          lng: pos.longitude,
          isOnline: true,
          vehicleId: vehicleId);
      if (success) {
        _activeVehicleId = vehicleId;
        isTrackingNotifier.value = true;
        _ultimoIdentificador = null;
        _iniciarReloj();
        _iniciarBuscadorDeViajes();
        return true;
      }
      return false;
    } catch (e) {
      if (e.toString().contains('membresía') ||
          e.toString().contains('membresia') ||
          e.toString().contains('vehículo ya está en uso')) {
        rethrow;
      }
      return false;
    }
  }

  Future<bool> finalizarJornada() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await updateStatus(
          lat: pos.latitude, lng: pos.longitude, isOnline: false);
      _activeVehicleId = null;
      isTrackingNotifier.value = false;
      _rastreoTimer?.cancel();
      _rideTimer?.cancel();
      detenerMonitoreoViajeActivo();
      return true;
    } catch (e) {
      isTrackingNotifier.value = false;
      _activeVehicleId = null;
      _rastreoTimer?.cancel();
      _rideTimer?.cancel();
      detenerMonitoreoViajeActivo();
      return false;
    }
  }

  void detenerJornadaLocal() {
    _activeVehicleId = null;
    _ultimoIdentificador = null;
    isTrackingNotifier.value = false;
    _rastreoTimer?.cancel();
    _rideTimer?.cancel();
    detenerMonitoreoViajeActivo();
  }

  // Consulta al backend el estado real del conductor (Redis) y arranca/detiene
  // los timers locales para reflejarlo. Pensado para llamarse al iniciar la app.
  Future<void> sincronizarEstado() async {
    if (Environment.driverToken.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/drivers/location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      ).timeout(const Duration(seconds: 8));

      bool activo = false;
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isNotEmpty && body != 'null') {
          try {
            final data = jsonDecode(body);
            if (data is Map) {
              final status = data['status']?.toString().toUpperCase();
              _activeVehicleId = data['vehicle_id']?.toString();
              activo = status == 'AVAILABLE' || status == 'BUSY';
            }
          } catch (_) {}
        }
      }

      debugPrint(
          '[sincronizarEstado] activo=$activo (status=${response.statusCode})');

      if (activo && !isTracking) {
        isTrackingNotifier.value = true;
        _ultimoIdentificador = null;
        _iniciarReloj();
        _iniciarBuscadorDeViajes();
        unawaited(_sincronizarViajeActivo());
      } else if (!activo && isTracking) {
        isTrackingNotifier.value = false;
        _activeVehicleId = null;
        _rastreoTimer?.cancel();
        _rideTimer?.cancel();
        detenerMonitoreoViajeActivo();
      } else if (!activo) {
        isTrackingNotifier.value = false;
        _activeVehicleId = null;
      } else {
        unawaited(_sincronizarViajeActivo());
      }
    } catch (e) {
      debugPrint('[sincronizarEstado] error: $e');
    }
  }

  Future<void> _sincronizarViajeActivo() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/drivers/me/ride'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is Map && data['id'] != null) {
        iniciarMonitoreoViajeActivo(data['id'].toString());
      }
    } catch (e) {
      debugPrint('[active-ride] error: $e');
    }
  }

  void _iniciarReloj() {
    _rastreoTimer?.cancel();
    final intervalo =
        Duration(seconds: Environment.locationUpdateIntervalSeconds);
    debugPrint(
        '[location] tracking iniciado, intervalo=${intervalo.inSeconds}s');
    _rastreoTimer = Timer.periodic(intervalo, (timer) async {
      if (!isTracking) {
        timer.cancel();
        return;
      }
      try {
        Position pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        final ok = await updateStatus(
            lat: pos.latitude,
            lng: pos.longitude,
            isOnline: true,
            vehicleId: _activeVehicleId);
        debugPrint(
            '[location] push lat=${pos.latitude} lng=${pos.longitude} ok=$ok');
      } catch (e) {
        debugPrint('[location] error obteniendo GPS: $e');
      }
    });
  }

  void _iniciarBuscadorDeViajes() {
    _rideTimer?.cancel();
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!isTracking) {
        timer.cancel();
        return;
      }
      try {
        final response = await http.get(
          Uri.parse('${Environment.apiUrl}/drivers/me/ride-offer'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Environment.driverToken}',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data != null && data.containsKey('id')) {
            String nuevoId = data['id'];
            if (nuevoId != _ultimoIdentificador) {
              _ultimoIdentificador = nuevoId;
              viajeEntrante.value = null;
              viajeEntrante.value = Map.from(data);
              await PushNotificationService().showLocalNotification(
                title: 'Nuevo servicio disponible',
                body: 'Tienes una nueva solicitud de viaje.',
                payload: jsonEncode({
                  'type': 'ride_offer',
                  'ride_id': nuevoId,
                }),
              );
            }
          }
        } else if (response.statusCode == 404 || response.statusCode == 204) {
          _ultimoIdentificador = null;
        }
      } catch (e) {}
    });
  }

  Future<bool> updateStatus(
      {required double lat,
      required double lng,
      required bool isOnline,
      String? vehicleId}) async {
    final url =
        isOnline ? Environment.driverOnlineUrl : Environment.driverOfflineUrl;
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${Environment.driverToken}',
            },
            body: jsonEncode({
              'latitude': lat,
              'longitude': lng,
              if (isOnline && vehicleId != null) 'vehicle_id': vehicleId,
            }),
          )
          .timeout(const Duration(seconds: 8));
      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      if (!ok) {
        debugPrint(
            '[updateStatus] $url status=${response.statusCode} body=${response.body}');
        if (response.statusCode == 409 &&
            response.body.toLowerCase().contains('vehicle is already occupied')) {
          throw 'Este vehículo ya está en uso por otro conductor';
        }
        if (response.statusCode == 402 ||
            response.body.toLowerCase().contains('membership')) {
          throw 'Necesitas una membresía activa para conectarte.';
        }
      }
      return ok;
    } catch (e) {
      debugPrint('[updateStatus] excepción: $e ($url)');
      if (e.toString().contains('Este vehículo ya está en uso') ||
          e.toString().contains('membresía')) {
        rethrow;
      }
      return false;
    }
  }

  Future<bool> aceptarViaje(String rideId) async {
    final url =
        Uri.parse('${Environment.apiUrl}/drivers/me/ride-offer/$rideId/accept');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rechazarViaje(String rideId) async {
    // Endpoint correcto para rechazar una oferta de viaje (no un viaje activo).
    final url =
        Uri.parse('${Environment.apiUrl}/drivers/me/ride-offer/$rideId/reject');
    try {
      debugPrint('[rechazarViaje] POST $url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      );
      debugPrint(
          '[rechazarViaje] status=${response.statusCode} body=${response.body}');
      return response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204 ||
          response.statusCode == 409;
    } catch (e) {
      debugPrint('[rechazarViaje] excepción: $e');
      return false;
    }
  }

  Future<String> verificarCodigoViaje(String rideId, String code) async {
    final url =
        Uri.parse('${Environment.apiUrl}/drivers/me/ride/$rideId/verify-code');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return "OK";
      }

      return "El PIN ingresado no es válido. Intenta de nuevo.";
    } catch (e) {
      return "Error de conexión. Intenta de nuevo.";
    }
  }

  Future<bool> cancelarViaje(String rideId) async {
    final url = Uri.parse(Environment.cancelarViajeUrl(rideId));
    try {
      debugPrint('[cancelarViaje] POST $url');
      final response = await http.post(
        url,
        headers: {
          'X-RIDE-KEY': Environment.rideAuthKey,
          'Authorization': 'Bearer ${Environment.driverToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({}),
      );
      debugPrint(
          '[cancelarViaje] status=${response.statusCode} body=${response.body}');
      final ok = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      if (ok) detenerMonitoreoViajeActivo();
      return ok;
    } catch (e) {
      debugPrint('[cancelarViaje] excepción: $e');
      return false;
    }
  }

  // Devuelve el viaje en curso del conductor o null si no hay ninguno activo.
  Future<Map<String, dynamic>?> obtenerViajeActivo() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/drivers/me/ride/detail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Environment.driverToken}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final body = response.body.trim();
      if (body.isEmpty) return null;

      final data = jsonDecode(body);
      if (data is! Map) return null;

      final status = data['status']?.toString().toUpperCase();
      const activos = {
        'IN_PROGRESS',
        'ACCEPTED',
        'ASSIGNED',
        'AT_PICKUP',
        'STARTED'
      };
      if (status == null || !activos.contains(status)) return null;

      return Map<String, dynamic>.from(data);
    } catch (e) {
      return null;
    }
  }

  Future<String?> finalizarViaje(String rideId) async {
    final url = Uri.parse(Environment.finalizarViajeUrl(rideId));
    try {
      debugPrint('[finalizarViaje] PUT $url');
      final response = await http.put(
        url,
        headers: {
          'X-RIDE-KEY': Environment.rideAuthKey,
          'Authorization': 'Bearer ${Environment.driverToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "status": "COMPLETED",
          "changed_by": "driver",
        }),
      );
      debugPrint(
          '[finalizarViaje] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        detenerMonitoreoViajeActivo();
        final data = jsonDecode(response.body);
        final price =
            data['final_price'] ?? data['finalPrice'] ?? data['price'];
        return price?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('[finalizarViaje] excepción: $e');
      return null;
    }
  }

  Future<String?> calificarCliente(String rideId, int score) async {
    final url = Uri.parse(Environment.calificarClienteUrl(rideId));
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${Environment.driverToken}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({"score": score}),
      );

      debugPrint(
          '[calificarCliente] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return data['message']?.toString() ??
              "No se pudo guardar la calificación.";
        }
      } catch (_) {}

      return "No se pudo guardar la calificación.";
    } catch (e) {
      debugPrint('[calificarCliente] excepción: $e');
      return "Error de conexión al guardar la calificación.";
    }
  }
}
