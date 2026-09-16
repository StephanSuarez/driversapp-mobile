// lib/pantallas/inicio/home_pantalla.dart

import 'package:flutter/material.dart';
import 'widgets/servicios_mapa.dart';
import 'widgets/barra_navegacion.dart';
import 'widgets/chat_viaje_modal.dart';
import 'membresia_pantalla.dart';
import 'promociones_pantalla.dart';
import 'comunidad_pantalla.dart';
import 'notificaciones_pantalla.dart';
import 'widgets/menu_lateral.dart';
import '../../services/auth_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/session_navigation.dart';

class HomePantalla extends StatefulWidget {
  const HomePantalla({super.key});

  @override
  State<HomePantalla> createState() => _HomePantallaState();
}

class _HomePantallaState extends State<HomePantalla>
    with WidgetsBindingObserver {
  int _indiceSeleccionado = 0;
  bool _ocultarBarra = false;
  bool _chatModalMostrandose = false;

  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService().syncTokenWithBackend();
    PushNotificationService()
        .notificationTap
        .addListener(_revisarTapNotificacion);
    _pantallas = [
      ServiciosMapaTab(
        onEstadoViajeChanged: (activo) {
          setState(() => _ocultarBarra = activo);
        },
      ),
      const MembresiaPantalla(),
      const PromocionesPantalla(),
      const ComunidadPantalla(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final redirigio = await _protegerOnboardingIncompleto();
      if (redirigio || !mounted) return;
      _revisarTapNotificacion();
      _revisarChatPendienteGuardado();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationService()
        .notificationTap
        .removeListener(_revisarTapNotificacion);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _revisarChatPendienteGuardado();
    }
  }

  void _revisarTapNotificacion() {
    final payload = PushNotificationService().notificationTap.value;
    if (payload == null) return;

    final tipo = payload['type']?.toString();
    final rideId = payload['ride_id']?.toString() ??
        payload['rideId']?.toString() ??
        payload['id_ride']?.toString();
    final esMensajeChat = tipo == 'ride_chat' ||
        tipo == 'chat' ||
        tipo == 'chat_message' ||
        tipo == 'ride_message';
    final esVolverAlViaje = tipo == 'return_to_ride';
    final esCentroNotificaciones = tipo != null &&
        (tipo.toLowerCase().contains('vehicle') ||
            tipo.toLowerCase().contains('notification'));

    if (esCentroNotificaciones) {
      PushNotificationService().notificationTap.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificacionesPantalla()),
        );
      });
      return;
    }

    if (rideId == null || rideId.isEmpty) return;

    PushNotificationService().notificationTap.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (esMensajeChat) {
        _abrirChatDesdeNotificacion(rideId);
      } else if (esVolverAlViaje) {
        _volverAlMapaDesdeNotificacion();
      }
    });
  }

  Future<bool> _protegerOnboardingIncompleto() async {
    final ruta = await AuthService()
        .determinarPantallaInicial()
        .timeout(const Duration(seconds: 8), onTimeout: () => 'foto_perfil');

    if (!mounted || ruta == 'home' || ruta == 'completado') return false;

    SessionNavigation.pushRoute(context, ruta);
    return true;
  }

  Future<void> _volverAlMapaDesdeNotificacion() async {
    if (!mounted) return;
    if (_indiceSeleccionado != 0) {
      setState(() => _indiceSeleccionado = 0);
    }
  }

  Future<void> _abrirChatDesdeNotificacion(String rideId) async {
    if (!mounted || _chatModalMostrandose) return;

    if (_indiceSeleccionado != 0) {
      setState(() => _indiceSeleccionado = 0);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
    }

    _chatModalMostrandose = true;
    try {
      DriverLocationService().clearUnreadChat(rideId);
      await ChatViajeModal.mostrar(context, rideId);
    } finally {
      _chatModalMostrandose = false;
    }
  }

  void _revisarChatPendienteGuardado() {
    PushNotificationService().consumePendingChatNotificationRideId().then(
      (rideId) {
        if (!mounted || rideId == null) return;
        _abrirChatDesdeNotificacion(rideId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      drawer: const MenuLateral(),
      body: Stack(
        children: [
          IndexedStack(
            index: _indiceSeleccionado,
            children: _pantallas,
          ),
          if (!_ocultarBarra)
            BarraNavegacionOcultable(
              indiceSeleccionado: _indiceSeleccionado,
              onTabSelected: (index) {
                setState(() => _indiceSeleccionado = index);
              },
            ),
        ],
      ),
    );
  }
}
