import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:driversapp/pantallas/bienvenida/bienvenida_pantalla.dart';

// --- WIDGETS ---
import '../../widgets/contenedor_vidrio.dart';
import '../../widgets/boton_bordeado.dart';

// --- SERVICIOS ---
import '../../services/datos_temporales.dart';
import '../../services/auth_service.dart';
import '../../services/session_navigation.dart';

// --- PANTALLAS ---
import 'login_pantalla.dart';
import 'verificacion_otp_pantalla.dart';
import 'fotos_perfil_pantalla.dart';
import 'documentos_conductor_pantalla.dart';
import 'fotos_vehiculo_pantalla.dart';
import 'licencia_pantalla.dart';
import 'tarjeta_propiedad_pantalla.dart';
import 'tarjeton_pantalla.dart';
import 'pantalla_espera_verificacion.dart';

class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});

  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final AuthService _authService = AuthService();

  // Inicialización tardía (late) para optimizar memoria durante el arranque de la vista
  late final TextEditingController _documentoController;
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _celularController;
  late final TextEditingController _passController;
  late final TextEditingController _confirmPassController;
  late final TextEditingController _celularPropietarioController;

  // Timer para controlar el guardado automático (Debounce)
  Timer? _debounce;

  // Estado del formulario
  String? _tipoDocumento;
  bool _esPropietario = true;
  bool _oscurecerPassword = true;
  bool _oscurecerConfirmPassword = true;
  bool _cargando = false;
  bool _mostrarBotonVolver = true;

  // Set para validación visual rápida (Búsqueda O(1))
  final Set<String> _camposConError = {};

  @override
  void initState() {
    super.initState();
    _inicializarControladores();
    _inicializarPantalla();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SessionNavigation.redirectIfAuthenticated(context);
    });
  }

  void _inicializarControladores() {
    _documentoController = TextEditingController();
    _nombreController = TextEditingController();
    _apellidosController = TextEditingController();
    _celularController = TextEditingController();
    _passController = TextEditingController();
    _confirmPassController = TextEditingController();
    _celularPropietarioController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-carga de assets pesados en la GPU para evitar caídas de frames (Jank)
    precacheImage(const AssetImage('assets/imagenes/fondo.jpg'), context);
    precacheImage(const AssetImage('assets/imagenes/logo_w.png'), context);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Persistencia de seguridad al destruir la vista, si no hay una transacción activa
    if (!_cargando) _guardarBorradorEnMemoria();

    // Limpieza estricta de controladores para evitar fugas de memoria
    _documentoController.dispose();
    _nombreController.dispose();
    _apellidosController.dispose();
    _celularController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _celularPropietarioController.dispose();
    super.dispose();
  }

  // Carga asíncrona y restauración de estado (State Restoration)
  Future<void> _inicializarPantalla() async {
    await Future.delayed(Duration.zero);
    await DatosTemporales.cargarFase1();

    if (!mounted) return;

    // Router de recuperación de flujo interrumpido
    String pasoGuardado = await DatosTemporales.obtenerPasoActual();
    if (pasoGuardado != 'inicio' && pasoGuardado != 'registro') {
      _redirigirAlPasoPendiente(pasoGuardado);
    } else {
      _restaurarDatosFormulario();
    }
  }

  void _redirigirAlPasoPendiente(String paso) {
    Widget? pantallaDestino;
    switch (paso) {
      case 'otp':
        pantallaDestino = VerificacionOtpPantalla(
            numeroCelular: DatosTemporales.celular, esRegistro: true);
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
      case 'espera':
        pantallaDestino = const PantallaEsperaVerificacion();
        break;
    }

    if (pantallaDestino != null) {
      setState(() => _cargando = true);
      // Usamos pushReplacement para mantener limpio el stack de navegación
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
              pageBuilder: (_, __, ___) => pantallaDestino!,
              transitionDuration: Duration.zero));
    } else {
      _restaurarDatosFormulario();
    }
  }

  void _restaurarDatosFormulario() {
    setState(() {
      _documentoController.text = DatosTemporales.documento;
      _nombreController.text = DatosTemporales.nombre;
      _apellidosController.text = DatosTemporales.apellidos;
      _celularController.text = DatosTemporales.celular;
      _passController.text = DatosTemporales.password;
      _celularPropietarioController.text = DatosTemporales.celularPropietario;
      if (DatosTemporales.tipoDocumento.isNotEmpty) {
        _tipoDocumento = DatosTemporales.tipoDocumento;
      }
      _esPropietario = DatosTemporales.esPropietario;
    });
  }

  void _guardarBorradorEnMemoria() {
    DatosTemporales.documento = _documentoController.text;
    DatosTemporales.nombre = _nombreController.text;
    DatosTemporales.apellidos = _apellidosController.text;
    DatosTemporales.celular = _celularController.text;
    DatosTemporales.password = _passController.text;
    DatosTemporales.celularPropietario = _celularPropietarioController.text;
    DatosTemporales.tipoDocumento = _tipoDocumento ?? "";
    DatosTemporales.esPropietario = _esPropietario;
    DatosTemporales.guardarFase1();
  }

  // Listener optimizado con debounce de 500ms para evitar escrituras excesivas
  void _onFieldChanged(String idCampo) {
    if (_camposConError.contains(idCampo)) {
      setState(() => _camposConError.remove(idCampo));
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 500), _guardarBorradorEnMemoria);
  }

  // --- LÓGICA CORE: PROCESAMIENTO ---
  Future<void> _procesarRegistro() async {
    FocusScope.of(context)
        .unfocus(); // Ocultar teclado para priorizar visibilidad de alertas

    if (_cargando) return;

    setState(() => _camposConError.clear());
    _guardarBorradorEnMemoria();

    final doc = _documentoController.text.trim();
    final nom = _nombreController.text.trim();
    final ape = _apellidosController.text.trim();
    final cel = _celularController.text.replaceAll(' ', '').trim();
    final pass = _passController.text.trim();
    final confirm = _confirmPassController.text.trim();

    // 1. Validaciones de integridad (Campos requeridos)
    bool hayError = false;
    if (_tipoDocumento == null) {
      _camposConError.add('tipo');
      hayError = true;
    }
    if (doc.isEmpty) {
      _camposConError.add('doc');
      hayError = true;
    }
    if (nom.isEmpty) {
      _camposConError.add('nom');
      hayError = true;
    }
    if (ape.isEmpty) {
      _camposConError.add('ape');
      hayError = true;
    }
    if (cel.isEmpty) {
      _camposConError.add('cel');
      hayError = true;
    }
    if (pass.isEmpty) {
      _camposConError.add('pass');
      hayError = true;
    }
    if (confirm.isEmpty) {
      _camposConError.add('confirm');
      hayError = true;
    }

    if (hayError) {
      _mostrarNotificacion(
          mensaje: "Completa todos los campos.", isError: true);
      return;
    }

    // 2. Validaciones de formato
    if (doc.length < 5) {
      _camposConError.add('doc');
      _mostrarNotificacion(
          mensaje: "Documento demasiado corto.", isError: true);
      return;
    }
    if (cel.length != 10) {
      _camposConError.add('cel');
      _mostrarNotificacion(
          mensaje: "El celular debe tener 10 dígitos.", isError: true);
      return;
    }
    if (pass.length < 6) {
      _camposConError.add('pass');
      _mostrarNotificacion(
          mensaje: "La contraseña es muy corta.", isError: true);
      return;
    }
    if (pass != confirm) {
      _camposConError.add('pass');
      _camposConError.add('confirm');
      _mostrarNotificacion(
          mensaje: "Las contraseñas no coinciden.", isError: true);
      return;
    }

    setState(() => _cargando = true);

    try {
      final String? errorRegistro = await _authService.registrarConductor(
        nombre: nom,
        apellidos: ape,
        celular: cel,
        password: pass,
        documento: doc,
        tipoDocumento: _tipoDocumento!,
        esPropietario: true,
      );

      if (!mounted) return;

      if (errorRegistro == null) {
        // Transacción exitosa: Commit del paso y navegación
        await DatosTemporales.guardarPasoActual('otp');
        if (!mounted) return;
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => VerificacionOtpPantalla(
                    numeroCelular: cel, esRegistro: true)));
      } else {
        _manejarErrorServidor(errorRegistro);
      }
    } catch (e) {
      _mostrarNotificacion(
          mensaje: "Verifique su conexión a internet.", isError: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // --- MANEJO DE RESPUESTAS DEL BACKEND ---
  void _manejarErrorServidor(String error) {
    final String errorMayus = error.toUpperCase();

    // 1. Conflicto: Celular ya registrado
    if (errorMayus.contains("PHONE") || errorMayus.contains("CELULAR")) {
      _camposConError.add('cel');
      _mostrarAlertaModal(
          titulo: "Número ya registrado",
          mensaje:
              "Este celular ya está registrado en nuestro sistema. Si la cuenta es tuya, por favor inicia sesión.",
          icono: Icons.phone_locked_rounded,
          colorIcono: Colors.orange,
          accion: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const LoginPantalla())),
          textoAccion: "Ir a Iniciar Sesión");
      return;
    }

    // 2. Conflicto: Documento ya registrado
    if (errorMayus.contains("ID_DOCUMENT") ||
        errorMayus.contains("DOCUMENT") ||
        errorMayus.contains("CEDULA")) {
      _camposConError.add('doc');
      _mostrarAlertaModal(
          titulo: "Documento ya registrado",
          mensaje:
              "Esta cédula ya está registrada en nuestro sistema. Si la cuenta es tuya, por favor inicia sesión.",
          icono: Icons.badge_outlined,
          colorIcono: Colors.orange,
          accion: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const LoginPantalla())),
          textoAccion: "Ir a Iniciar Sesión");
      return;
    }

    // 3. Fallos de Red / Infraestructura
    if (errorMayus.contains("NETWORK") ||
        errorMayus.contains("CONEXIÓN") ||
        errorMayus.contains("TIMEOUT") ||
        errorMayus.contains("SOCKET")) {
      _mostrarNotificacion(
          mensaje: "Verifique su conexión a internet.", isError: true);
    } else {
      // 4. Fallo técnico no controlado
      _mostrarNotificacion(mensaje: "Error técnico: $error", isError: true);
    }
  }

  // --- UI: NOTIFICACIÓN FLOTANTE (Toast) ---
  void _mostrarNotificacion({required String mensaje, bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
        content: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  // Uso de withValues para compatibilidad moderna con Flutter (Wide Gamut)
                  color: isError
                      ? const Color(0xFFFF3B30).withValues(alpha: 0.95)
                      : const Color(0xFF34C759).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        isError
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text(mensaje,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI: ALERTA MODAL (Glassmorphism) ---
  void _mostrarAlertaModal({
    required String titulo,
    required String mensaje,
    required IconData icono,
    required Color colorIcono,
    VoidCallback? accion,
    String? textoAccion,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        // Material wrap necesario para evitar problemas de renderizado de texto
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 25,
                        spreadRadius: 5)
                  ],
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorIcono.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, size: 42, color: colorIcono),
                      ),
                      const SizedBox(height: 20),
                      Text(titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              fontFamily: 'Segoe UI')),
                      const SizedBox(height: 10),
                      Text(mensaje,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Segoe UI')),
                      const SizedBox(height: 30),
                      if (accion != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              accion();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 5,
                              shadowColor: Colors.black.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(textoAccion ?? "Aceptar",
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black54,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                          ),
                          child: const Text("Cancelar",
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Entendido",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Capa 1: Fondo optimizado (RepaintBoundary)
            Positioned.fill(
                child: RepaintBoundary(
              child: Image.asset('assets/imagenes/fondo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.white)),
            )),
            // Capa 2: Formulario con Scroll
            Positioned.fill(
              child: SafeArea(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (scrollNotification) {
                    if (scrollNotification is ScrollUpdateNotification) {
                      final bool debeMostrar =
                          scrollNotification.metrics.pixels <= 50;
                      if (_mostrarBotonVolver != debeMostrar) {
                        setState(() => _mostrarBotonVolver = debeMostrar);
                      }
                    }
                    return true;
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 10,
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.02),
                        Image.asset('assets/imagenes/logo_w.png',
                            width: 95,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox(height: 80)),
                        const SizedBox(height: 10),
                        ContenedorVidrio(
                          ancho: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 20),
                          child: Column(
                            children: [
                              Row(children: [
                                SizedBox(
                                    width: 105, child: _dropdownDocumento()),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildTextField(_documentoController,
                                        null, "No. Documento", 'doc',
                                        isNumber: true)),
                              ]),
                              const SizedBox(height: 12),
                              _buildTextField(_nombreController, Icons.person,
                                  "Nombres", 'nom'),
                              const SizedBox(height: 12),
                              _buildTextField(_apellidosController,
                                  Icons.person_outline, "Apellidos", 'ape'),
                              const SizedBox(height: 12),
                              _buildTextField(_celularController,
                                  Icons.phone_android, "Celular", 'cel',
                                  isNumber: true),
                              const SizedBox(height: 12),
                              _buildTextField(_passController, Icons.lock,
                                  "Contraseña", 'pass',
                                  isPassword: true),
                              const SizedBox(height: 12),
                              _buildTextField(
                                  _confirmPassController,
                                  Icons.lock_outline,
                                  "Confirmar contraseña",
                                  'confirm',
                                  isPassword: true),
                              const SizedBox(height: 25),
                              _buildBotonAccion(),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const LoginPantalla()));
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                  child: const Text("Iniciar sesión aquí",
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          decoration: TextDecoration.underline,
                                          letterSpacing: 0.5)),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Capa 3: Botón Volver con redirección a bienvenida para evitar pantalla negra
            Positioned(
              top: 55,
              left: 22,
              child: AnimatedOpacity(
                opacity: _mostrarBotonVolver ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_mostrarBotonVolver,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.6),
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black, size: 20),
                      // Redirige a bienvenida explícitamente si el stack está vacío
                      onPressed: () async {
                        final redirigio =
                            await SessionNavigation.redirectIfAuthenticated(
                                context);
                        if (!context.mounted || redirigio) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BienvenidaPantalla(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Capa 4: Loader Global
            if (_cargando)
              Positioned.fill(
                  child: Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3)))),
          ],
        ),
      ),
    );
  }

  Widget _dropdownDocumento() {
    final bool tieneError = _camposConError.contains('tipo');
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: tieneError ? Colors.red : Colors.black,
              width: tieneError ? 2.0 : 1.0)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _tipoDocumento,
          dropdownColor: const Color(0xFFFFFDE7).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(20),
          hint: const Row(children: [
            Icon(Icons.badge_outlined, color: Colors.black, size: 18),
            SizedBox(width: 8),
            Text("Tipo",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.black54))
          ]),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
          items: const ["CC", "CE", "PAS"]
              .map((String value) => DropdownMenuItem(
                  value: value,
                  child: Row(children: [
                    const Icon(Icons.badge_outlined,
                        color: Colors.black, size: 18),
                    const SizedBox(width: 8),
                    Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.black))
                  ])))
              .toList(),
          onChanged: (valor) {
            setState(() {
              _tipoDocumento = valor;
              _camposConError.remove('tipo');
            });
            _guardarBorradorEnMemoria();
          },
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, IconData? icon,
      String hint, String fieldId,
      {bool isPassword = false, bool isNumber = false}) {
    final bool tieneError = _camposConError.contains(fieldId);
    final bool esConfirmacion = fieldId == 'confirm';
    final bool obscureText =
        esConfirmacion ? _oscurecerConfirmPassword : _oscurecerPassword;
    return Container(
      height: 50,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: tieneError ? Colors.red : Colors.black,
              width: tieneError ? 2.0 : 1.0)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)
              ]
            : [],
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
        onChanged: (_) => _onFieldChanged(fieldId),
        decoration: InputDecoration(
          prefixIcon: icon != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 15, right: 10),
                  child: Icon(icon, color: Colors.black, size: 20))
              : null,
          prefixIconConstraints: const BoxConstraints(minWidth: 45),
          hintText: hint,
          hintStyle: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black38, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          suffixIcon: isPassword
              ? IconButton(
                  padding: const EdgeInsets.only(right: 10),
                  icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black54,
                      size: 20),
                  onPressed: () => setState(() {
                    if (esConfirmacion) {
                      _oscurecerConfirmPassword = !_oscurecerConfirmPassword;
                    } else {
                      _oscurecerPassword = !_oscurecerPassword;
                    }
                  }),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildBotonAccion() {
    return BotonBordeado(texto: "SIGUIENTE", alPresionar: _procesarRegistro);
  }
}
