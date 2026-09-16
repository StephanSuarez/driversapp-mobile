import 'package:flutter/material.dart';

class PromocionesPantalla extends StatelessWidget {
  const PromocionesPantalla({super.key});

  static const String _fondoPath = 'assets/imagenes/fondo.jpg';
  static const String _logoWPath = 'assets/imagenes/logo_w.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      appBar: AppBar(
        title: const Text("PROMOCIONES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
        child: Container(
          width: double.infinity,
          // Definimos la forma exterior del contenedor (Amarillo, bordes redondeados, borde negro)
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700), 
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.black, width: 2),
          ),
          // ClipRRect para que las imágenes internas respeten los bordes redondeados
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28), // Un poco menos que el borde exterior
            child: Stack(
              fit: StackFit.expand, // Para que los hijos llenen el espacio
              children: [
                // CAPA 1: La textura de fondo (fondo.jpg)
                Image.asset(
                  _fondoPath,
                  fit: BoxFit.cover,
                ),
                
                // CAPA 2: La W centrada (logo_w.png)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Image.asset(
                      _logoWPath,
                      fit: BoxFit.contain,
                      // Ajusta la opacidad si la W es muy fuerte en la imagen original
                      opacity: const AlwaysStoppedAnimation(0.6), 
                    ),
                  ),
                ),

                // CAPA 3: El contenido (Tarjeta blanca y "Hoy")
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black),
                        ),
                        child: const Text("Hoy", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 20),
                      // Tarjeta blanca
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: const Text(
                          "Solo por el día de hoy los taxistas tendrán el 20% de descuento en el autolavado X...",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}