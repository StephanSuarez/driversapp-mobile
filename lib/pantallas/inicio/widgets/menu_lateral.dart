// lib/pantallas/inicio/widgets/menu_lateral.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:driversapp/pantallas/bienvenida/bienvenida_pantalla.dart';
import 'package:driversapp/pantallas/inicio/mis_vehiculos_pantalla.dart';
import 'package:driversapp/pantallas/inicio/membresia_pantalla.dart';
import 'package:driversapp/pantallas/inicio/notificaciones_pantalla.dart';
import 'package:driversapp/pantallas/perfil/cambiar_contrasena_menu.dart';
import 'package:driversapp/pantallas/perfil/terminos_menu.dart';
import 'package:driversapp/services/auth_service.dart';
import 'package:driversapp/services/driver_location_service.dart';
import 'package:driversapp/services/notification_center_service.dart';

class MenuLateral extends StatefulWidget {
  const MenuLateral({super.key});

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  final _authService = AuthService();
  final _notificationService = NotificationCenterService();
  String _nombre = "Cargando...";
  String _placa = "---";
  String _fotoUrl = "";
  String _rating = "—";
  int _viajes = 0;
  int _notificacionesNoLeidas = 0;
  bool _cargandoPerfil = true;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfilCacheado();
    _cargarPerfilConductor();
    _cargarNotificacionesNoLeidas();
  }

  Future<void> _cargarNotificacionesNoLeidas() async {
    final count = await _notificationService.contarNoLeidas();
    if (!mounted) return;
    setState(() => _notificacionesNoLeidas = count);
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) debugPrint("Error abriendo: $url");
    } catch (e) {
      debugPrint("Excepción abriendo link: $e");
    }
  }

  Future<void> _cargarPerfilConductor() async {
    final data = await _authService.obtenerPerfil();
    if (!mounted) return;

    if (data == null) {
      setState(() => _cargandoPerfil = false);
      return;
    }

    _aplicarPerfil(data);
  }

  Future<void> _cargarPerfilCacheado() async {
    final data = await _authService.obtenerPerfilCacheado();
    if (!mounted || data == null) return;
    _aplicarPerfil(data);
  }

  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;

    setState(() => _cerrandoSesion = true);
    await DriverLocationService().finalizarJornada();
    await _authService.logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BienvenidaPantalla()),
      (_) => false,
    );
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesPantalla()),
    );
    if (!mounted) return;
    _cargarNotificacionesNoLeidas();
  }

  void _aplicarPerfil(Map<String, dynamic> data, {bool cargando = false}) {
    final driverInfo = data['driver_info'];
    setState(() {
      _nombre = data['full_name']?.toString() ?? "Conductor DriversApp";
      if (driverInfo is Map<String, dynamic>) {
        _fotoUrl = driverInfo['profile_photo']?.toString() ?? "";
        _placa = driverInfo['vehicle_plate']?.toString() ?? "---";
        _rating = _formatearRating(driverInfo['rating_average']);
        _viajes = _enteroDesde(driverInfo['completed_rides']);
      }
      _cargandoPerfil = cargando;
    });
  }

  String _formatearRating(dynamic value) {
    final rating = value is num ? value.toDouble() : double.tryParse('$value');
    if (rating == null || rating <= 0) return "—";
    return rating.toStringAsFixed(1);
  }

  int _enteroDesde(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    const Color amarilloDriversApp = Color(0xFFFFD600);
    final double topPadding = MediaQuery.of(context).padding.top;

    return Drawer(
      backgroundColor: Colors.white,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, topPadding + 14, 18, 30),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 48),
                    const Spacer(),
                    _buildHeaderIcon(
                      icon: Icons.notifications_none_rounded,
                      onTap: _abrirNotificaciones,
                      badgeCount: _notificacionesNoLeidas,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildAvatarMinimal(amarilloDriversApp),
                const SizedBox(height: 20),
                _cargandoPerfil
                    ? _buildSkeleton(width: 180, height: 28, radius: 8)
                    : Text(
                        _nombre.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                const SizedBox(height: 10),
                _buildRatingBar(amarilloDriversApp),
                const SizedBox(height: 15),
                _buildPlateBadge(),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Divider(color: Color(0xFFF5F5F5), thickness: 2),
          ),

          // OPCIONES
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildMenuOption(
                  "Mis vehículos",
                  Icons.local_taxi_rounded,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MisVehiculosPantalla(),
                    ),
                  ),
                ),
                _buildMenuOption(
                  "Membresía",
                  Icons.workspace_premium_rounded,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MembresiaPantalla(),
                    ),
                  ),
                ),
                _buildMenuOption(
                    "Historial de Viajes", Icons.history_rounded, () {}),
                _buildMenuOption(
                  "Seguridad de Cuenta",
                  Icons.vpn_key_rounded,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CambiarContrasenaMenu(),
                    ),
                  ),
                ),
                _buildMenuOption(
                  "Soporte Técnico",
                  Icons.chat_bubble_rounded,
                  () => _launchURL(
                    'https://wa.me/570000000000?text=Hola%2C%20buen%20d%C3%ADa.%20Necesito%20ayuda%20con%20un%20problema.',
                  ),
                ),
                _buildMenuOption(
                  "Página Web",
                  Icons.language_rounded,
                  () => _launchURL('https://example.com/'),
                ),
                _buildMenuOption(
                  "Términos Legales",
                  Icons.verified_user_rounded,
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TerminosMenu())),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25),
                  child: Divider(color: Color(0xFFF0F0F0), thickness: 1),
                ),
                _buildMenuOption(
                  _cerrandoSesion ? "Cerrando sesión..." : "Cerrar sesión",
                  Icons.logout_rounded,
                  _cerrarSesion,
                  iconColor: Colors.redAccent,
                  textColor: Colors.red.shade700,
                  showChevron: false,
                ),
              ],
            ),
          ),

          // FOOTER
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Image.asset(
              'assets/imagenes/logito.png',
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                "DRIVERSAPP",
                style: TextStyle(
                  color: amarilloDriversApp,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarMinimal(Color color) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: CircleAvatar(
        radius: 45,
        backgroundColor: const Color(0xFFF8F8F8),
        backgroundImage: !_cargandoPerfil && _fotoUrl.isNotEmpty
            ? NetworkImage(_fotoUrl)
            : null,
        child: _cargandoPerfil
            ? ClipOval(child: _buildSkeleton(width: 90, height: 90, radius: 45))
            : _fotoUrl.isEmpty
                ? const Icon(Icons.person, size: 45, color: Color(0xFFE0E0E0))
                : null,
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Colors.black, size: 30),
              if (badgeCount > 0)
                Positioned(
                  right: 1,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingBar(Color color) {
    if (_cargandoPerfil) {
      return _buildSkeleton(width: 130, height: 20, radius: 6);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _rating,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.star_rounded, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          "•  $_viajes viajes",
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlateBadge() {
    if (_cargandoPerfil) {
      return _buildSkeleton(width: 120, height: 64, radius: 10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _placa,
        style: const TextStyle(
          color: Color(0xFFFFD600),
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 2.0,
        ),
      ),
    );
  }

  Widget _buildSkeleton({
    required double width,
    required double height,
    double radius = 12,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return Opacity(opacity: opacity, child: child);
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color iconColor = const Color(0xFFFFD600),
    Color textColor = Colors.black87,
    bool showChevron = true,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 26),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      trailing: showChevron
          ? const Icon(Icons.chevron_right_rounded,
              color: Colors.black12, size: 20)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    );
  }
}
