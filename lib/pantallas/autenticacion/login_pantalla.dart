import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Widgets y Temas
import '../../widgets/contenedor_vidrio.dart';
import '../../temas/colores.dart';

// Servicios
import '../../services/auth_service.dart';
import '../../services/datos_temporales.dart';
import '../../services/session_navigation.dart';

// Pantallas de flujo
import 'olvido_contrasena_pantalla.dart';
import '../inicio/home_pantalla.dart';
import 'verificacion_otp_pantalla.dart';
import 'fotos_perfil_pantalla.dart';
import 'documentos_conductor_pantalla.dart';
import 'fotos_vehiculo_pantalla.dart';
import 'licencia_pantalla.dart';
import 'tarjeta_propiedad_pantalla.dart';
import 'tarjeton_pantalla.dart';
import 'pantalla_espera_verificacion.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _cargando = false;
  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionNavigation.redirectIfAuthenticated(context);
    });
  }

  void _mostrarAlerta(String mensaje) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(mensaje,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- LÓGICA DE LOGIN ---
  void _manejarLogin() async {
    FocusScope.of(context).unfocus();

    String telefono = _phoneController.text.trim();
    String password = _passController.text.trim();

    if (telefono.isEmpty || telefono.length < 10) {
      _mostrarAlerta("Ingresa un número de celular válido.");
      return;
    }
    if (password.isEmpty) {
      _mostrarAlerta("Ingresa tu contraseña.");
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. INTENTO DE LOGIN
      debugPrint("DRIVERSAPP_LOG: Intentando conectar al backend...");
      final exito = await _authService.login(telefono, password);
      debugPrint("DRIVERSAPP_LOG: Respuesta de login: $exito");

      if (exito) {
        // 2. DETERMINAR EL SIGUIENTE PASO
        debugPrint("DRIVERSAPP_LOG: Obteniendo pantalla inicial...");
        String proximoPaso = await _authService.determinarPantallaInicial();
        debugPrint("DRIVERSAPP_LOG: Próximo paso -> $proximoPaso");

        // 3. GUARDAR EL PASO EN DISCO
        await DatosTemporales.guardarPasoActual(proximoPaso);

        if (!mounted) return;
        setState(() => _cargando = false);

        Widget pantallaDestino;

        // 4. SELECCIONAR PANTALLA
        switch (proximoPaso) {
          case 'home':
          case 'completado':
            pantallaDestino = const HomePantalla();
            break;
          case 'espera':
            pantallaDestino = const PantallaEsperaVerificacion();
            break;
          case 'otp':
            pantallaDestino = VerificacionOtpPantalla(
                numeroCelular: telefono, esRegistro: true);
            break;
          case 'foto_perfil':
          case 'fotos_perfil':
            pantallaDestino = const FotosPerfilPantalla();
            break;
          case 'documentos_conductor':
            pantallaDestino = const DocumentosConductorPantalla();
            break;
          case 'foto_vehiculo':
            pantallaDestino = const FotosVehiculoPantalla();
            break;
          case 'licencia':
            pantallaDestino = const LicenciaPantalla();
            break;
          case 'propiedad':
            pantallaDestino = const TarjetaPropiedadPantalla();
            break;
          case 'tarjeton':
            pantallaDestino = const TarjetonPantalla();
            break;
          default:
            pantallaDestino = const HomePantalla();
        }

        // 5. NAVEGAR Y BORRAR HISTORIAL
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => pantallaDestino),
          (route) => false,
        );
      } else {
        if (mounted) setState(() => _cargando = false);
        _mostrarAlerta("Credenciales incorrectas o error de conexión.");
      }
    } catch (e) {
      debugPrint("DRIVERSAPP_ERROR: $e");
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarAlerta("Error al conectar con el servidor.");
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // A. FONDO
            Positioned.fill(
              child: Image.asset(
                'assets/imagenes/fondo.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: ColoresApp.amarilloBoton),
              ),
            ),

            // B. CONTENIDO
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final keyboard = MediaQuery.viewInsetsOf(context).bottom;
                  final keyboardOpen = keyboard > 0;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      30,
                      keyboardOpen ? 18 : 0,
                      30,
                      keyboardOpen ? keyboard + 24 : 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight -
                            (keyboardOpen ? keyboard * 0.45 : 0),
                      ),
                      child: Column(
                        mainAxisAlignment: keyboardOpen
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          // LOGO
                          Image.asset(
                            'assets/imagenes/logo_w.png',
                            width: keyboardOpen ? 150 : 250,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.local_taxi, size: 100),
                          ),
                          SizedBox(height: keyboardOpen ? 18 : 40),

                          // FORMULARIO VIDRIO
                          ContenedorVidrio(
                            ancho: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 40, horizontal: 20),
                            child: Column(
                              children: [
                                _campoTexto(
                                  controller: _phoneController,
                                  icono: Icons.phone_android,
                                  texto: "Celular",
                                  esNumero: true,
                                ),
                                const SizedBox(height: 20),
                                _campoTexto(
                                  controller: _passController,
                                  icono: Icons.lock,
                                  texto: "Contraseña",
                                  esPassword: true,
                                  ocultarTexto: _ocultarPassword,
                                  toggleVisibilidad: () => setState(() =>
                                      _ocultarPassword = !_ocultarPassword),
                                ),
                                const SizedBox(height: 30),

                                // BOTÓN INGRESAR
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _cargando ? null : _manejarLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ColoresApp.amarilloBoton,
                                      foregroundColor: ColoresApp.negro,
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                        side: const BorderSide(
                                            color: ColoresApp.negro, width: 1),
                                      ),
                                    ),
                                    child: _cargando
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                color: Colors.black,
                                                strokeWidth: 2))
                                        : const Text("INGRESAR",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // OLVIDÓ CONTRASEÑA
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const OlvidoContrasenaPantalla())),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text("¿Olvidaste tu contraseña?",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: ColoresApp.negro,
                                            decoration:
                                                TextDecoration.underline)),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // C. BOTÓN ATRÁS
            if (!_cargando)
              Positioned(
                top: 50,
                left: 20,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: ColoresApp.negro, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required IconData icono,
    required String texto,
    bool esPassword = false,
    bool esNumero = false,
    bool ocultarTexto = false,
    VoidCallback? toggleVisibilidad,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ColoresApp.negro.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: esPassword ? ocultarTexto : false,
        keyboardType: esNumero ? TextInputType.number : TextInputType.text,
        inputFormatters: esNumero
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ]
            : [],
        style: const TextStyle(
            color: ColoresApp.negro, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          prefixIcon: Icon(icono, color: ColoresApp.negro),
          hintText: texto,
          hintStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColoresApp.negro.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          suffixIcon: esPassword
              ? IconButton(
                  icon: Icon(
                      ocultarTexto ? Icons.visibility_off : Icons.visibility,
                      color: ColoresApp.negro),
                  onPressed: toggleVisibilidad)
              : null,
        ),
      ),
    );
  }
}
