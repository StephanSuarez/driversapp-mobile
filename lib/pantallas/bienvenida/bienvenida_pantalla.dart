import 'package:flutter/material.dart';

import '../../services/session_navigation.dart';
import '../../widgets/boton_bordeado.dart';
import '../autenticacion/login_pantalla.dart';
import '../autenticacion/registro_pantalla.dart';

class BienvenidaPantalla extends StatefulWidget {
  const BienvenidaPantalla({super.key});

  @override
  State<BienvenidaPantalla> createState() => _BienvenidaPantallaState();
}

class _BienvenidaPantallaState extends State<BienvenidaPantalla> {
  bool _verificandoSesion = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _validarSesion());
  }

  Future<void> _validarSesion() async {
    final redirigio = await SessionNavigation.redirectIfAuthenticated(context);
    if (!mounted || redirigio) return;
    setState(() => _verificandoSesion = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/imagenes/fondo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFFFFD600));
              },
            ),
          ),
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: _verificandoSesion
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),
                        Image.asset(
                          'assets/imagenes/logo_w.png',
                          width: 500,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error, size: 50),
                        ),
                        const Spacer(flex: 2),
                        BotonBordeado(
                          texto: "INICIAR SESION",
                          alPresionar: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPantalla(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 25),
                        BotonBordeado(
                          texto: "REGISTRARSE",
                          alPresionar: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegistroPantalla(),
                              ),
                            );
                          },
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
