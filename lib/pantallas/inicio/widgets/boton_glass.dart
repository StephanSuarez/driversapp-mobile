// lib/pantallas/inicio/widgets/boton_glass.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class BotonGlass extends StatelessWidget {
  final IconData icono;
  final VoidCallback onPressed;
  final Color? colorIcono;

  const BotonGlass({
    super.key,
    required this.icono,
    required this.onPressed,
    this.colorIcono,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(31), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Material(
            color: Colors.white.withAlpha(217),
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 50, 
                height: 50,
                child: Icon(icono, color: colorIcono ?? Colors.black87, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}