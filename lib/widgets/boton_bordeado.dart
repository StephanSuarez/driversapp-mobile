import 'package:flutter/material.dart';
import '../temas/colores.dart'; // <--- Conectado a tu archivo de colores

class BotonBordeado extends StatelessWidget {
  final String texto;
  final VoidCallback alPresionar;

  const BotonBordeado({
    super.key,
    required this.texto,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    double anchoPantalla = MediaQuery.of(context).size.width;

    return SizedBox(
      width: anchoPantalla * 0.75,
      height: 55,
      child: ElevatedButton(
        onPressed: alPresionar,
        style: ElevatedButton.styleFrom(
          // 1. Usamos la variable de tu archivo central
          // (.withOpacity hace que no sea const, así que quitamos la palabra const)
          backgroundColor: ColoresApp.amarilloBoton.withOpacity(0.8),

          // 2. Usamos el negro de tu archivo central
          foregroundColor: ColoresApp.negro,
          
          elevation: 5,
          
          // 3. Borde negro usando tu archivo central
          side: const BorderSide(color: ColoresApp.negro, width: 2.0),
          
          shape: const StadiumBorder(),
        ),
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900, // Negrita fuerte
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}