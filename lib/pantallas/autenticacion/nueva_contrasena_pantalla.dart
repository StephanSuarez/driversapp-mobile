import 'package:flutter/material.dart';
import '../../widgets/contenedor_vidrio.dart';
import '../../widgets/boton_bordeado.dart';
import '../../temas/colores.dart';
import '../inicio/home_pantalla.dart';

class NuevaContrasenaPantalla extends StatelessWidget {
  const NuevaContrasenaPantalla({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondo.jpg',
              fit: BoxFit.cover,
              // CORRECCIÓN AQUÍ: Usamos nombres reales para evitar el error de variables duplicadas
              errorBuilder: (context, error, stackTrace) => Container(color: ColoresApp.amarilloBoton),
            ),
          ),

          // 2. CONTENIDO
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // LOGO
                    Image.asset(
                      'assets/imagenes/logo_w.png',
                      width: 100,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 30),

                    // --- TARJETA DE VIDRIO ---
                    ContenedorVidrio(
                      ancho: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      child: Column(
                        children: [
                          
                          // Icono y Título constantes
                          const Icon(Icons.lock_reset, size: 50, color: ColoresApp.negro),
                          
                          const SizedBox(height: 10),

                          const Text(
                            "Crear Nueva Contraseña",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.negro,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Subtítulo dinámico (por la opacidad)
                          Text(
                            "Por favor ingresa tu nueva contraseña segura.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColoresApp.negro.withValues(alpha: 0.6),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // INPUT: NUEVA CONTRASEÑA
                          _campoTexto(
                            icono: Icons.lock_outline, 
                            texto: "Nueva Contraseña", 
                            esPassword: true
                          ),

                          const SizedBox(height: 20),

                          // INPUT: CONFIRMAR CONTRASEÑA
                          _campoTexto(
                            icono: Icons.lock, 
                            texto: "Confirmar Contraseña", 
                            esPassword: true
                          ),

                          const SizedBox(height: 30),

                          // BOTÓN ENVIAR -> Va al Home con mensaje de éxito
                          BotonBordeado(
                            texto: "ENVIAR", 
                            alPresionar: () {
                              // 1. Mostrar Mensaje de Éxito
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "¡Contraseña cambiada con éxito!",
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );

                              // 2. Ir al Home (Mapa) borrando el historial
                              Future.delayed(const Duration(milliseconds: 1500), () {
                                if (context.mounted) {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HomePantalla()),
                                    (route) => false, 
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget Input Reutilizable
  Widget _campoTexto({
    required IconData icono, 
    required String texto, 
    bool esPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ColoresApp.negro.withValues(alpha: 0.5)),
      ),
      child: TextField(
        obscureText: esPassword,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icono, color: ColoresApp.negro),
          hintText: texto,
          hintStyle: TextStyle(
            fontWeight: FontWeight.bold, 
            color: ColoresApp.negro.withValues(alpha: 0.6)
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        ),
      ),
    );
  }
}