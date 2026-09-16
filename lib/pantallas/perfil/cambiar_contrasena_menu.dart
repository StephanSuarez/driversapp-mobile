import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class CambiarContrasenaMenu extends StatefulWidget {
  const CambiarContrasenaMenu({super.key});

  @override
  State<CambiarContrasenaMenu> createState() => _CambiarContrasenaMenuState();
}

class _CambiarContrasenaMenuState extends State<CambiarContrasenaMenu> {
  final _authService = AuthService();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();
  String _nombre = 'Conductor DriversApp';
  String _fotoUrl = '';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfilCacheado();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    final data = await _authService.obtenerPerfil();
    if (!mounted || data == null) return;

    _aplicarPerfil(data);
  }

  Future<void> _cargarPerfilCacheado() async {
    final data = await _authService.obtenerPerfilCacheado();
    if (!mounted || data == null) return;

    _aplicarPerfil(data);
  }

  void _aplicarPerfil(Map<String, dynamic> data) {
    final driverInfo = data['driver_info'];
    setState(() {
      _nombre = data['full_name']?.toString() ?? 'Conductor DriversApp';
      if (driverInfo is Map<String, dynamic>) {
        _fotoUrl = driverInfo['profile_photo']?.toString() ?? '';
      }
    });
  }

  Future<void> _guardar() async {
    final actual = _actualController.text.trim();
    final nueva = _nuevaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (actual.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      _mostrarMensaje("Completa todos los campos.", esError: true);
      return;
    }
    if (nueva.length < 6) {
      _mostrarMensaje("La contraseña debe tener al menos 6 caracteres.",
          esError: true);
      return;
    }
    if (nueva != confirmar) {
      _mostrarMensaje("Las contraseñas nuevas no coinciden.", esError: true);
      return;
    }
    if (actual == nueva) {
      _mostrarMensaje("La contraseña nueva debe ser diferente.", esError: true);
      return;
    }

    setState(() => _guardando = true);
    final error = await _authService.cambiarContrasena(
      contrasenaActual: actual,
      contrasenaNueva: nueva,
    );
    if (!mounted) return;
    setState(() => _guardando = false);

    if (error == null) {
      _actualController.clear();
      _nuevaController.clear();
      _confirmarController.clear();
      _mostrarMensaje("Contraseña actualizada.");
    } else {
      _mostrarMensaje(error, esError: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red.shade700 : Colors.black87,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String logoPath = 'assets/imagenes/logito.png';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          size: 28, color: Colors.black),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    "CAMBIAR CONTRASEÑA",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Montserrat',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                _nombre,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD54F), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) : null,
                  onBackgroundImageError: _fotoUrl.isNotEmpty
                      ? (_, __) => debugPrint("Error cargando imagen de perfil")
                      : null,
                  child: _fotoUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 48,
                          color: Color(0xFFBDBDBD),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      "La contraseña debe tener al menos 6 caracteres.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 25),
                    _buildRoundedInput(
                        controller: _actualController,
                        hintText: "Contraseña actual"),
                    const SizedBox(height: 15),
                    _buildRoundedInput(
                        controller: _nuevaController,
                        hintText: "Contraseña nueva"),
                    const SizedBox(height: 15),
                    _buildRoundedInput(
                        controller: _confirmarController,
                        hintText: "Confirmar contraseña nueva"),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          shadowColor: Colors.black.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                                color: Colors.black, width: 1.5),
                          ),
                        ),
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : const Text(
                                "CONTINUAR",
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Image.asset(
                logoPath,
                height: 70,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.local_taxi,
                      size: 70, color: Colors.black);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundedInput({
    required TextEditingController controller,
    required String hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: true,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
              fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: Colors.black, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
