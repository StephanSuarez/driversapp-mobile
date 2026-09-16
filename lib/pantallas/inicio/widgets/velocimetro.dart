// lib/pantallas/inicio/widgets/velocimetro.dart

import 'dart:ui';
import 'package:flutter/material.dart';

class Velocimetro extends StatelessWidget {
  final int estadoViaje;
  final bool panelExpandido;
  final ValueNotifier<double> velocidadActual;

  const Velocimetro({
    Key? key,
    required this.estadoViaje,
    required this.panelExpandido,
    required this.velocidadActual,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (estadoViaje == 0) return const SizedBox.shrink();
    
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: panelExpandido ? 290 : 130, 
      left: 15, 
      child: ValueListenableBuilder<double>(
        valueListenable: velocidadActual,
        builder: (context, speed, child) {
          final bool exceso = speed > 80;
          
          return ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 60, 
                width: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: exceso 
                        ? [Colors.red.withAlpha(204), Colors.red.shade900.withAlpha(153)]
                        : [Colors.white.withAlpha(204), Colors.white.withAlpha(102)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: exceso ? Colors.red.withAlpha(102) : Colors.black.withAlpha(20), 
                      blurRadius: exceso ? 12 : 8, 
                      spreadRadius: exceso ? 2 : 0,
                      offset: const Offset(0, 3)
                    )
                  ],
                  border: Border.all(
                    color: exceso ? Colors.redAccent.withAlpha(204) : Colors.white.withAlpha(153), 
                    width: 1.5
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      speed.toStringAsFixed(0), 
                      style: TextStyle(
                        color: exceso ? Colors.white : Colors.black87, 
                        fontSize: 22, 
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      )
                    ),
                    Text(
                      "km/h", 
                      style: TextStyle(
                        color: exceso ? Colors.white.withAlpha(204) : Colors.black54, 
                        fontSize: 9, 
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}