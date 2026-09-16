import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/datos_temporales.dart';
import '../../bienvenida/bienvenida_pantalla.dart';
import '../fotos_perfil_pantalla.dart';

class RestablecerRegistroBoton extends StatelessWidget {
  final Widget destino;

  const RestablecerRegistroBoton({
    super.key,
    required this.destino,
  });

  Future<void> _confirmar(BuildContext context) async {
    final limpiar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Restablecer documentos"),
          content: const Text(
            "Se eliminaran las fotos y documentos guardados en este registro. "
            "Tus datos basicos y tu sesion se conservaran.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Restablecer"),
            ),
          ],
        );
      },
    );

    if (limpiar != true) return;

    await DatosTemporales.borrarDocumentosRegistro();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const FotosPerfilPantalla()),
      (route) => false,
    );
  }

  Future<void> _cerrarSesion(BuildContext context) async {
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Cerrar sesion"),
          content: const Text(
            "Se cerrara tu sesion y volveras a la pantalla inicial.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Cerrar sesion"),
            ),
          ],
        );
      },
    );

    if (cerrar != true) return;

    await AuthService().logout();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const BienvenidaPantalla()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: () => _confirmar(context),
          icon: const Icon(Icons.restart_alt_rounded, size: 20),
          label: const Text("Restablecer documentos"),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red.shade700,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton.icon(
          onPressed: () => _cerrarSesion(context),
          icon: const Icon(Icons.logout_rounded, size: 19),
          label: const Text("Cerrar sesion"),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black54,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
