import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- SERVICIOS PROPIOS ---
import '../../services/datos_temporales.dart';
import 'fotos_perfil_pantalla.dart';
import 'fotos_vehiculo_pantalla.dart';
import 'tarjeta_propiedad_pantalla.dart';
import 'widgets/restablecer_registro_boton.dart';

class LicenciaPantalla extends StatefulWidget {
  const LicenciaPantalla({super.key});

  @override
  State<LicenciaPantalla> createState() => _LicenciaPantallaState();
}

class _LicenciaPantallaState extends State<LicenciaPantalla> {
  File? _imageFile;
  bool _procesando = false;

  // 0: Pendiente (Borde Amarillo) | 1: Validado (Borde Verde)
  int _estadoValidacion = 0;

  final ImagePicker _picker = ImagePicker();
  late final TextRecognizer _textRecognizer;

  static const String _iconoLogito = 'assets/imagenes/logito.png';
  static const String _fondoWPath = 'assets/imagenes/fondo_w.png';
  static const String _imgReferencia = 'assets/imagenes/licencia_frontal.png';

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _restaurarSesionSegura();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(_fondoWPath), context);
    precacheImage(const AssetImage(_iconoLogito), context);
    precacheImage(const AssetImage(_imgReferencia), context);
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // --- PERSISTENCIA SEGURA ---
  Future<void> _restaurarSesionSegura() async {
    final prefs = await SharedPreferences.getInstance();
    await DatosTemporales.guardarPasoActual('licencia');
    await DatosTemporales.cargarFase1();

    final String? pathGuardado = prefs.getString('path_licencia_seguro');
    final bool validado = prefs.getBool('licencia_validada') ?? false;

    if (pathGuardado != null && await File(pathGuardado).exists()) {
      final archivoGuardado = File(pathGuardado);
      DatosTemporales.fotoLicencia = archivoGuardado;
      await DatosTemporales.guardarFase1();
      if (mounted) {
        setState(() {
          _imageFile = DatosTemporales.fotoLicencia ?? archivoGuardado;
          _estadoValidacion = validado ? 1 : 0;
        });
      }
    } else if (mounted && DatosTemporales.fotoLicencia != null) {
      setState(() {
        _imageFile = DatosTemporales.fotoLicencia;
        _estadoValidacion = 1;
      });
    }
  }

  Color _obtenerColorBorde() {
    if (_imageFile == null) return Colors.yellow;
    if (_estadoValidacion == 1) return const Color(0xFF2E7D32);
    return Colors.yellow;
  }

  void _mostrarModalVidrio(
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
                            color: colorIcono.withValues(alpha: 0.1),
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
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim1, child: child));
      },
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
                      child: Text("Licencia Validada",
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

  Future<void> _procesarImagen(ImageSource fuente) async {
    if (_procesando) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: fuente,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 76,
        requestFullMetadata: false,
      );

      if (pickedFile == null) return;

      setState(() {
        _procesando = true;
        _estadoValidacion = 0;
      });

      final File archivo = File(pickedFile.path);
      final inputImage = InputImage.fromFile(archivo);
      final RecognizedText textoReconocido =
          await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      final String texto = textoReconocido.text.toUpperCase();
      final String textoLimpio = texto.replaceAll('.', '').replaceAll(' ', '');

      // ✅ EXTRACCIÓN SEGURA DESDE LA BASE DE DATOS LOCAL
      final prefs = await SharedPreferences.getInstance();
      final String documentoUsuario = prefs.getString('documento_usuario') ??
          DatosTemporales.documento.trim();

      final bool esLicencia = _validarLicencia(texto);
      final bool cedulaCoincide =
          documentoUsuario.isNotEmpty && textoLimpio.contains(documentoUsuario);

      if (esLicencia && cedulaCoincide) {
        setState(() {
          _imageFile = archivo;
          DatosTemporales.fotoLicencia = archivo;
          _procesando = false;
          _estadoValidacion = 1;
        });

        await DatosTemporales.guardarFase1();
        await prefs.setString('path_licencia_seguro',
            DatosTemporales.fotoLicencia?.path ?? archivo.path);
        await prefs.setBool('licencia_validada', true);

        _mostrarFeedbackExito();
      } else {
        setState(() {
          _imageFile = null;
          DatosTemporales.fotoLicencia = null;
          _procesando = false;
          _estadoValidacion = 0;
        });

        String errorMsg = "No pudimos validar el documento.";
        IconData iconoError = Icons.error_outline_rounded;

        if (!esLicencia) {
          errorMsg =
              "La imagen no parece ser una Licencia de Conducción válida.";
          iconoError = Icons.credit_card_off_rounded;
        } else if (!cedulaCoincide) {
          errorMsg =
              "El número de documento no coincide con tu cédula registrada ($documentoUsuario).";
          iconoError = Icons.person_off_rounded;
        }

        _mostrarModalVidrio(
            titulo: "Documento Inválido",
            mensaje: errorMsg,
            icono: iconoError,
            colorIcono: Colors.red);
      }
    } catch (e) {
      setState(() => _procesando = false);
      _mostrarModalVidrio(
          titulo: "Error Técnico",
          mensaje:
              "No pudimos procesar la imagen. Verifica los permisos e inténtalo de nuevo.",
          icono: Icons.cloud_off_rounded,
          colorIcono: Colors.red);
    }
  }

  bool _validarLicencia(String texto) {
    bool t1 = texto.contains('LICENCIA') &&
        (texto.contains('CONDUCCIÓN') || texto.contains('CONDUCCION'));
    bool t2 = texto.contains('REPÚBLICA') || texto.contains('COLOMBIA');
    bool t3 = texto.contains('CATEGORÍA') || texto.contains('FECHA');
    return t1 || (t2 && t3);
  }

  void _continuar() async {
    if (_imageFile != null && _estadoValidacion == 1) {
      if (_procesando) return;
      DatosTemporales.fotoLicencia = _imageFile;
      await DatosTemporales.guardarFase1();
      await DatosTemporales.guardarPasoActual('propiedad');
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const TarjetaPropiedadPantalla()));
    } else {
      _mostrarModalVidrio(
          titulo: "Foto requerida",
          mensaje: "Debes subir una licencia válida para continuar.",
          icono: Icons.camera_enhance_rounded,
          colorIcono: Colors.black);
    }
  }

  Widget _botonBordeNegro(String text, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        label: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color colorBorde = _obtenerColorBorde();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Center(
                child: Opacity(
                  opacity: 0.06,
                  child: Image.asset(_fondoWPath,
                      fit: BoxFit.contain,
                      width: MediaQuery.of(context).size.width * 0.6,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25.0, vertical: 10),
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
                                                const FotosVehiculoPantalla()),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 15.0),
                                child: const Text("LICENCIA",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                        color: Colors.black,
                                        letterSpacing: 1.0)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              children: [
                                const Text(
                                    "Por favor, sube una foto del lado frontal de tu Licencia de Conducción.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4)),
                                const SizedBox(height: 8),
                                const Text(
                                    "La imagen debe ser clara y completamente legible.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),
                          AspectRatio(
                            aspectRatio: 1.58,
                            child: Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFEEEEEE),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: colorBorde, width: 3),
                                      boxShadow: const [
                                        BoxShadow(
                                            color: Color(0x1A000000),
                                            blurRadius: 15,
                                            offset: Offset(0, 5))
                                      ]),
                                  child: _imageFile != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.file(_imageFile!,
                                              fit: BoxFit.cover))
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.asset(
                                            _imgReferencia,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: const [
                                                  Icon(Icons.badge_outlined,
                                                      size: 70,
                                                      color: Color(0xFF78909C)),
                                                  SizedBox(height: 10),
                                                  Text("Frente de la Licencia",
                                                      style: TextStyle(
                                                          color:
                                                              Color(0xFF78909C),
                                                          fontWeight:
                                                              FontWeight.bold))
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                ),
                                if (_estadoValidacion == 1 &&
                                    _imageFile != null)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4)
                                          ]),
                                      child: const Icon(Icons.check_circle,
                                          color: Color(0xFF2E7D32), size: 24),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_procesando)
                            const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                    color: Colors.black))
                          else ...[
                            _botonBordeNegro("Galería", Icons.photo_library,
                                () => _procesarImagen(ImageSource.gallery)),
                            const SizedBox(height: 15),
                            _botonBordeNegro("Cámara", Icons.camera_alt,
                                () => _procesarImagen(ImageSource.camera)),
                          ],
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _continuar,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                  elevation: 5,
                                  shadowColor: const Color(0x40000000)),
                              child: const Text("Continuar",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Image.asset(_iconoLogito,
                              height: 70,
                              errorBuilder: (_, __, ___) => const SizedBox()),
                          const RestablecerRegistroBoton(
                            destino: FotosPerfilPantalla(),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
