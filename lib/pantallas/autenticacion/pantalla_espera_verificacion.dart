import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../inicio/home_pantalla.dart';
import 'login_pantalla.dart';

class PantallaEsperaVerificacion extends StatefulWidget {
  const PantallaEsperaVerificacion({super.key});

  @override
  State<PantallaEsperaVerificacion> createState() => _PantallaEsperaVerificacionState();
}

class _PantallaEsperaVerificacionState extends State<PantallaEsperaVerificacion>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  Timer? _timer;
  bool _verificando = false;

  static const String _fondoPath = 'assets/imagenes/fondo_w.png';
  static const String _seguridadIconPath = 'assets/imagenes/seguridad.png';
  static const String _whatsappIconPath = 'assets/imagenes/whatsapp.png';

  final Uri _whatsappUrl = Uri.parse(
      "https://wa.me/570000000000?text=Hola%2C%20ya%20sub%C3%AD%20mis%20documentos%2C%20quiero%20acelerar%20mi%20proceso%20de%20registro");

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine));
    PushNotificationService()
        .notificationTap
        .addListener(_revisarNotificacionAprobacion);
    PushNotificationService().syncTokenWithBackend();
    _startStatusPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarEstadoAhora());
  }

  @override
  void dispose() {
    _timer?.cancel();
    PushNotificationService()
        .notificationTap
        .removeListener(_revisarNotificacionAprobacion);
    _animController.dispose();
    super.dispose();
  }

  void _startStatusPolling() {
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) async {
      await _verificarEstadoAhora();
    });
  }

  void _revisarNotificacionAprobacion() {
    final payload = PushNotificationService().notificationTap.value;
    if (payload == null) return;

    final type = payload['type']?.toString();
    final notificationType = payload['notification_type']?.toString();
    final event = payload['event']?.toString();
    final route = payload['route']?.toString();

    final esAprobacion = notificationType == 'DRIVER_ACCOUNT_APPROVED' ||
        type == 'DRIVER_ACCOUNT_APPROVED' ||
        event == 'driver_account_approved' ||
        route == 'home';

    if (!esAprobacion) return;

    PushNotificationService().notificationTap.value = null;
    _verificarEstadoAhora(force: true);
  }

  Future<void> _verificarEstadoAhora({bool force = false}) async {
    if (_verificando || !mounted) return;
    setState(() => _verificando = true);

    try {
      final destino = await _authService.determinarPantallaInicial();
      if (!mounted) return;

      if (destino == 'home') {
        _timer?.cancel();
        _handleSuccessState();
      } else if (destino == 'login') {
        _timer?.cancel();
        _navigateToLogin();
      } else if (force) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estamos actualizando tu estado de verificación.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  void _handleSuccessState() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            SizedBox(width: 16),
            Expanded(
                child: Text("¡Cuenta Activada! Bienvenido a DriversApp.",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15))),
          ],
        ),
        backgroundColor: const Color(0xFF34C759),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _navigateToHome();
    });
  }

  void _navigateToHome() => Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePantalla()),
      (route) => false);

  void _navigateToLogin() => Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPantalla()),
      (route) => false);

  Future<void> _launchSupportCall() async {
    if (!await launchUrl(_whatsappUrl, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("No se pudo abrir WhatsApp")));
    }
  }

  Future<void> _processLogout() async {
    _timer?.cancel();
    await _authService.logout();
    if (mounted) _navigateToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: FractionallySizedBox(
                widthFactor: 0.80,
                child: Opacity(
                  opacity: 0.05,
                  child: Image.asset(
                    _fondoPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMainCard(),
                    const SizedBox(height: 32),
                    _buildPrimaryButton(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 60),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 75, 24, 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 40,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Validando perfil",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Nuestro equipo está revisando tus documentos para garantizar la seguridad de la comunidad DriversApp.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _verificando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Color(0xFFEAB308)))
                        : const Icon(Icons.hourglass_top_rounded,
                            color: Color(0xFFEAB308), size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      "Esperando aprobación",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          child: _buildAnimatedSecurityIcon(),
        ),
      ],
    );
  }

  Widget _buildAnimatedSecurityIcon() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Image.asset(
            _seguridadIconPath,
            height: 120,
            width: 120,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.security_rounded,
              size: 100,
              color: Color(0xFFEAB308),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _launchSupportCall,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEAB308),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              _whatsappIconPath,
              height: 24,
              width: 24,
              color: Colors.black,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.chat_bubble_outline,
                  size: 24,
                  color: Colors.black),
            ),
            const SizedBox(width: 10),
            const Text(
              "Contactar soporte",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _processLogout,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFFEF4444),
        backgroundColor:  Color(0xFFEF4444).withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: 0,
      ),
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text(
        "Cerrar sesión",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
