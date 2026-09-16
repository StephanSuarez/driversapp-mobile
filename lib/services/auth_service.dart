// lib/services/auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../global/environment.dart';
import 'datos_temporales.dart';
import 'push_notification_service.dart';

class AuthService {
  final String _baseUrl = Environment.apiUrl;
  final Duration _timeout = const Duration(seconds: 15);
  static const String _perfilCacheKey = 'driver_profile_cache';
  static const String _telefonoSesionKey = 'driver_phone_number';

  Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? prefs.getString('auth_token');
  }

  Future<void> _guardarSesion(
    String accessToken,
    String? refreshToken, {
    String? phoneNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString('access_token', accessToken),
      prefs.setString('auth_token', accessToken),
      if (refreshToken != null) prefs.setString('refresh_token', refreshToken),
      if (phoneNumber != null && phoneNumber.isNotEmpty)
        prefs.setString(_telefonoSesionKey, phoneNumber),
    ]);

    Environment.driverToken = accessToken;
    await PushNotificationService().syncTokenWithBackend();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await obtenerToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<bool> asegurarSesionConductor({
    required String celular,
    required String password,
  }) async {
    final token = await obtenerToken();
    if (token != null && token.isNotEmpty) return true;

    if (celular.trim().isEmpty || password.isEmpty) return false;
    return login(celular, password);
  }

  String _formatearCelular(String numero) {
    final limpio = numero.replaceAll(RegExp(r'\s+'), '');
    return limpio.startsWith('+') ? limpio : "+57$limpio";
  }

  Future<bool> login(String celular, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/login/driver'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "phone_number": _formatearCelular(celular),
              "password": password
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('access_token')) {
          await _guardarSesion(
            data['access_token'],
            data['refresh_token'],
            phoneNumber: _formatearCelular(celular),
          );
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> registrarConductor(
      {required String nombre,
      required String apellidos,
      required String celular,
      required String password,
      required String documento,
      required String tipoDocumento,
      required bool esPropietario,
      String? celularPropietario}) async {
    final payload = {
      "full_name": "$nombre $apellidos",
      "phone_number": _formatearCelular(celular),
      "id_document": documento,
      "password": password,
      "document_type": tipoDocumento,
      "is_owner_taxi": esPropietario,
      "phone_number_owner_taxi":
          esPropietario ? null : _formatearCelular(celularPropietario ?? "")
    };

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/driver/register'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      if (response.statusCode == 200 || response.statusCode == 201) return null;

      final data = jsonDecode(response.body);
      return data['message'] ??
          data['trigger'] ??
          "Error ${response.statusCode}";
    } catch (_) {
      return "Error de conexión con el servidor.";
    }
  }

  Future<bool> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final rt = prefs.getString('refresh_token');
    if (rt == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/user/refresh_token'),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"refresh_token": rt}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _guardarSesion(data['access_token'], data['refresh_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<String?> subirArchivo(File imagen) async {
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_baseUrl/storage/upload'));
      final token = await obtenerToken();

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(await http.MultipartFile.fromPath('file', imagen.path));

      final response = await http.Response.fromStream(
          await request.send().timeout(const Duration(seconds: 30)));

      if (response.statusCode == 401 && await refreshToken()) {
        return subirArchivo(imagen);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body)['url'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> actualizarDatosConductor(Map<String, dynamic> payload) async {
    return actualizarDatosConductorConMensaje(payload)
        .then((error) => error == null);
  }

  Future<String?> actualizarDatosConductorConMensaje(
    Map<String, dynamic> payload, {
    String? celular,
    String? password,
    bool reintentarLogin = true,
  }) async {
    try {
      debugPrint("[driver-update] payload=${jsonEncode(payload)}");
      final response = await http
          .put(
            Uri.parse('$_baseUrl/user/driver'),
            headers: await _getHeaders(),
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
      debugPrint(
          "[driver-update] status=${response.statusCode} body=${response.body}");

      if (response.statusCode == 401 && await refreshToken()) {
        return actualizarDatosConductorConMensaje(
          payload,
          celular: celular,
          password: password,
          reintentarLogin: reintentarLogin,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      if (response.statusCode == 400 &&
          response.body.contains('Required RequestAttribute [user-id]') &&
          reintentarLogin &&
          celular != null &&
          password != null &&
          celular.trim().isNotEmpty &&
          password.isNotEmpty &&
          await login(celular, password)) {
        return actualizarDatosConductorConMensaje(
          payload,
          celular: celular,
          password: password,
          reintentarLogin: false,
        );
      }

      try {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final trigger = data['trigger']?.toString();
          final message = data['message']?.toString();
          final mappedMessage = _mensajeErrorUpdateDriver(
            trigger: trigger,
            message: message,
            fallbackBody: response.body,
          );
          if (mappedMessage != null) return mappedMessage;

          return message ?? trigger ?? "Error ${response.statusCode}";
        }
      } catch (_) {}

      final mappedMessage = _mensajeErrorUpdateDriver(
        trigger: null,
        message: null,
        fallbackBody: response.body,
      );
      if (mappedMessage != null) return mappedMessage;

      return response.body.isNotEmpty
          ? "Error ${response.statusCode}: ${response.body}"
          : "Error ${response.statusCode}";
    } catch (_) {
      return "Error de conexión con el servidor.";
    }
  }

  String? _mensajeErrorUpdateDriver({
    required String? trigger,
    required String? message,
    required String fallbackBody,
  }) {
    final body = fallbackBody.toLowerCase();
    final rawMessage = message?.toLowerCase() ?? '';

    if (trigger == 'VEHICLE_PLATE_ALREADY_EXISTS' ||
        body.contains('vehicles_vehicle_plate_unique_active') ||
        rawMessage.contains('vehicles_vehicle_plate_unique_active')) {
      return "La placa ya está registrada. Verifica la placa o solicita soporte para liberar el vehículo anterior.";
    }

    if (trigger == 'DRIVER_NOT_FOUND') {
      return "No encontramos el conductor de esta sesión. Cierra sesión e inicia el registro nuevamente.";
    }

    if (trigger == 'USER_NOT_FOUND') {
      return "No encontramos el usuario de esta sesión. Cierra sesión e inicia el registro nuevamente.";
    }

    if (trigger == 'UNAUTHORIZED') {
      return "Tu sesión expiró. Inicia sesión nuevamente para finalizar el registro.";
    }

    return null;
  }

  Future<String?> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/user/driver/change-password'),
            headers: await _getHeaders(),
            body: jsonEncode({
              'current_password': contrasenaActual,
              'new_password': contrasenaNueva,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 && await refreshToken()) {
        return cambiarContrasena(
          contrasenaActual: contrasenaActual,
          contrasenaNueva: contrasenaNueva,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      final data = jsonDecode(response.body);
      return data['message']?.toString() ?? "Error ${response.statusCode}";
    } catch (_) {
      return "Error de conexión con el servidor.";
    }
  }

  Future<Map<String, dynamic>?> obtenerPerfil() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/user/profile'),
            headers: await _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 && await refreshToken()) {
        return obtenerPerfil();
      }

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final driverInfo = data['driver_info'];
      if (driverInfo is Map<String, dynamic>) {
        driverInfo['profile_photo'] =
            _normalizarUrlImagen(driverInfo['profile_photo']);
      }

      await _completarEstadisticasPerfil(data);
      await _guardarPerfilCache(data);
      await _guardarTelefonoDesdePerfil(data);
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> obtenerPerfilCacheado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_perfilCacheKey);
      if (raw == null || raw.isEmpty) return null;

      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {}
    return null;
  }

  Future<void> _guardarPerfilCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_perfilCacheKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<String?> obtenerTelefonoSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final telefonoGuardado = prefs.getString(_telefonoSesionKey);
    if (telefonoGuardado != null && telefonoGuardado.trim().isNotEmpty) {
      return telefonoGuardado;
    }

    final perfilCacheado = await obtenerPerfilCacheado();
    final telefonoCacheado = _extraerTelefonoDesdePerfil(perfilCacheado);
    if (telefonoCacheado != null) {
      await prefs.setString(_telefonoSesionKey, telefonoCacheado);
      return telefonoCacheado;
    }

    final perfil = await obtenerPerfil();
    return _extraerTelefonoDesdePerfil(perfil);
  }

  Future<void> _guardarTelefonoDesdePerfil(Map<String, dynamic> data) async {
    final telefono = _extraerTelefonoDesdePerfil(data);
    if (telefono == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_telefonoSesionKey, telefono);
  }

  String? _extraerTelefonoDesdePerfil(Map<String, dynamic>? data) {
    if (data == null) return null;

    final driverInfo = data['driver_info'];
    final candidates = <dynamic>[
      data['phone_number'],
      data['phoneNumber'],
      data['phone'],
      if (driverInfo is Map) driverInfo['phone_number'],
      if (driverInfo is Map) driverInfo['phoneNumber'],
      if (driverInfo is Map) driverInfo['phone'],
    ];

    for (final value in candidates) {
      final phone = value?.toString().trim();
      if (phone != null && phone.isNotEmpty && phone.toLowerCase() != 'null') {
        return phone;
      }
    }

    return null;
  }

  Future<void> _completarEstadisticasPerfil(Map<String, dynamic> data) async {
    final userId = data['user_id']?.toString();
    final driverInfo = data['driver_info'];
    if (userId == null ||
        userId.isEmpty ||
        driverInfo is! Map<String, dynamic>) {
      return;
    }

    await _mezclarStatsConductor(driverInfo);
    await _mezclarRatingConductor(userId, driverInfo);
  }

  Future<void> _mezclarStatsConductor(Map<String, dynamic> driverInfo) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/drivers/me/stats'),
            headers: await _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;

      driverInfo['rating_average'] ??= data['rating_average'];
      driverInfo['rating_total'] ??= data['rating_total'];
      driverInfo['completed_rides'] ??= data['completed_rides'];
    } catch (_) {}
  }

  Future<void> _mezclarRatingConductor(
    String userId,
    Map<String, dynamic> driverInfo,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/drivers/$userId/ratings/average'),
            headers: await _getHeaders(),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return;

      driverInfo['rating_average'] ??= data['average'];
      driverInfo['rating_total'] ??= data['total'];

      // Fallback temporal para producción mientras /drivers/me/stats no esté
      // desplegado. Evita mostrar 0 cuando sí hay calificaciones registradas.
      driverInfo['completed_rides'] ??= data['total'];
    } catch (_) {}
  }

  String _normalizarUrlImagen(dynamic value) {
    if (value == null) return '';

    final url = value.toString().trim();
    if (url.isEmpty || url.toLowerCase() == 'null') return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    final base = Environment.apiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  bool _isValid(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s.isNotEmpty && s != 'null' && s != '[]';
    }
    if (value is List) {
      return value.isNotEmpty;
    }
    return true;
  }

  bool _isFalseValue(dynamic value) {
    if (value is bool) return value == false;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'false' || normalized == '0' || normalized == 'no';
    }
    if (value is num) return value == 0;
    return false;
  }

  bool _isTrueValue(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'verified' ||
          normalized == 'verificada';
    }
    if (value is num) return value != 0;
    return false;
  }

  String _rutaSegunPerfil(Map<String, dynamic> data) {
    final info = data['driver_info'] ?? data;
    if (info is! Map) return 'foto_perfil';

    if (!_isValid(info['profile_photo'])) return 'foto_perfil';

    final profileStatus = info['status']?.toString().trim().toUpperCase();
    final documentosCompletos = profileStatus == 'COMPLETE' ||
        (_isValid(info['id_card_images']) && _isValid(info['driver_license']));

    if (!documentosCompletos) {
      return 'documentos_conductor';
    }

    final phoneVerifiedValue =
        info['is_phone_number_verified'] ?? info['phone_verified'];
    if (_isFalseValue(phoneVerifiedValue)) return 'otp';

    final isVerified = _isTrueValue(info['is_account_verified']) ||
        _isTrueValue(info['account_verified']) ||
        _isTrueValue(data['status']) ||
        _isTrueValue(info['verification_status']);

    return isVerified ? 'home' : 'espera';
  }

  Future<String?> _rutaDesdePerfilCacheado() async {
    final data = await obtenerPerfilCacheado();
    if (data == null) return null;
    return _rutaSegunPerfil(data);
  }

  Future<String> _rutaFallbackSesionActiva(String pasoPendiente) async {
    if (_esPasoOnboarding(pasoPendiente) && pasoPendiente != 'otp') {
      return _normalizarPasoOnboarding(pasoPendiente);
    }

    final rutaCacheada = await _rutaDesdePerfilCacheado();
    if (rutaCacheada != null && rutaCacheada != 'home') {
      return rutaCacheada;
    }

    return 'foto_perfil';
  }

  Future<String> determinarPantallaInicial() async {
    String? token;
    try {
      await DatosTemporales.cargarFase1();
      final pasoPendiente = await DatosTemporales.obtenerPasoActual();
      token = await obtenerToken();

      final sesionActiva = token != null && token.isNotEmpty;
      if (sesionActiva) {
        final perfil = await obtenerPerfil();
        if (perfil != null) {
          final ruta = _rutaSegunPerfil(perfil);
          await DatosTemporales.guardarPasoActual(ruta);
          return ruta;
        }

        return _rutaFallbackSesionActiva(pasoPendiente);
      }

      if (_esPasoOnboarding(pasoPendiente)) {
        if (DatosTemporales.celular.isNotEmpty &&
            DatosTemporales.password.isNotEmpty &&
            await login(DatosTemporales.celular, DatosTemporales.password)) {
          final perfil = await obtenerPerfil();
          if (perfil != null) {
            final ruta = _rutaSegunPerfil(perfil);
            await DatosTemporales.guardarPasoActual(ruta);
            return ruta;
          }
        }

        return _normalizarPasoOnboarding(pasoPendiente);
      }
    } catch (e) {
      debugPrint("Auth Routing Error: $e");
    }

    if (token != null && token.isNotEmpty) {
      return _rutaFallbackSesionActiva(
          await DatosTemporales.obtenerPasoActual());
    }

    return 'login';
  }

  bool _esPasoOnboarding(String paso) {
    return {
      'otp',
      'foto_perfil',
      'fotos_perfil',
      'documentos_conductor',
      'foto_vehiculo',
      'licencia',
      'propiedad',
      'tarjeton',
    }.contains(paso);
  }

  String _normalizarPasoOnboarding(String paso) {
    if (paso == 'fotos_perfil') return 'foto_perfil';
    return paso;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Environment.driverToken = '';
  }
}
