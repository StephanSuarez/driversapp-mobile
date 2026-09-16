import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// Servicios y utilidades
import '../../services/auth_service.dart';
import '../../services/datos_temporales.dart';
import 'widgets/restablecer_registro_boton.dart';

import '../bienvenida/bienvenida_pantalla.dart'; // Ruta correcta a la bienvenida
import 'documentos_conductor_pantalla.dart';

class FotosPerfilPantalla extends StatefulWidget {
  const FotosPerfilPantalla({super.key});

  @override
  State<FotosPerfilPantalla> createState() => _FotosPerfilPantallaState();
}

class _FotosPerfilPantallaState extends State<FotosPerfilPantalla> {
  File? _imageFile;
  bool _procesando = false; // Evita doble tap

  final ImagePicker _picker = ImagePicker();
  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _inicializarDetector();
    _cargarEstadoPrevio();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precargamos imágenes para que no haya pantallazo blanco
    precacheImage(const AssetImage('assets/imagenes/fondo_w.png'), context);
    precacheImage(const AssetImage('assets/imagenes/logito.png'), context);
  }

  @override
  void dispose() {
    // Importante cerrar el detector para no comer memoria nativa
    _faceDetector.close();
    super.dispose();
  }

  void _inicializarDetector() {
    // Configuración rápida, solo nos importa detectar si hay cara o no
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        minFaceSize: 0.15,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _cargarEstadoPrevio() async {
    await DatosTemporales.guardarPasoActual('foto_perfil');
    await DatosTemporales.cargarFase1();

    if (mounted && DatosTemporales.fotoPerfil != null) {
      setState(() => _imageFile = DatosTemporales.fotoPerfil);
    }
  }

  // --- LÓGICA DE VALIDACIÓN ---
  Future<void> _procesarImagen(ImageSource fuente) async {
    if (_procesando) return;

    try {
      // Calidad 85 y max 1000px para que el ML no tarde procesando 4K
      final XFile? pickedFile = await _picker.pickImage(
        source: fuente,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (pickedFile == null) return;

      setState(() => _procesando = true);

      final file = File(pickedFile.path);
      final inputImage = InputImage.fromFile(file);

      // Procesamos en background con ML Kit
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      // 1. Validar que haya alguien
      if (faces.isEmpty) {
        _mostrarError("Rostro no detectado", "Mejora la luz y mira de frente.",
            Icons.face_retouching_off_rounded, Colors.orange);
        return;
      }

      // 2. Validar que sea solo uno
      if (faces.length > 1) {
        _mostrarError("Demasiados rostros", "La foto debe ser solo tuya.",
            Icons.groups_rounded, Colors.redAccent);
        return;
      }

      // 3. Validar que no esté muy lejos
      if (faces.first.boundingBox.width < 120) {
        _mostrarError("Estás muy lejos", "Acércate un poco más.",
            Icons.zoom_in_rounded, Colors.blueAccent);
        return;
      }

      // Todo OK
      setState(() {
        _imageFile = file;
        _procesando = false;
        DatosTemporales.fotoPerfil = _imageFile;
      });

      await DatosTemporales.guardarFase1();
      _mostrarFeedbackExito();
    } catch (e) {
      if (mounted) {
        _mostrarError("Error al procesar", "Inténtalo de nuevo.",
            Icons.error_outline_rounded, Colors.red);
      }
    }
  }

  void _mostrarError(
      String titulo, String mensaje, IconData icono, Color color) {
    setState(() => _procesando = false);
    _mostrarModalVidrio(
        titulo: titulo, mensaje: mensaje, icono: icono, colorIcono: color);
  }

  void _continuar() async {
    if (_imageFile != null) {
      if (_procesando) return;

      await DatosTemporales.guardarPasoActual('documentos_conductor');

      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const DocumentosConductorPantalla()));
    } else {
      _mostrarModalVidrio(
          titulo: "Foto requerida",
          mensaje: "Sube una foto válida para continuar.",
          icono: Icons.camera_enhance_rounded,
          colorIcono: Colors.black);
    }
  }

  Future<void> _cerrarSesion() async {
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Cerrar sesion"),
          content: const Text(
            "Se cerrara tu sesion y volveras a la pantalla inicial.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Cerrar sesion"),
            ),
          ],
        );
      },
    );

    if (cerrar != true) return;

    await AuthService().logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BienvenidaPantalla()),
        (route) => false);
  }

  // --- UI COMPONENTS ---

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
                    colors: [Color(0xE600C853), Color(0xF21B5E20)], // Verde pro
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                    child: Text(
                      "Identidad Validada",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'Segoe UI'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      barrierColor:
          const Color(0x99000000), // 60% Negro (Hex directo es más rápido)
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
                  color: const Color(0xF0FFFFFF), // 94% Blanco
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
            backgroundColor: Colors.white),
        label: Text(text,
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
          // 1. Fondo Estático (RepaintBoundary evita render innecesario)
          Positioned.fill(
            child: RepaintBoundary(
              child: Center(
                child: Opacity(
                  opacity: 1.0,
                  child: Image.asset(
                    'assets/imagenes/fondo_w.png',
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width * 0.5,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
            ),
          ),

          // 2. Contenido
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30.0),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),

                          // Avatar
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFEEEEEE),
                                border:
                                    Border.all(color: Colors.yellow, width: 3)),
                            child: _imageFile != null
                                ? ClipOval(
                                    child: Image.file(_imageFile!,
                                        fit: BoxFit.cover))
                                : const Icon(Icons.person,
                                    size: 90, color: Color(0xFF78909C)),
                          ),

                          const SizedBox(height: 20),

                          const Text("FOTO DE PERFIL",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black,
                                  letterSpacing: 1.0)),

                          const Spacer(),

                          const Text(
                            "Sube o toma una foto de tu rostro.\n \n Nota: Asegúrate de que sea un primer plano nítido y bien iluminado.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 60),

                          // Botones
                          if (_procesando)
                            const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.black)))
                          else ...[
                            _botonBordeNegro("Galería", Icons.photo_library,
                                () => _procesarImagen(ImageSource.gallery)),
                            const SizedBox(height: 15),
                            _botonBordeNegro("Cámara", Icons.camera_alt,
                                () => _procesarImagen(ImageSource.camera)),
                          ],

                          // Continuar
                          if (_imageFile != null && !_procesando) ...[
                            const SizedBox(height: 25),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _continuar,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    elevation: 5,
                                    shadowColor: const Color(0x4D000000)),
                                child: const Text("Continuar",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],

                          const Spacer(),

                          Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 30, top: 20),
                              child: Image.asset('assets/imagenes/logito.png',
                                  height: 70,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox())),
                          const RestablecerRegistroBoton(
                            destino: FotosPerfilPantalla(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          // 3. Botón Atrás
          Positioned(
              top: 50,
              left: 20,
              child: CircleAvatar(
                  backgroundColor: const Color(0x99FFFFFF),
                  radius: 20,
                  child: IconButton(
                      icon: const Icon(Icons.logout_rounded,
                          color: Colors.black, size: 20),
                      onPressed: _cerrarSesion))),
        ],
      ),
    );
  }
}
