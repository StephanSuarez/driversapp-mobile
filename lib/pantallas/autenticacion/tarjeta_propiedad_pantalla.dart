import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/datos_temporales.dart';
import 'fotos_perfil_pantalla.dart';
import 'licencia_pantalla.dart';
import 'tarjeton_pantalla.dart';
import 'widgets/restablecer_registro_boton.dart';

// Pantalla para la captura y validacion OCR de la Tarjeta de Propiedad.
class TarjetaPropiedadPantalla extends StatefulWidget {
  const TarjetaPropiedadPantalla({super.key});

  @override
  State<TarjetaPropiedadPantalla> createState() =>
      _TarjetaPropiedadPantallaState();
}

class _TarjetaPropiedadPantallaState extends State<TarjetaPropiedadPantalla> {
  File? _imagenTarjeta;
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;

  // Manejo de estados: 0 = Pendiente, 1 = Validacion exitosa
  int _estadoValidacion = 0;

  final TextEditingController _placaController = TextEditingController();
  final _placaFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized =
        newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  });

  static const String _logoPath = 'assets/imagenes/logito.png';
  static const String _ejemploTarjetaPath =
      'assets/imagenes/tarjeta_propiedad.png';

  @override
  void initState() {
    super.initState();
    _marcarPasoCerrado();
    _cargarFotoExistente();
  }

  @override
  void dispose() {
    _placaController.dispose();
    super.dispose();
  }

  // Guardo el progreso localmente para mantener el flujo si la app se reinicia
  Future<void> _marcarPasoCerrado() async {
    await DatosTemporales.guardarPasoActual('propiedad');
  }

  // Restauro los datos en memoria si el usuario navega hacia atras
  void _cargarFotoExistente() async {
    await DatosTemporales.cargarFase1();
    if (DatosTemporales.fotoTarjetaPropiedad != null) {
      if (!mounted) return;
      setState(() {
        _imagenTarjeta = DatosTemporales.fotoTarjetaPropiedad;
        if (DatosTemporales.placa.isNotEmpty) {
          _placaController.text = DatosTemporales.placa;
        }
        _estadoValidacion = 1;
      });
    }
  }

  Color _obtenerColorBorde() {
    if (_imagenTarjeta == null) return Colors.yellow;
    if (_estadoValidacion == 1) return const Color(0xFF2E7D32);
    return Colors.yellow;
  }

  // Modal estandarizado con glassmorphism para alertas de usuario
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
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim1, child: child));
      },
    );
  }

  // Feedback visual no intrusivo para casos de exito
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
                      child: Text("Tarjeta Validada",
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

  // Logica principal de extraccion y validacion de texto con ML Kit
  Future<void> _procesarImagen(ImageSource source) async {
    String placaManual = _placaController.text.trim().toUpperCase();

    if (placaManual.isEmpty) {
      _mostrarModalVidrio(
          titulo: "Falta la Placa",
          mensaje:
              "Por favor digita la placa del vehículo antes de subir la foto para validarla.",
          icono: Icons.directions_car_filled,
          colorIcono: Colors.orange);
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
        requestFullMetadata: false,
      );

      if (pickedFile == null) return;

      setState(() {
        _procesando = true;
        _estadoValidacion = 0;
      });

      File file = File(pickedFile.path);
      final inputImage = InputImage.fromFile(file);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText =
            await textRecognizer.processImage(inputImage);

        if (!mounted) return;

        String texto = recognizedText.text.toUpperCase();
        String textoLimpio = texto.replaceAll(' ', '').replaceAll('-', '');
        String placaLimpia =
            placaManual.replaceAll(' ', '').replaceAll('-', '');

        // Evito que suban la licencia de conduccion por error
        if (texto.contains('CONDUCCION') || texto.contains('CONDUCCIÓN')) {
          _mostrarModalVidrio(
              titulo: "Documento Incorrecto",
              mensaje:
                  "Parece una Licencia de Conducción. Por favor sube la Tarjeta de Propiedad.",
              icono: Icons.credit_card_off_rounded,
              colorIcono: Colors.red);
          setState(() => _imagenTarjeta = null);
          return;
        }

        // Valido keywords clave del documento
        bool esValida = texto.contains('TRANSITO') ||
            texto.contains('TRÁNSITO') ||
            texto.contains('PROPIEDAD') ||
            texto.contains('VEHICULO') ||
            texto.contains('PLACA') ||
            texto.contains('LICENCIA DE TRÁNSITO');

        bool placaCoincide = textoLimpio.contains(placaLimpia);

        if (esValida && placaCoincide) {
          setState(() {
            _imagenTarjeta = file;
            DatosTemporales.fotoTarjetaPropiedad = file;
            DatosTemporales.placa = placaManual;
            _estadoValidacion = 1;
          });
          await DatosTemporales.guardarFase1();
          if (!mounted) return;
          _mostrarFeedbackExito();
        } else {
          String errorExtra = !esValida
              ? "No parece una Tarjeta de Propiedad válida."
              : "La placa en la foto no coincide con la ingresada ($placaManual).";

          _mostrarModalVidrio(
              titulo: "Validación Fallida",
              mensaje: errorExtra,
              icono: Icons.error_outline_rounded,
              colorIcono: Colors.red);
          setState(() => _imagenTarjeta = null);
        }
      } finally {
        textRecognizer.close();
        if (mounted) {
          setState(() => _procesando = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarModalVidrio(
            titulo: "Error",
            mensaje: "Ocurrió un error al procesar la imagen.",
            icono: Icons.error,
            colorIcono: Colors.red);
      }
    }
  }

  void _continuar() async {
    if (_placaController.text.trim().isEmpty) {
      _mostrarModalVidrio(
          titulo: "Falta la Placa",
          mensaje: "Por favor ingresa la placa del vehículo.",
          icono: Icons.warning_amber_rounded,
          colorIcono: Colors.orange);
      return;
    }

    if (_imagenTarjeta == null || _estadoValidacion == 0) {
      _mostrarModalVidrio(
          titulo: "Foto requerida",
          mensaje: "Por favor sube una foto válida de la Tarjeta de Propiedad.",
          icono: Icons.camera_alt_rounded,
          colorIcono: Colors.black);
      return;
    }

    DatosTemporales.fotoTarjetaPropiedad = _imagenTarjeta;
    DatosTemporales.placa = _placaController.text.trim().toUpperCase();
    await DatosTemporales.guardarFase1();
    await DatosTemporales.guardarPasoActual('tarjeton');

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TarjetonPantalla()),
    );
  }

  Widget _botonBordeNegro(String text, IconData icon, VoidCallback? onPressed) {
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
                                                const LicenciaPantalla()),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 15.0, left: 15.0),
                                child: Text("TARJETA DE PROPIEDAD",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                  color: Colors.black87),
                              children: [
                                const TextSpan(
                                    text:
                                        'Digita la placa y sube la foto frontal de tu Tarjeta de Propiedad.\n\n'),
                                // Mantengo el icono relleno adaptado a la paleta del estado pendiente
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Icon(
                                      CupertinoIcons
                                          .exclamationmark_triangle_fill,
                                      size: 19,
                                      color: colorBorde == Colors.yellow
                                          ? Colors.yellow
                                          : Colors.yellow,
                                    ),
                                  ),
                                ),
                                const TextSpan(
                                    text:
                                        ' Atención: Ambos datos deben coincidir.',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _placaController,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [_placaFormatter],
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'Placa del Vehículo',
                              hintText: 'Ej: SGW987',
                              prefixIcon: const Icon(
                                  Icons.directions_car_filled_outlined,
                                  color: Colors.black54),
                              counterText: "",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(
                                    color: Colors.black, width: 2),
                              ),
                            ),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 12),
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
                                  child: _imagenTarjeta != null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.file(_imagenTarjeta!,
                                              fit: BoxFit.cover))
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Image.asset(
                                            _ejemploTarjetaPath,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .directions_car_filled_outlined,
                                                      size: 70,
                                                      color: Color(0xFF78909C)),
                                                  SizedBox(height: 10),
                                                  Text("Tarjeta de Propiedad",
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
                                    _imagenTarjeta != null)
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
                                          color: Colors.green, size: 24),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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
                              onPressed: _procesando ? null : _continuar,
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
                          const SizedBox(height: 10),
                          Center(
                              child: Image.asset(_logoPath,
                                  height: 70,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox())),
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
          if (_procesando)
            Container(
                color: Colors.black54,
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
    );
  }
}
