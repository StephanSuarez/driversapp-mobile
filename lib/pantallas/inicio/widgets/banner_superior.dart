// lib/pantallas/inicio/widgets/banner_superior.dart

import 'dart:ui';
import 'package:flutter/material.dart';

// Banner de arriba que muestra hacia dónde girar
class BannerSuperior extends StatelessWidget {
  final int estadoViaje;
  final String instruccionNavegacion;
  final String distanciaManiobra;
  final IconData iconoNavegacion;
  final bool sonidoActivado;
  final Color colorAcento;
  final VoidCallback onToggleSonido;
  final bool panelExpandido;

  const BannerSuperior({
    super.key, 
    required this.estadoViaje,
    required this.instruccionNavegacion,
    required this.distanciaManiobra,
    required this.iconoNavegacion,
    required this.sonidoActivado,
    required this.colorAcento,
    required this.onToggleSonido,
    this.panelExpandido = false,
  });

  // funcion para limpiar el texto largo que manda mapbox y dejar solo lo importante
  String _simplificarInstruccion(String instruccion) {
    if (instruccion.isEmpty) return instruccion;
    
    String limpia = instruccion.toLowerCase();
    
    // palabras que no quiero que salgan en pantalla
    const palabrasBasura = [
      "gira a la derecha en ", 
      "gira a la izquierda en ", 
      "continúa por ", 
      "mantente a la derecha en ", 
      "mantente a la izquierda en ", 
      "hacia ", 
      "incorpora a "
    ];

    // borramos esas palabras de la instruccion
    for (final palabra in palabrasBasura) {
      limpia = limpia.replaceAll(palabra, "");
    }
    
    // ponemos la primera letra en mayuscula para que se vea bien
    if (limpia.isNotEmpty) {
      limpia = limpia[0].toUpperCase() + limpia.substring(1);
    }
    
    return limpia;
  }

  @override
  Widget build(BuildContext context) {
    // si no hay viaje, no mostramos el banner
    if (estadoViaje == 0) return const SizedBox.shrink();
    
    const Color amarilloIntenso = Color(0xFFFFD500); 
    final String instruccionCorta = _simplificarInstruccion(instruccionNavegacion);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      // ocultamos el banner subiendolo si el panel de abajo esta expandido
      top: panelExpandido ? -120 : 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: BackdropFilter(
          // efecto cristal borroso
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.only(
              // margen para que no se cruce con la barra de bateria/hora del celular
              top: MediaQuery.of(context).padding.top + 8, 
              bottom: 10,
              left: 16,
              right: 16
            ),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20), 
              border: Border(
                bottom: BorderSide(color: Colors.white.withAlpha(60), width: 0.5), 
              ),
            ),
            child: Row(
              children: [
                // circulo amarillo con la flecha de direccion
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: amarilloIntenso.withAlpha(180), 
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: amarilloIntenso.withAlpha(60), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Icon(iconoNavegacion, color: Colors.black87, size: 22),
                ),
                const SizedBox(width: 12),
                
                // textos de la calle y la distancia
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        instruccionCorta, 
                        style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.3), 
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "A $distanciaManiobra", 
                        style: TextStyle(color: Colors.black87.withAlpha(160), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                
                // boton para mutear la voz
                GestureDetector(
                  onTap: onToggleSonido,
                  behavior: HitTestBehavior.opaque, // para que sea facil de tocar
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // cambia de color si esta encendido o apagado
                      color: sonidoActivado ? amarilloIntenso.withAlpha(120) : Colors.black.withAlpha(10),
                      shape: BoxShape.circle,
                      border: Border.all(color: sonidoActivado ? amarilloIntenso.withAlpha(180) : Colors.transparent, width: 0.5),
                    ),
                    child: Icon(
                      sonidoActivado ? Icons.volume_up_rounded : Icons.volume_off_rounded, 
                      color: sonidoActivado ? Colors.black87 : Colors.black.withAlpha(100),
                      size: 20,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}