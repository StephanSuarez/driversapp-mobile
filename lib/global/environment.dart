// lib/global/environment.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Environment {
  // Helper: lee del .env y si falta o el archivo no fue cargado, devuelve fallback.
  static String _env(String key, String fallback) {
    try {
      final v = dotenv.maybeGet(key);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return fallback;
  }

  // ============ Backend ============
  static String get apiBaseUrl => _env('API_BASE_URL', 'https://services.example.com');
  static String get wsUrl => _env('WS_URL', 'wss://services.example.com');
  static String get apiPrefix => _env('API_PREFIX', '/api/ms/driversapp-service');
  static String get apiUrl => '$apiBaseUrl$apiPrefix';
  static String get wsApiUrl => '$wsUrl$apiPrefix';

  // ============ Llaves compartidas ============
  static String get rideAuthKey => _env('RIDE_AUTH_KEY', '');

  // ============ Mapbox ============
  static String get mapboxToken => _env('MAPBOX_TOKEN', '');
  static String get mapboxStyleUrl => _env('MAPBOX_STYLE_URL', '');
  static String get mapboxDirectionsUrl => _env('MAPBOX_DIRECTIONS_URL', 'https://api.mapbox.com/directions/v5/mapbox');

  // ============ Tracking ============
  static int get locationUpdateIntervalSeconds {
    return int.tryParse(_env('LOCATION_UPDATE_INTERVAL_SECONDS', '15')) ?? 15;
  }

  // ============ Token de sesión del conductor (runtime) ============
  static String driverToken = '';

  // ============ URLs de viaje ============
  static String get driverOnlineUrl  => '$apiUrl/drivers/location/online';
  static String get driverOfflineUrl => '$apiUrl/drivers/location/offline';

  static String cancelarViajeUrl(String rideId) => '$apiUrl/drivers/me/ride/$rideId/cancel';
  static String rechazarViajeUrl(String rideId) => '$apiUrl/drivers/me/ride/$rideId/reject';
  static String finalizarViajeUrl(String rideId) => '$apiUrl/ride/$rideId/status';
  static String calificarClienteUrl(String rideId) => '$apiUrl/rides/$rideId/client-rating';

  static Future<void> cargarTokenLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null && token.isNotEmpty) {
      driverToken = token;
    }
  }
}
