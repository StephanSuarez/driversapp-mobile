// lib/pantallas/inicio/widgets/modal_cancelacion.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../services/driver_location_service.dart';

class ModalCancelacion {
  static void mostrar(BuildContext context, String rideId, VoidCallback onCancelado) {
    showGeneralDialog(
      context: context, 
      barrierColor: Colors.black.withAlpha(100), 
      barrierDismissible: true, 
      barrierLabel: 'Cerrar', 
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85, 
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(180), 
                    borderRadius: BorderRadius.circular(28), 
                    border: Border.all(color: Colors.white.withAlpha(150), width: 1.5)
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(height: 60, width: 60, decoration: const BoxDecoration(color: Color(0x1FFF0000), shape: BoxShape.circle), child: Icon(Icons.close_rounded, color: Colors.red.shade700, size: 35)),
                      const SizedBox(height: 20), const Text("¿Cancelar viaje?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                      const SizedBox(height: 12), const Text("¿Estás seguro de que deseas cancelar este viaje?", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black54)),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(child: InkWell(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.white.withAlpha(100), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)), child: const Text("Mantener", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800))))),
                          const SizedBox(width: 12),
                          Expanded(child: InkWell(onTap: () async {
                            Navigator.pop(context); 
                            bool ok = await DriverLocationService().cancelarViaje(rideId);
                            if (ok) { onCancelado(); }
                          }, child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(16)), child: const Text("Sí, cancelar", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}