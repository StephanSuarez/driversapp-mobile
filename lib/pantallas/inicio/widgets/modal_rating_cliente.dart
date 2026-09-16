import 'dart:ui';

import 'package:flutter/material.dart';

class ModalRatingCliente {
  static Future<int?> mostrar(BuildContext context) {
    int seleccionado = 0;

    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Calificar usuario",
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Material(
              type: MaterialType.transparency,
              child: Center(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.86,
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Califica al usuario",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Tu calificación nos ayuda a mantener una comunidad segura.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final value = index + 1;
                            final activo = value <= seleccionado;
                            return IconButton(
                              tooltip: "$value estrellas",
                              onPressed: () => setState(() => seleccionado = value),
                              icon: Icon(
                                activo ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 40,
                                color: const Color(0xFFFFD600),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: seleccionado == 0
                                ? null
                                : () => Navigator.pop(dialogContext, seleccionado),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              disabledBackgroundColor: Colors.black12,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              "Guardar calificación",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text("Omitir"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }
}
