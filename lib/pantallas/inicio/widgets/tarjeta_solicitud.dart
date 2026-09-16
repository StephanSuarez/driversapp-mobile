// lib/pantallas/inicio/widgets/tarjeta_solicitud.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:driversapp/services/driver_location_service.dart';

class TarjetaSolicitud extends StatefulWidget {
  final Map<String, dynamic> datosViaje;
  final Function(bool aceptado, Map<String, dynamic> jsonViaje) onFinalizar;

  const TarjetaSolicitud({super.key, required this.datosViaje, required this.onFinalizar});

  static Future<void> mostrar(BuildContext context, Map<String, dynamic> jsonViaje, Function(bool aceptado, Map<String, dynamic> jsonViaje) onFinalizar) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      isDismissible: false,
      enableDrag: false,
      builder: (context) => TarjetaSolicitud(
        datosViaje: jsonViaje,
        onFinalizar: (aceptado, viaje) {
          Navigator.pop(context);
          onFinalizar(aceptado, viaje);
        },
      ),
    );
  }

  @override
  State<TarjetaSolicitud> createState() => _TarjetaSolicitudState();
}

class _TarjetaSolicitudState extends State<TarjetaSolicitud> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 40))
      ..forward().whenComplete(() {
        if (mounted && !_procesando) _handleRechazar();
      });
      
    DriverLocationService().viajeEntrante.addListener(_verificarCancelacion);
  }

  void _verificarCancelacion() {
    final viajeActual = DriverLocationService().viajeEntrante.value;
    if (viajeActual == null || viajeActual['id'] != widget.datosViaje['id']) {
      if (mounted && !_procesando) {
        _timerController.stop();
        widget.onFinalizar(false, widget.datosViaje); 
      }
    }
  }

  @override
  void dispose() {
    DriverLocationService().viajeEntrante.removeListener(_verificarCancelacion);
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _handleRechazar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    await DriverLocationService().rechazarViaje(widget.datosViaje['id'] ?? '');
    widget.onFinalizar(false, widget.datosViaje);
  }

  Future<void> _handleAceptar() async {
    if (_procesando) return;
    setState(() => _procesando = true);
    bool exito = await DriverLocationService().aceptarViaje(widget.datosViaje['id'] ?? '');
    if (!exito && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El viaje ya no está disponible'), backgroundColor: Colors.redAccent,)
      );
    }
    widget.onFinalizar(exito, widget.datosViaje);
  }

  String _fPrecio(dynamic p) {
    int v = (p is int) ? p : double.tryParse(p.toString())?.toInt() ?? 0;
    return "COP ${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}";
  }

  @override
  Widget build(BuildContext context) {
    final origin = widget.datosViaje['origin'] ?? {};
    final dest = widget.datosViaje['destination'] ?? {};
    final prefs = widget.datosViaje['client_preferences'] ?? {};
    
    final String dirOrigen = origin['place_name'] ?? "${origin['street'] ?? ''} ${origin['street_number'] ?? ''}".trim();
    final String barrioOrigen = origin['neighborhood'] ?? origin['city'] ?? "";
    final String origenCompleto = [dirOrigen, barrioOrigen].where((e) => e.isNotEmpty).join(", ");

    final String dirDestino = dest['place_name'] ?? dest['street'] ?? dest['city'] ?? "Destino no disponible";
    final String barrioDestino = dest['neighborhood'] ?? dest['city'] ?? "";
    final String destinoCompleto = [dirDestino, barrioDestino].where((e) => e.isNotEmpty).join(", ");
    
    final String precioMin = _fPrecio(widget.datosViaje['suggested_min_price']);
    final String precioMax = _fPrecio(widget.datosViaje['suggested_max_price']);
    final String km = ((widget.datosViaje['distance_meters'] ?? 0) / 1000).toStringAsFixed(1);
    final int minutos = ((widget.datosViaje['duration_seconds'] ?? 0) / 60).round();

    String metodoPago = prefs['payment_method']?.toString() ?? 'Efectivo';
    if (metodoPago.toLowerCase() == 'electronico') metodoPago = 'Transferencia';

    final bool traeMascota = prefs['brings_pet'] == 'true' || prefs['brings_pet'] == true;
    final bool pideAire = prefs['air_conditioning'] == 'true' || prefs['air_conditioning'] == true;

    return PopScope(
      canPop: false, 
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D).withOpacity(0.80),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.18), width: 1.0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                AnimatedBuilder(
                  animation: _timerController,
                  builder: (context, child) => SizedBox(
                    width: double.infinity, height: 3,
                    child: LinearProgressIndicator(
                      value: 1 - _timerController.value,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFFFFCC00),
                    ),
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/imagenes/logo_blanco.png', 
                            width: 45, 
                            height: 45, 
                            fit: BoxFit.contain, 
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("NUEVA SOLICITUD", style: TextStyle(color: Color(0xFFFFCC00), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                                    Text("$km km • $minutos min", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text("$precioMin - $precioMax", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPrefItem(Icons.payments_outlined, "Pago:", metodoPago, Colors.white70),
                          _buildPrefItem(Icons.pets, "Mascota:", traeMascota ? 'Sí' : 'No', traeMascota ? const Color(0xFFFFCC00) : Colors.white70),
                          _buildPrefItem(Icons.ac_unit, "Aire:", pideAire ? 'Sí' : 'No', pideAire ? const Color(0xFFFFCC00) : Colors.white70),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04), 
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.05))
                        ),
                        child: Column(
                          children: [
                            _itemRuta(Icons.radio_button_checked, Colors.white, origenCompleto),
                            Padding(
                              padding: const EdgeInsets.only(left: 7.0, top: 4, bottom: 4),
                              child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 12, color: Colors.white12)),
                            ),
                            _itemRuta(Icons.location_on, const Color(0xFFFFCC00), destinoCompleto),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _procesando ? null : _handleRechazar,
                            child: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                              child: const Icon(Icons.close, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _procesando ? null : _handleAceptar,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCC00), 
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(color: const Color(0xFFFFCC00).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))
                                  ]
                                ),
                                child: Center(
                                  child: _procesando 
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5))
                                    : const Text("ACEPTAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrefItem(IconData icon, String label, String value, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(width: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _itemRuta(IconData icon, Color color, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.0),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            address, 
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
          ), 
        )
      ],
    );
  }
}