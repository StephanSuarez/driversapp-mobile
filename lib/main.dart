// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/datos_temporales.dart';
import 'services/auth_service.dart';
import 'services/driver_location_service.dart';
import 'services/push_notification_service.dart';
import 'global/environment.dart';

import 'pantallas/bienvenida/bienvenida_pantalla.dart';
import 'pantallas/autenticacion/pantalla_espera_verificacion.dart';
import 'pantallas/inicio/home_pantalla.dart';
import 'pantallas/autenticacion/verificacion_otp_pantalla.dart';
import 'pantallas/autenticacion/fotos_perfil_pantalla.dart';
import 'pantallas/autenticacion/documentos_conductor_pantalla.dart';
import 'pantallas/autenticacion/fotos_vehiculo_pantalla.dart';
import 'pantallas/autenticacion/licencia_pantalla.dart';
import 'pantallas/autenticacion/tarjeta_propiedad_pantalla.dart';
import 'pantallas/autenticacion/tarjeton_pantalla.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carga las variables de entorno desde .env (registrado como asset).
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Info: no se pudo cargar .env, se usan valores por defecto: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  try {
    await Environment.cargarTokenLocal();
    await DatosTemporales.cargarFase1();
  } catch (e) {
    debugPrint("Info: Fallo al cargar caché local: $e");
  }

  runApp(const DriversAppApp());
  unawaited(PushNotificationService().initialize());
}

class DriversAppApp extends StatelessWidget {
  const DriversAppApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DriversApp Driver',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      builder: (context, child) {
        _precargarAssets(context);

        return Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/imagenes/fondo.jpg',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            if (child != null) child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: InternetConnectionBanner(),
            ),
          ],
        );
      },
      home: const EnrutadorInicial(),
    );
  }

  void _precargarAssets(BuildContext context) {
    precacheImage(const AssetImage('assets/imagenes/fondo.jpg'), context);
    precacheImage(const AssetImage('assets/imagenes/fondo_w.png'), context);
    precacheImage(const AssetImage('assets/imagenes/logo_w.png'), context);
    precacheImage(const AssetImage('assets/imagenes/logito.png'), context);
  }
}

class InternetConnectionBanner extends StatefulWidget {
  const InternetConnectionBanner({super.key});

  @override
  State<InternetConnectionBanner> createState() =>
      _InternetConnectionBannerState();
}

class _InternetConnectionBannerState extends State<InternetConnectionBanner>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _sinInternet = false;
  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificarConexion();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _verificarConexion(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarConexion();
    }
  }

  Future<void> _verificarConexion() async {
    if (_verificando) return;

    _verificando = true;
    final tieneInternet = await _tieneInternet();

    if (mounted && _sinInternet == tieneInternet) {
      setState(() => _sinInternet = !tieneInternet);
    }

    _verificando = false;
  }

  Future<bool> _tieneInternet() async {
    try {
      final resultado = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 3));
      return resultado.isNotEmpty && resultado.first.rawAddress.isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_sinInternet,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        offset: _sinInternet ? Offset.zero : const Offset(0, -1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: _sinInternet ? 1 : 0,
          child: Material(
            color: Colors.redAccent.shade700,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                alignment: Alignment.center,
                child: const Text(
                  'No hay conexión a internet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EnrutadorInicial extends StatefulWidget {
  const EnrutadorInicial({super.key});

  @override
  State<EnrutadorInicial> createState() => _EnrutadorInicialState();
}

class _EnrutadorInicialState extends State<EnrutadorInicial> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decidirRuta());
  }

  Future<void> _decidirRuta() async {
    final authService = AuthService();
    final ruta = await authService
        .determinarPantallaInicial()
        .timeout(const Duration(seconds: 8), onTimeout: () => 'foto_perfil');

    if (ruta == 'home') {
      await DriverLocationService().sincronizarEstado();
    }

    if (!mounted) return;

    Widget destino;

    switch (ruta) {
      case 'home':
        destino = const HomePantalla();
        break;
      case 'espera':
        destino = const PantallaEsperaVerificacion();
        break;
      case 'otp':
        destino = const VerificacionOtpPantalla();
        break;
      case 'foto_perfil':
        destino = const FotosPerfilPantalla();
        break;
      case 'documentos_conductor':
        destino = const DocumentosConductorPantalla();
        break;
      case 'foto_vehiculo':
        destino = const FotosVehiculoPantalla();
        break;
      case 'licencia':
        destino = const LicenciaPantalla();
        break;
      case 'propiedad':
        destino = const TarjetaPropiedadPantalla();
        break;
      case 'tarjeton':
        destino = const TarjetonPantalla();
        break;
      case 'login':
      default:
        destino = const BienvenidaPantalla();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destino,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFFFEB3B),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Cargando DriversApp...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
