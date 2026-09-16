// lib/pantallas/inicio/widgets/modal_cobro.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModalCobro {
  // llamamos a esta funcion para que aparezca el modal en pantalla
  static Future<bool> mostrar(BuildContext context, String tarifa) async {
    bool cobroConfirmado = false;
    // Formatea el número con separador de miles (estilo COP: 8.500)
    final tarifaNum = num.tryParse(tarifa);
    final tarifaFormateada = tarifaNum != null
        ? NumberFormat.decimalPattern('es_CO').format(tarifaNum.round())
        : tarifa;

    await showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(128), // fondo oscuro transparente
      barrierDismissible: false, // obligamos al conductor a tocar un boton
      barrierLabel: 'Cobro',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                // efecto borroso para que se vea premium
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // iconito verde de exito
                      Container(
                        height: 64,
                        width: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
                      ),
                      const SizedBox(height: 20),
                      
                      const Text(
                        "Viaje Finalizado",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      
                      // el precio grandote
                      Text(
                        "\$ $tarifaFormateada",
                        style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -1.0),
                      ),
                      const SizedBox(height: 8),
                      
                      const Text(
                        "Cobrar en efectivo",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // boton para confirmar y cerrar el viaje
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            cobroConfirmado = true;
                            Navigator.pop(context); // cierra el modal
                          },
                          child: const Text(
                            "Confirmar Pago",
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
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

    return cobroConfirmado;
  }
}