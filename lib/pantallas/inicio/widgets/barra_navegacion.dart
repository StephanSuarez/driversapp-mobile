// lib/pantallas/inicio/widgets/barra_navegacion.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../boton_conexion.dart';

class BarraNavegacionOcultable extends StatefulWidget {
  final int indiceSeleccionado;
  final Function(int) onTabSelected;

  const BarraNavegacionOcultable({
    super.key,
    required this.indiceSeleccionado,
    required this.onTabSelected,
  });

  @override
  State<BarraNavegacionOcultable> createState() => _BarraNavegacionOcultableState();
}

class _BarraNavegacionOcultableState extends State<BarraNavegacionOcultable> {
  bool _isVisible = true;
  bool _modalAbierto = false;
  bool _driverIsOnline = false;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double anchoPantalla = mediaQuery.size.width;
    final double margenLateral = anchoPantalla * 0.04;
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double islandBottom = bottomSafeArea + 12;
    final double toggleBottom = bottomSafeArea + 78;
    final double hiddenToggleBottom = bottomSafeArea + 20;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // 🔥 BOTÓN PARA BAJAR/SUBIR: ¡Micro-Círculo elegante! 🔥
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          // Ajusté un pelito la altura para que encaje perfecto con el nuevo tamaño
          bottom: _isVisible ? toggleBottom : hiddenToggleBottom,
          left: 0, 
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _isVisible = !_isVisible);
              },
              // 🔥 TRUCO: Hace que el toque funcione incluso si le das al borde invisible 🔥
              behavior: HitTestBehavior.opaque, 
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Espacio invisible para el dedo
                child: ClipOval( 
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
                    child: Container(
                      // 🔥 Reducido de 36x36 a 28x28 🔥
                      width: 28, height: 28, 
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3), 
                        shape: BoxShape.circle, 
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      ),
                      child: Icon(
                        _isVisible ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 16, // 🔥 Ícono miniatura 🔥
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 🔥 LA ISLA FLOTANTE (Con el centrado perfecto del botón rojo) 🔥
        AnimatedPositioned(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack, 
          bottom: _isVisible ? islandBottom : -150,
          left: margenLateral, 
          right: margenLateral, 
          child: RepaintBoundary(
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 5) setState(() => _isVisible = false);
              },
              child: _buildFloatingIsland(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingIsland() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30), 
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), 
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8), 
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35), 
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45), 
                blurRadius: 15, 
                offset: const Offset(0, 5)
              )
            ],
          ),
          child: Row(
            // El truco para que el botón rojo quede exactamente en la mitad de la pantalla
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lado Izquierdo
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLiquidIcon(0, Icons.local_taxi_rounded, "Servicios"),
                    _buildLiquidIcon(1, Icons.stars_rounded, "Membresía"),
                  ],
                ),
              ),
              
              // Botón Central (No se mueve por nada del mundo)
              _buildBotonIniciar(context),
              
              // Lado Derecho
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLiquidIcon(2, Icons.campaign_rounded, "Promo"),
                    _buildLiquidIcon(3, Icons.people_alt_rounded, "Comunidad"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonIniciar(BuildContext context) {
    final Color colorBoton = _driverIsOnline ? const Color(0xFF00E676) : const Color(0xFFE53935);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.heavyImpact();
        setState(() => _modalAbierto = true);
        
        await Future.delayed(const Duration(milliseconds: 150)); 
        if (!mounted) return;
        
        final result = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => BotonConexionTop(initialConnectionState: _driverIsOnline),
        );

        if (mounted) {
          setState(() {
            _modalAbierto = false;
            if (result != null) _driverIsOnline = result;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        height: 50, width: 50,  
        decoration: BoxDecoration(
          color: colorBoton,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorBoton.withOpacity(0.4), 
              blurRadius: 10, 
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5), 
        ),
        child: const Center(
          child: Icon(
            Icons.power_settings_new_rounded, 
            color: Colors.white, 
            size: 26 
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidIcon(int index, IconData icon, String label) {
    bool isSelected = widget.indiceSeleccionado == index;
    const Color accentColor = Color(0xFFFFD600); 

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTabSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22, 
              color: isSelected ? accentColor : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(height: 3), 
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white.withOpacity(0.7),
                fontSize: 9, 
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
