import 'package:flutter/material.dart';

import '../pantallas/autenticacion/documentos_conductor_pantalla.dart';
import '../pantallas/autenticacion/fotos_perfil_pantalla.dart';
import '../pantallas/autenticacion/fotos_vehiculo_pantalla.dart';
import '../pantallas/autenticacion/licencia_pantalla.dart';
import '../pantallas/autenticacion/pantalla_espera_verificacion.dart';
import '../pantallas/autenticacion/tarjeta_propiedad_pantalla.dart';
import '../pantallas/autenticacion/tarjeton_pantalla.dart';
import '../pantallas/autenticacion/verificacion_otp_pantalla.dart';
import '../pantallas/inicio/home_pantalla.dart';
import 'auth_service.dart';

class SessionNavigation {
  static Future<bool> redirectIfAuthenticated(BuildContext context) async {
    final authService = AuthService();
    final token = await authService.obtenerToken();
    if (token == null || token.isEmpty) return false;

    final ruta = await authService
        .determinarPantallaInicial()
        .timeout(const Duration(seconds: 8), onTimeout: () => 'foto_perfil');

    if (!context.mounted) return true;
    pushRoute(context, ruta);
    return true;
  }

  static void pushRoute(BuildContext context, String ruta) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screenForRoute(ruta)),
      (_) => false,
    );
  }

  static Widget screenForRoute(String ruta) {
    switch (ruta) {
      case 'espera':
        return const PantallaEsperaVerificacion();
      case 'otp':
        return const VerificacionOtpPantalla();
      case 'foto_perfil':
      case 'fotos_perfil':
        return const FotosPerfilPantalla();
      case 'documentos_conductor':
        return const DocumentosConductorPantalla();
      case 'foto_vehiculo':
        return const FotosVehiculoPantalla();
      case 'licencia':
        return const LicenciaPantalla();
      case 'propiedad':
        return const TarjetaPropiedadPantalla();
      case 'tarjeton':
        return const TarjetonPantalla();
      case 'home':
      case 'completado':
      default:
        return const HomePantalla();
    }
  }
}
