import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/contenedor_vidrio.dart';
import '../../widgets/boton_bordeado.dart';
import '../../temas/colores.dart';
// Importamos la pantalla siguiente (OTP)
import 'verificacion_otp_pantalla.dart'; 

class OlvidoContrasenaPantalla extends StatelessWidget {
  const OlvidoContrasenaPantalla({super.key});

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
                    const SizedBox(height: 20),
                    
                    // LOGO
                    Image.asset(
                      'assets/imagenes/logo_w.png',
                      width: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 50),
                    ),

                    const SizedBox(height: 30),

                    // --- TARJETA DE VIDRIO ---
                    ContenedorVidrio(
                      ancho: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                      child: Column(
                        children: [
                          
                          // Agregamos const aquí porque el icono no cambia
                          const Icon(Icons.lock_reset, size: 60, color: ColoresApp.negro),
                          
                          const SizedBox(height: 10),

                          
                          const Text(
                            "Recuperar Contraseña",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: ColoresApp.negro,
                            ),
                          ),

                          const SizedBox(height: 10),

                          
                          Text(
                            "Ingresa tu número de celular y te enviaremos un código para restablecer tu contraseña.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ColoresApp.negro.withValues(alpha: 0.6),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // INPUT: CELULAR (Solo números)
                          _campoTexto(
                            icono: Icons.phone_android, 
                            texto: "Celular", 
                            esNumero: true
                          ),

                          const SizedBox(height: 30),

                          // BOTÓN ENVIAR CÓDIGO -> VA AL SMS (MODO RECUPERACIÓN)
                          BotonBordeado(
                            texto: "ENVIAR CÓDIGO",
                            alPresionar: () {
                              // Navegación correcta pasando el parámetro esRecuperacion: true
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const VerificacionOtpPantalla(esRecuperacion: true),
                                ),
                              );
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

          // BOTÓN ATRÁS
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: ColoresApp.negro),
              onPressed: () => Navigator.pop(context),
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
    bool esNumero = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ColoresApp.negro.withValues(alpha: 0.5)),
      ),
      child: TextField(
        keyboardType: esNumero ? TextInputType.number : TextInputType.text,
        inputFormatters: esNumero ? [FilteringTextInputFormatter.digitsOnly] : [],
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
      