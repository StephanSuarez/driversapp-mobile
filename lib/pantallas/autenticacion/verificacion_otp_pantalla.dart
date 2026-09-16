import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

// --- WIDGETS ---
import '../../widgets/contenedor_vidrio.dart';
import '../../widgets/boton_bordeado.dart';

// --- SERVICIOS ---
import '../../services/auth_service.dart';
import '../../services/datos_temporales.dart';

// --- PANTALLAS ---
import '../inicio/home_pantalla.dart';
import 'fotos_perfil_pantalla.dart';
import 'nueva_contrasena_pantalla.dart';
import '../bienvenida/bienvenida_pantalla.dart';

class VerificacionOtpPantalla extends StatefulWidget {
  final String? numeroCelular;
  final bool esRecuperacion;
  final bool esRegistro;

  const VerificacionOtpPantalla({
    super.key,
    this.numeroCelular,
    this.esRecuperacion = false,
    this.esRegistro = false,
  });

  @override
  State<VerificacionOtpPantalla> createState() =>
      _VerificacionOtpPantallaState();
}

class _VerificacionOtpPantallaState extends State<VerificacionOtpPantalla>
    with TickerProviderStateMixin {
  late final TextEditingController _codigoController;
  late final FocusNode _focusNode;

  bool _cargando = false;
  bool _codigoYaEnviado = false;
  String _numeroActual = "";

  Timer? _timer;
  static const int _tiempoEspera = 120;
  int _segundosRestantes = _tiempoEspera;
  bool _puedeReenviar = false;
  int _contadorReenvios = 0;

  late final AnimationController _latidoController;
  late final AnimationController _entradaController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  final AuthService _authService =
      AuthService(); // Instancia para el login automático

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController();
    _focusNode = FocusNode();
    _cargarNumeroInicial();
    _configurarAnimaciones();
  }

  void _configurarAnimaciones() {
    _latidoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entradaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entradaController, curve: Curves.easeOutQuart));

    _fadeAnimation =
        CurvedAnimation(parent: _entradaController, curve: Curves.easeIn);

    _entradaController.forward();
  }

  void _cargarNumeroInicial() {
    final numeroWidget = _normalizarNumeroLocal(widget.numeroCelular);
    final numeroDraft = _normalizarNumeroLocal(DatosTemporales.celular);

    _numeroActual = numeroWidget.isNotEmpty ? numeroWidget : numeroDraft;
    if (_numeroActual.isEmpty) {
      unawaited(_hidratarNumeroDesdeSesion());
    }
  }

  Future<void> _hidratarNumeroDesdeSesion() async {
    final numeroSesion =
        _normalizarNumeroLocal(await _authService.obtenerTelefonoSesion());
    if (numeroSesion.isEmpty || !mounted) return;

    setState(() => _numeroActual = numeroSesion);
  }

  String _normalizarNumeroLocal(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty || raw.toLowerCase() == 'null') return '';

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length <= 10) return digits;
    return digits.substring(digits.length - 10);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigoController.dispose();
    _focusNode.dispose();
    _latidoController.dispose();
    _entradaController.dispose();
    super.dispose();
  }

  Future<void> _manejarBotonAtrasFisico() async {
    final token = await _authService.obtenerToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      await _confirmarCerrarSesion();
      return;
    }

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BienvenidaPantalla()),
        (route) => false);
  }

  Future<void> _confirmarCerrarSesion() async {
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Cerrar sesión"),
          content: const Text(
            "Para salir de la verificación SMS debes cerrar la sesión actual.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Cerrar sesión"),
            ),
          ],
        );
      },
    );

    if (cerrar != true) return;

    await _authService.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const BienvenidaPantalla()),
      (route) => false,
    );
  }

  Future<void> _enviarCodigoMock() async {
    if (_cargando) return;
    if (_numeroActual.length != 10) {
      _mostrarNotificacion(
        "No encontramos el teléfono de esta sesión.",
        isError: true,
      );
      return;
    }

    setState(() => _cargando = true);
    FocusScope.of(context).unfocus();

    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      await DatosTemporales.guardarPasoActual('otp');

      setState(() {
        _cargando = false;
        _codigoYaEnviado = true;
        _startTimer();
        _entradaController.reset();
        _entradaController.forward();
      });

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _focusNode.requestFocus();
      });

      _mostrarNotificacion("Código de prueba: 123456", isSuccess: true);
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      _mostrarNotificacion("Error de conexión.", isError: true);
    }
  }

  Future<void> _reenviarCodigo() async {
    if (_contadorReenvios >= 2) {
      _mostrarAlertaGlass(
          titulo: "Límite alcanzado",
          mensaje: "Intenta más tarde.",
          icono: Icons.block_rounded,
          colorIcono: Colors.red);
      return;
    }
    setState(() => _cargando = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _contadorReenvios++;
      _startTimer();
    });
    _mostrarNotificacion("Nuevo código enviado.", isSuccess: true);
  }

  // --- AQUÍ SE SOLUCIONA EL RECHAZO DEL SERVIDOR ---
  Future<void> _verificarCodigoMock() async {
    final codigo = _codigoController.text.trim();
    if (codigo.length < 6) return;

    setState(() => _cargando = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Simulación de verificación (Reemplaza por tu API real)
      await Future.delayed(const Duration(seconds: 2));
      bool esValido = (codigo == "123456");

      if (!mounted) return;

      if (esValido) {
        // 2. LOGUEO AUTOMÁTICO TRAS REGISTRO
        // Esto guarda el token necesario para subir fotos después
        if (widget.esRegistro) {
          final telefonoLogin = DatosTemporales.celular.isNotEmpty
              ? DatosTemporales.celular
              : _numeroActual;
          final logueado = await _authService.login(
            telefonoLogin,
            DatosTemporales.password,
          );
          if (!logueado) {
            _mostrarNotificacion(
              "Código dummy aceptado. Continúa el registro.",
              isSuccess: true,
            );
          }
        }

        final token = await _authService.obtenerToken();
        if (widget.esRegistro && (token == null || token.isEmpty)) {
          await DatosTemporales.guardarPasoActual('otp');
        } else {
          await DatosTemporales.guardarPasoActual('foto_perfil');
        }

        Widget nextScreen = const HomePantalla();
        if (widget.esRecuperacion) nextScreen = const NuevaContrasenaPantalla();
        if (widget.esRegistro && token != null && token.isNotEmpty) {
          nextScreen = const FotosPerfilPantalla();
        }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => nextScreen),
            (route) => false);
      } else {
        setState(() => _cargando = false);
        _mostrarAlertaGlass(
            titulo: "Código Incorrecto",
            mensaje: "No coincide. Intenta de nuevo.",
            icono: Icons.lock_open_rounded,
            colorIcono: Colors.orange);
        _codigoController.clear();
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
      _mostrarNotificacion("Error al validar sesión.", isError: true);
    }
  }

  void _startTimer() {
    setState(() {
      _segundosRestantes = _tiempoEspera;
      _puedeReenviar = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_segundosRestantes == 0) {
        setState(() => _puedeReenviar = true);
        t.cancel();
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  // --- UI COMPONENTS ---

  void _mostrarDialogoEditar() {
    final controllerTemp = TextEditingController(text: _numeroActual);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(25, 25, 25, 40),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 25),
                    const Text("Corregir número",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(15)),
                      child: Row(children: [
                        const Text("🇨🇴 +57",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                controller: controllerTemp,
                                keyboardType: TextInputType.phone,
                                autofocus: true,
                                maxLength: 10,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 20),
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    counterText: ""))),
                      ]),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                            onPressed: () async {
                              if (controllerTemp.text.length == 10) {
                                setState(() {
                                  _numeroActual = controllerTemp.text;
                                  _codigoYaEnviado = false;
                                  _codigoController.clear();
                                });
                                DatosTemporales.celular = controllerTemp.text;
                                await DatosTemporales.guardarFase1();
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15))),
                            child: const Text("GUARDAR",
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
            ));
  }

  void _mostrarNotificacion(String texto,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    Color colorBg = const Color(0xE6000000);
    IconData icono = Icons.info_outline;
    if (isError) {
      colorBg = const Color(0xE6FF3B30);
      icono = Icons.warning_amber_rounded;
    }
    if (isSuccess) {
      colorBg = const Color(0xE634C759);
      icono = Icons.check_circle_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(20),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
                color: colorBg, borderRadius: BorderRadius.circular(50)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icono, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Flexible(
                  child: Text(texto,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontSize: 14))),
            ]),
          ),
        ),
      ),
    ));
  }

  void _mostrarAlertaGlass(
      {required String titulo,
      required String mensaje,
      required IconData icono,
      required Color colorIcono}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => Material(
        type: MaterialType.transparency,
        child: Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(25)),
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: colorIcono.withAlpha(25),
                          shape: BoxShape.circle),
                      child: Icon(icono, size: 42, color: colorIcono)),
                  const SizedBox(height: 20),
                  Text(titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                  const SizedBox(height: 10),
                  Text(mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.black54, height: 1.5)),
                  const SizedBox(height: 30),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15))),
                          child: const Text("Entendido"))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _manejarBotonAtrasFisico();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(
                  child: RepaintBoundary(
                      child: Image.asset('assets/imagenes/fondo.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.white)))),
              Positioned.fill(
                  child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(color: const Color(0x1A000000)))),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 5),
                            Hero(
                                tag: 'logo_app',
                                child: Image.asset('assets/imagenes/logo_w.png',
                                    width: 140)),
                            const SizedBox(height: 25),
                            ContenedorVidrio(
                              ancho: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 35),
                              child: AnimatedCrossFade(
                                duration: const Duration(milliseconds: 600),
                                crossFadeState: _codigoYaEnviado
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                firstChild: Column(children: [
                                  _buildIconoMensajeAura(),
                                  const SizedBox(height: 25),
                                  const Text("Verificación SMS",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  const Text(
                                      "Te enviaremos un código de seguridad.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.black54, fontSize: 15)),
                                  const SizedBox(height: 30),
                                  GestureDetector(
                                      onTap: _mostrarDialogoEditar,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 15),
                                          decoration: BoxDecoration(
                                              color: const Color(0x99FFFFFF),
                                              borderRadius:
                                                  BorderRadius.circular(15)),
                                          child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                    _numeroActual.isEmpty
                                                        ? "Cargando número..."
                                                        : "+57 $_numeroActual",
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 19)),
                                                const SizedBox(width: 10),
                                                const Icon(Icons.edit_rounded,
                                                    size: 18,
                                                    color: Color(0xFFFFD700))
                                              ]))),
                                  const SizedBox(height: 35),
                                  BotonBordeado(
                                      texto: "ENVIAR CÓDIGO",
                                      alPresionar: _enviarCodigoMock),
                                ]),
                                secondChild: Column(children: [
                                  const Text("Ingresa el código",
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 10),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: const Color(0x1A9E9E9E),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          "Enviado al +57 $_numeroActual",
                                          style: const TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13))),
                                  const SizedBox(height: 30),
                                  _buildPinputGlass(),
                                  const SizedBox(height: 30),
                                  _buildTimer(),
                                  const SizedBox(height: 35),
                                  BotonBordeado(
                                      texto: "VERIFICAR",
                                      alPresionar: _verificarCodigoMock),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                  top: 55,
                  left: 22,
                  child: CircleAvatar(
                      backgroundColor: const Color(0x99FFFFFF),
                      radius: 20,
                      child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.black, size: 20),
                          onPressed: _manejarBotonAtrasFisico))),
              if (_cargando)
                Positioned.fill(
                    child: Container(
                        color: const Color(0x66000000),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconoMensajeAura() {
    return AnimatedBuilder(
      animation: _latidoController,
      builder: (context, child) => Transform.scale(
          scale: 1.0 + (_latidoController.value * 0.05), child: child),
      child: Stack(alignment: Alignment.center, children: [
        Container(
            height: 90,
            width: 90,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0x33FFD700))),
        Container(
            height: 70,
            width: 70,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Colors.white),
            child: const Icon(Icons.mark_email_unread_rounded, size: 32)),
      ]),
    );
  }

  Widget _buildTimer() {
    if (_puedeReenviar) {
      return TextButton(
          onPressed: _reenviarCodigo,
          child: const Text("¿No recibiste el código? Reenviar",
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline)));
    }
    final minutes =
        (_segundosRestantes / 60).floor().toString().padLeft(2, '0');
    final seconds = (_segundosRestantes % 60).toString().padLeft(2, '0');
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0x149E9E9E),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  value: _segundosRestantes / _tiempoEspera,
                  strokeWidth: 2.5,
                  color: const Color(0xFFFFD700))),
          const SizedBox(width: 10),
          Text("$minutes:$seconds",
              style: const TextStyle(
                  color: Colors.black54, fontWeight: FontWeight.w700))
        ]));
  }

  Widget _buildPinputGlass() {
    final defaultPinTheme = PinTheme(
        width: 50,
        height: 60,
        textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
        decoration: BoxDecoration(
            color: const Color(0x80FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x1A000000))));
    return Pinput(
        length: 6,
        controller: _codigoController,
        focusNode: _focusNode,
        defaultPinTheme: defaultPinTheme,
        focusedPinTheme: defaultPinTheme.copyWith(
            decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: const Color(0xFFFFD700), width: 2))),
        onCompleted: (pin) => _verificarCodigoMock());
  }
}
