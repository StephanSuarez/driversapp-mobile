// lib/pantallas/inicio/widgets/modal_error_glass.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class ModalErrorGlass {
  static void mostrar(BuildContext context, String mensaje) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(128),
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withAlpha(100), width: 1.0),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                      const SizedBox(height: 12),
                      const Text("Código Incorrecto", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        mensaje == "OK" ? "El PIN ingresado no es válido. Intenta de nuevo." : mensaje, 
                        textAlign: TextAlign.center, 
                        style: const TextStyle(color: Colors.white70, fontSize: 13)
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 45,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("CERRAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      )
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