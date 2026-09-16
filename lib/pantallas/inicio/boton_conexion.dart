// lib/pantallas/inicio/widgets/boton_conexion.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/driver_location_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/app_top_toast.dart';

class BotonConexionTop extends StatefulWidget {
  final bool initialConnectionState;

  const BotonConexionTop({super.key, required this.initialConnectionState});

  @override
  State<BotonConexionTop> createState() => _BotonConexionTopState();
}

class _BotonConexionTopState extends State<BotonConexionTop>
    with SingleTickerProviderStateMixin {
  late bool _isOnline;
  bool _isLoading = false;

  final DriverLocationService _locationService = DriverLocationService();
  final VehicleService _vehicleService = VehicleService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  static const _colorOnline = Color(0xFF00FF88);
  static const _colorOffline = Color(0xFFFF1744);
  static const _colorBgDark = Color(0xFF0D0D0F);

  @override
  void initState() {
    super.initState();
    _isOnline = _locationService.isTrackingNotifier.value;
    _locationService.isTrackingNotifier.addListener(_onTrackingChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  void _onTrackingChanged() {
    final v = _locationService.isTrackingNotifier.value;
    if (mounted && v != _isOnline) {
      setState(() => _isOnline = v);
    }
  }

  @override
  void dispose() {
    _locationService.isTrackingNotifier.removeListener(_onTrackingChanged);
    _pulseController.dispose();
    // ¡OJO! Ya no detenemos el rastreo aquí. El rastreo sigue vivo en el Service.
    super.dispose();
  }

  void _mostrarNotificacion(bool conectado) {
    AppTopToast.show(
      context,
      message: conectado ? 'En línea' : 'Desconectado',
      type: conectado ? AppToastType.success : AppToastType.info,
    );
  }

  void _confirmarDesconexion() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => _DialogoFinalizar(
        onConfirm: () {
          Navigator.pop(context);
          _ejecutarCambioEstado(false);
        },
      ),
    );
  }

  Future<void> _ejecutarCambioEstado(bool nuevoEstado) async {
    setState(() => _isLoading = true);

    try {
      String? selectedVehicleId;
      if (nuevoEstado) {
        selectedVehicleId = await _seleccionarVehiculoDisponible();
        if (selectedVehicleId == null) {
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      // 1. Verificar si el usuario dio permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw 'Los permisos de ubicación fueron denegados.';
        }
      }

      // 2. Verificar si el GPS del celular está encendido
      bool isLocationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!isLocationServiceEnabled) {
        throw 'Por favor, enciende el GPS de tu teléfono.';
      }

      // 3. Dejamos que el Service se encargue de todo (conectar y prender el Timer)
      bool success = false;
      if (nuevoEstado) {
        success = await _locationService.iniciarJornada(
            vehicleId: selectedVehicleId!);
      } else {
        success = await _locationService.finalizarJornada();
      }

      if (!mounted) return;

      if (success) {
        setState(() {
          _isOnline = nuevoEstado;
          _isLoading = false;
        });
        HapticFeedback.mediumImpact();
        _mostrarNotificacion(nuevoEstado);
      } else {
        throw 'Error en el servidor. Intenta de nuevo.';
      }
    } catch (e) {
      debugPrint('ERROR AL CONECTAR: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppTopToast.show(
          context,
          message: e.toString(),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<String?> _seleccionarVehiculoDisponible() async {
    final vehiculos = await _vehicleService.vehiculosDisponiblesParaConectar();
    if (!mounted) return null;

    if (vehiculos.isEmpty) {
      AppTopToast.show(
        context,
        message: 'Necesitas un vehículo autorizado y validado para conectarte.',
        type: AppToastType.error,
      );
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige el vehículo para tu jornada',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Solo un conductor puede usar un vehículo a la vez.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...vehiculos.map((vehicle) {
                final id = vehicle['id']?.toString();
                final placa =
                    vehicle['vehicle_plate']?.toString() ?? 'Sin placa';
                final order = vehicle['order_number']?.toString();
                final owner = vehicle['owner_name']?.toString();
                final availability =
                    vehicle['availability_status']?.toString().toUpperCase();
                final activeDriver = vehicle['active_driver_name']?.toString();
                final inUseByOther = availability == 'IN_USE_BY_OTHER';
                final inUseByMe = availability == 'IN_USE_BY_ME';
                final subtitle = [
                  if (order != null && order.isNotEmpty) 'Orden $order',
                  if (owner != null && owner.isNotEmpty) 'Dueño $owner',
                  if (inUseByMe) 'En uso por ti',
                  if (inUseByOther)
                    'En uso por ${activeDriver == null || activeDriver.isEmpty ? 'otro conductor' : activeDriver}',
                ].join(' · ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: inUseByOther
                        ? const Color(0xFFF4F4F4)
                        : const Color(0xFFFFF8CC),
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      enabled: !inUseByOther,
                      leading: const Icon(Icons.local_taxi_rounded),
                      title: Text(
                        placa,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      trailing: inUseByOther
                          ? const Icon(Icons.lock_rounded)
                          : const Text(
                              'Usar',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                      onTap: id == null || inUseByOther
                          ? () {
                              AppTopToast.show(
                                context,
                                message:
                                    'Este vehículo ya está en uso por otro conductor.',
                                type: AppToastType.error,
                              );
                            }
                          : () => Navigator.pop(context, id),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorEstado = _isOnline ? _colorOnline : _colorOffline;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
            decoration: BoxDecoration(
              color: _colorBgDark.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _HandleBar(),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) => _RadarIcon(
                    scale: _pulseAnimation.value,
                    isOnline: _isOnline,
                    color: colorEstado,
                  ),
                ),
                const SizedBox(height: 15),
                _EstadoInfo(isOnline: _isOnline, color: colorEstado),
                const SizedBox(height: 25),
                _BotonAccion(
                  isLoading: _isLoading,
                  isOnline: _isOnline,
                  color: colorEstado,
                  onPressed: () => _isLoading
                      ? null
                      : (_isOnline
                          ? _confirmarDesconexion()
                          : _ejecutarCambioEstado(true)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _RadarIcon extends StatelessWidget {
  final double scale;
  final bool isOnline;
  final Color color;

  const _RadarIcon(
      {required this.scale, required this.isOnline, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (isOnline)
          Container(
            width: 80 * scale,
            height: 80 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.03 * (1.2 - scale)),
            ),
          ),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 15,
                  spreadRadius: 1)
            ],
          ),
          child: Icon(
              isOnline ? Icons.bolt_rounded : Icons.power_settings_new_rounded,
              color: color,
              size: 28),
        ),
      ],
    );
  }
}

class _EstadoInfo extends StatelessWidget {
  final bool isOnline;
  final Color color;

  const _EstadoInfo({required this.isOnline, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isOnline ? "EN LÍNEA" : "DESCONECTADO",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isOnline ? "Buscando viajes..." : "Conéctate para trabajar.",
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final bool isLoading;
  final bool isOnline;
  final Color color;
  final VoidCallback onPressed;

  const _BotonAccion(
      {required this.isLoading,
      required this.isOnline,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        width: 180,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(color: color, strokeWidth: 2.5))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        isOnline
                            ? Icons.power_settings_new_rounded
                            : Icons.play_arrow_rounded,
                        color: color,
                        size: 18),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? "Finalizar" : "Iniciar",
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _DialogoFinalizar extends StatelessWidget {
  final VoidCallback onConfirm;
  const _DialogoFinalizar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.power_settings_new_rounded,
                color: Color(0xFFFF2A5F), size: 45),
            const SizedBox(height: 16),
            const Text(
              "¿Finalizar jornada?",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _BotonDialogo(
                    text: "No",
                    color: const Color(0xFF2C2C2E),
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BotonDialogo(
                    text: "Sí, salir",
                    color: const Color(0xFFFF2A5F),
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonDialogo extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _BotonDialogo(
      {required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }
}
