import 'dart:convert';

import 'package:http/http.dart' as http;

import '../global/environment.dart';
import 'auth_service.dart';

class SubscriptionService {
  final AuthService _authService = AuthService();
  final Duration _timeout = const Duration(seconds: 15);

  Future<Map<String, String>> _headers() async {
    final token = await _authService.obtenerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> estado() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/subscriptions/me'),
            headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return estado();
    }
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<List<Map<String, dynamic>>> planes() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/subscriptions/plans'),
            headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return planes();
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

  Future<Map<String, dynamic>?> previewPromo({
    required String planId,
    required String code,
  }) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/subscriptions/promo/preview'),
          headers: await _headers(),
          body: jsonEncode({'plan_id': planId, 'code': code.trim()}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return previewPromo(planId: planId, code: code);
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _leerError(response);
    }
    final data = jsonDecode(response.body);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>?> crearIntentoPago({
    required String planId,
    required String method,
    String? promotionCode,
  }) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/subscriptions/payment-intents'),
          headers: await _headers(),
          body: jsonEncode({
            'plan_id': planId,
            'method': method,
            if (promotionCode != null && promotionCode.trim().isNotEmpty)
              'promotion_code': promotionCode.trim(),
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return crearIntentoPago(
        planId: planId,
        method: method,
        promotionCode: promotionCode,
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _leerError(response);
    }
    final data = jsonDecode(response.body);
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>?> historial() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/subscriptions/history'),
            headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return historial();
    }
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body);
    return data is Map ? Map<String, dynamic>.from(data) : null;
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
