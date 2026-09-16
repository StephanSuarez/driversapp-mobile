import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../global/environment.dart';
import 'auth_service.dart';

class NotificationCenterService {
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  final AuthService _authService = AuthService();
  final Duration _timeout = const Duration(seconds: 15);

  Future<Map<String, String>> _headers() async {
    final token = await _authService.obtenerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listar() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/notifications'),
            headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return listar();
    }
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  Future<int> contarNoLeidas() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/notifications/unread-count'),
            headers: await _headers())
        .timeout(_timeout);
    if (response.statusCode != 200) return 0;
    final data = jsonDecode(response.body);
    if (data is Map && data['count'] is num) {
      return (data['count'] as num).toInt();
    }
    if (data is Map && data['unread_count'] is num) {
      return (data['unread_count'] as num).toInt();
    }
    return 0;
  }

  Future<String?> aceptar(String notificationId) =>
      _resolver(notificationId, true);

  Future<String?> rechazar(String notificationId) =>
      _resolver(notificationId, false);

  Future<String?> marcarLeida(String notificationId) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/notifications/$notificationId/read'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return marcarLeida(notificationId);
    }
    if (response.statusCode == 200 || response.statusCode == 204) return null;
    return _leerError(response);
  }

  Future<String?> _resolver(String notificationId, bool aceptar) async {
    final action = aceptar ? 'accept' : 'reject';
    final response = await http
        .post(
          Uri.parse(
              '${Environment.apiUrl}/notifications/$notificationId/$action'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return _resolver(notificationId, aceptar);
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      changes.value++;
      return null;
    }
    return _leerError(response);
  }

  String _leerError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        return data['message']?.toString() ??
            data['trigger']?.toString() ??
            'Error ${response.statusCode}';
      }
    } catch (_) {}
    return 'Error ${response.statusCode}';
  }
}
