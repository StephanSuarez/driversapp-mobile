import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/auth_service.dart';
import '../../services/datos_temporales.dart';
import 'fotos_perfil_pantalla.dart';
import 'pantalla_espera_verificacion.dart';
import 'tarjeta_propiedad_pantalla.dart';
import 'widgets/restablecer_registro_boton.dart';

class TarjetonPantalla extends StatefulWidget {
  const TarjetonPantalla({super.key});

  @override
  State<TarjetonPantalla> createState() => _TarjetonPantallaState();
}

class _TarjetonPantallaState extends State<TarjetonPantalla> {
  File? _imagenTarjeton;
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();
  bool _procesando = false;
  int _estadoValidacion = 0;

  static const String _logoPath = 'assets/imagenes/logito.png';
  static const String _ejemploTarjetonPath =
      'assets/imagenes/tarjeton_taxi.png';

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    await DatosTemporales.guardarPasoActual('tarjeton');
    await DatosTemporales.cargarFase1();

    if (DatosTemporales.fotoTarjeton != null && mounted) {
      setState(() {
        _imagenTarjeton = DatosTemporales.fotoTarjeton;
        _estadoValidacion = 1;
      });
    }
  }

  Color get _colorBorde {
    if (_imagenTarjeton == null) return Colors.yellow;
    return _estadoValidacion == 1 ? const Color(0xFF2E7D32) : Colors.yellow;
  }

  void _mostrarModalVidrio({
    required String titulo,
    required String mensaje,
    required IconData icono,
    required Color colorIcono,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Material(
          type: MaterialType.transparency,
          child: Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xF0FFFFFF),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 30,
                        spreadRadius: 5)
                  ],
                  border:
                      Border.all(color: const Color(0x80FFFFFF), width: 1.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: colorIcono.withAlpha(26),
                            shape: BoxShape.circle),
                        child: Icon(icono, size: 42, color: colorIcono),
                      ),
                      const SizedBox(height: 22),
                      Text(titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              fontFamily: 'Segoe UI')),
                      const SizedBox(height: 12),
                      Text(mensaje,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Segoe UI')),
                      const SizedBox(height: 32),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) => ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child)),
    );
  }

  void _mostrarFeedbackExito() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xE600C853), Color(0xF21B5E20)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0x33FFFFFF), width: 1),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x4D00C853),
                        blurRadius: 20,
                        offset: Offset(0, 8))
                  ]),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Flexible(
                      child: Text("Tarjetón Validado",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              fontFamily: 'Segoe UI'))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _procesarImagen(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1100,
        maxHeight: 1100,
        imageQuality: 76,
        requestFullMetadata: false,
      );

      if (pickedFile == null) return;

      setState(() {
        _procesando = true;
        _estadoValidacion = 0;
      });

      final file = File(pickedFile.path);
      final inputImage = InputImage.fromFile(file);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);
        if (!mounted) return;

        final textoLimpio = recognizedText.text
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');
        final placaEsperada = DatosTemporales.placa
            .toUpperCase()
            .replaceAll(RegExp(r'[^A-Z0-9]'), '');

        final esTarjeton = [
          'CONTROL',
          'TARJETA',
          'MOVILIDAD',
          'BOGOTA',
          'SECRETARIA',
          'DISTRITAL',
          'CONDUCTOR'
        ].any((kw) => textoLimpio.contains(kw));

        final placaCoincide =
            placaEsperada.isEmpty || textoLimpio.contains(placaEsperada);

        if (esTarjeton && placaCoincide) {
          setState(() {
            _imagenTarjeton = file;
            _estadoValidacion = 1;
          });
          DatosTemporales.fotoTarjeton = file;
          await DatosTemporales.guardarFase1();
          if (!mounted) return;
          _mostrarFeedbackExito();
        } else {
          final motivo = !esTarjeton
              ? "El documento no parece ser un Tarjetón de Control válido."
              : "La placa detectada no coincide con la registrada ($placaEsperada).";

          setState(() {
            _imagenTarjeton = null;
            _estadoValidacion = 0;
          });

          _mostrarModalVidrio(
              titulo: "Validación Fallida",
              mensaje: "$motivo\n\nPor favor sube una foto clara y válida.",
              icono: Icons.error_outline_rounded,
              colorIcono: Colors.red);
        }
      } finally {
        textRecognizer.close();
        if (mounted) setState(() => _procesando = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarModalVidrio(
            titulo: "Error",
            mensaje: "Ocurrió un problema al procesar la imagen.",
            icono: Icons.error,
            colorIcono: Colors.red);
      }
    }
  }

  Future<void> _finalizarRegistro() async {
    if (_imagenTarjeton == null || _estadoValidacion == 0) {
      _mostrarModalVidrio(
          titulo: "Foto Requerida",
          mensaje: "Es necesario subir una foto válida del Tarjetón.",
          icono: Icons.camera_alt_rounded,
          colorIcono: Colors.black);
      return;
    }

    setState(() => _procesando = true);

    try {
      DatosTemporales.fotoTarjeton = _imagenTarjeton;
      await DatosTemporales.cargarFase1();
      if (_imagenTarjeton != null) {
        DatosTemporales.fotoTarjeton = _imagenTarjeton;
      }
      await DatosTemporales.guardarFase1();

      final faltantes = _archivosFaltantes();
      if (faltantes.isNotEmpty) {
        _mostrarModalVidrio(
          titulo: "Faltan documentos",
          mensaje:
              "No encontramos estos archivos en el borrador:\n\n${faltantes.join('\n')}\n\nVuelve al paso correspondiente y sube la foto otra vez.",
          icono: Icons.folder_off_rounded,
          colorIcono: Colors.orange,
        );
        return;
      }

      final sesionOk = await _authService.asegurarSesionConductor(
        celular: DatosTemporales.celular,
        password: DatosTemporales.password,
      );
      if (!sesionOk) {
        _mostrarModalVidrio(
          titulo: "Sesión requerida",
          mensaje:
              "No pudimos recuperar tu sesión para guardar los documentos. Vuelve a iniciar sesión e intenta finalizar el registro otra vez.",
          icono: Icons.lock_outline_rounded,
          colorIcono: Colors.orange,
        );
        return;
      }

      final payload = <String, dynamic>{};
      if (DatosTemporales.placa.isNotEmpty) {
        payload["vehicle_plate"] = DatosTemporales.placa;
      }

      Future<void> adjuntarSiExiste(String key, File? file,
          {bool asList = false}) async {
        if (file == null || !file.existsSync()) {
          throw Exception("Archivo faltante para $key");
        }
        final url = await _authService.subirArchivo(file);
        if (url == null) {
          throw Exception("No se pudo subir $key");
        }
        payload[key] = asList ? [url] : url;
      }

      // SUBIDA DE ARCHIVOS CON Future.wait PARA MÁXIMA VELOCIDAD
      await Future.wait([
        adjuntarSiExiste("profile_photo", DatosTemporales.fotoPerfil),
        adjuntarSiExiste("driver_license", DatosTemporales.fotoLicencia,
            asList: true),
        adjuntarSiExiste("ownership_card", DatosTemporales.fotoTarjetaPropiedad,
            asList: true),
        adjuntarSiExiste("taxi_control_card", DatosTemporales.fotoTarjeton),
      ]);

      final urlsVehiculo = <String>[];
      final fotosDelVehiculo = [
        DatosTemporales.fotoVehiculoFrontal,
        DatosTemporales.fotoVehiculoTrasera,
        DatosTemporales.fotoVehiculoLateral
      ];

      for (final file in fotosDelVehiculo) {
        if (file == null || !file.existsSync()) {
          throw Exception("Archivo faltante para vehicle_images");
        }
        final url = await _authService.subirArchivo(file);
        if (url == null) {
          throw Exception("No se pudo subir una imagen del vehiculo");
        }
        urlsVehiculo.add(url);
      }
      payload["vehicle_images"] = urlsVehiculo;

      if (payload.isNotEmpty) {
        final error = await _authService.actualizarDatosConductorConMensaje(
          payload,
          celular: DatosTemporales.celular,
          password: DatosTemporales.password,
        );
        if (error == null) {
          await DatosTemporales.borrarBorrador();
          await DatosTemporales.guardarPasoActual('completado');
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) => const PantallaEsperaVerificacion()),
              (route) => false);
        } else {
          _mostrarModalVidrio(
              titulo: "Error",
              mensaje: "El servidor rechazó la actualización:\n\n$error",
              icono: Icons.cloud_off,
              colorIcono: Colors.red);
        }
      } else {
        _mostrarModalVidrio(
            titulo: "Atención",
            mensaje: "No se encontraron datos para procesar.",
            icono: Icons.warning,
            colorIcono: Colors.orange);
      }
    } catch (e) {
      _mostrarModalVidrio(
          titulo: "Error",
          mensaje: "Error de conexión con el servidor.",
          icono: Icons.wifi_off_rounded,
          colorIcono: Colors.red);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  List<String> _archivosFaltantes() {
    final archivos = <String, File?>{
      "Foto de perfil": DatosTemporales.fotoPerfil,
      "Foto frontal del vehiculo": DatosTemporales.fotoVehiculoFrontal,
      "Foto trasera del vehiculo": DatosTemporales.fotoVehiculoTrasera,
      "Foto lateral del vehiculo": DatosTemporales.fotoVehiculoLateral,
      "Licencia": DatosTemporales.fotoLicencia,
      "Tarjeta de propiedad": DatosTemporales.fotoTarjetaPropiedad,
      "Tarjeton": DatosTemporales.fotoTarjeton,
    };

    return archivos.entries
        .where((entry) => entry.value == null || !entry.value!.existsSync())
        .map((entry) => "- ${entry.key}")
        .toList();
  }

  Widget _buildBotonAccion(
      String texto, IconData icono, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icono, color: Colors.black),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        label: Text(texto,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25.0, vertical: 10.0),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: CircleAvatar(
                                  backgroundColor: const Color(0x99FFFFFF),
                                  radius: 20,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new,
                                        color: Colors.black, size: 18),
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const TarjetaPropiedadPantalla()),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 15.0, left: 15.0),
                                child: Text("TARJETA DE CONTROL",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          RichText(
                            textAlign: TextAlign.center,
                            text: const TextSpan(
                              style: TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: Colors.black87),
                              children: [
                                TextSpan(
                                    text:
                                        'Sube una foto del Tarjetón visible en el taxi.\n\n'),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 6.0),
                                    child: Icon(Icons.warning_amber_rounded,
                                        size: 20, color: Colors.amber),
                                  ),
                                ),
                                TextSpan(
                                    text:
                                        ' Verificaremos que la placa coincida.',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 25),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1.6,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _colorBorde, width: 3),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x1A000000),
                                            blurRadius: 15,
                                            offset: Offset(0, 5))
                                      ]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(17),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (_imagenTarjeton != null)
                                          Image.file(
                                            _imagenTarjeton!,
                                            fit: BoxFit.cover,
                                            alignment: Alignment.topCenter,
                                          )
                                        else
                                          Image.asset(
                                            _ejemploTarjetonPath,
                                            fit: BoxFit.fill,
                                            errorBuilder: (_, __, ___) =>
                                                const Center(
                                                    child: Icon(
                                                        Icons.assignment_ind,
                                                        size: 80,
                                                        color: Colors.grey)),
                                          ),
                                        if (_estadoValidacion == 1 &&
                                            _imagenTarjeton != null)
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black12,
                                                        blurRadius: 4)
                                                  ]),
                                              child: const Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 28),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_procesando)
                            const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                    color: Colors.black))
                          else ...[
                            _buildBotonAccion("Galería", Icons.photo_library,
                                () => _procesarImagen(ImageSource.gallery)),
                            const SizedBox(height: 15),
                            _buildBotonAccion("Cámara", Icons.camera_alt,
                                () => _procesarImagen(ImageSource.camera)),
                          ],
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed:
                                  _procesando ? null : _finalizarRegistro,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  shadowColor: const Color(0x40000000)),
                              child: const Text("FINALIZAR REGISTRO",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 25),
                          Center(
                              child: Image.asset(_logoPath,
                                  height: 70,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox())),
                          const RestablecerRegistroBoton(
                            destino: FotosPerfilPantalla(),
                          ),
                          const Spacer(),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_procesando)
            Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }
}
