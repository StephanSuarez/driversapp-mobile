import 'dart:convert';

import 'package:http/http.dart' as http;

import '../global/environment.dart';
import 'auth_service.dart';

class VehicleService {
  final AuthService _authService = AuthService();
  final Duration _timeout = const Duration(seconds: 15);

  String _normalizarPlaca(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  Future<Map<String, String>> _headers() async {
    final token = await _authService.obtenerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listarVehiculos() async {
    final response = await http
        .get(Uri.parse('${Environment.apiUrl}/user/vehicles'),
            headers: await _headers())
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return listarVehiculos();
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

  Future<List<Map<String, dynamic>>> vehiculosDisponiblesParaConectar() async {
    final vehiculos = await listarVehiculos();
    return vehiculos.where((vehicle) {
      final status = vehicle['relationship_status']?.toString().toUpperCase();
      return vehicle['verified'] == true && status == 'ACTIVE';
    }).toList();
  }

  Future<String?> registrarVehiculo({
    required String placa,
    required String numeroOrden,
    required List<String> tarjetaPropiedad,
    required List<String> fotosVehiculo,
  }) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/user/vehicles'),
          headers: await _headers(),
          body: jsonEncode({
            'vehicle_plate': _normalizarPlaca(placa),
            'order_number': numeroOrden,
            'ownership_card': tarjetaPropiedad,
            'vehicle_images': fotosVehiculo,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return registrarVehiculo(
        placa: _normalizarPlaca(placa),
        numeroOrden: numeroOrden,
        tarjetaPropiedad: tarjetaPropiedad,
        fotosVehiculo: fotosVehiculo,
      );
    }
    if (response.statusCode == 200 || response.statusCode == 201) return null;
    return _leerError(response);
  }

  Future<String?> invitarConductor({
    required String vehicleId,
    required String documento,
  }) async {
    final response = await http
        .post(
          Uri.parse(
              '${Environment.apiUrl}/user/vehicles/$vehicleId/invite-driver'),
          headers: await _headers(),
          body: jsonEncode({'id_document': documento}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return invitarConductor(vehicleId: vehicleId, documento: documento);
    }
    if (response.statusCode == 200 || response.statusCode == 201) return null;
    return _leerError(response);
  }

  Future<String?> solicitarVehiculoPorPlaca(String placa) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/user/vehicles/association-requests'),
          headers: await _headers(),
          body: jsonEncode({'vehicle_plate': _normalizarPlaca(placa)}),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return solicitarVehiculoPorPlaca(_normalizarPlaca(placa));
    }
    if (response.statusCode == 200 || response.statusCode == 201) return null;
    return _leerError(response);
  }

  Future<String?> retirarConductor({
    required String vehicleId,
    required String driverId,
  }) async {
    final response = await http
        .delete(
          Uri.parse(
              '${Environment.apiUrl}/user/vehicles/$vehicleId/drivers/$driverId'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return retirarConductor(vehicleId: vehicleId, driverId: driverId);
    }
    if (response.statusCode == 200 || response.statusCode == 204) return null;
    return _leerError(response);
  }

  Future<String?> liberarVehiculo({required String vehicleId}) async {
    final response = await http
        .post(
          Uri.parse('${Environment.apiUrl}/user/vehicles/$vehicleId/release'),
          headers: await _headers(),
        )
        .timeout(_timeout);

    if (response.statusCode == 401 && await _authService.refreshToken()) {
      return liberarVehiculo(vehicleId: vehicleId);
    }
    if (response.statusCode == 200 || response.statusCode == 204) return null;
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
