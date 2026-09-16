import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

// Mis servicios
import '../../services/datos_temporales.dart';
import 'fotos_perfil_pantalla.dart';
import 'licencia_pantalla.dart';
import 'widgets/restablecer_registro_boton.dart';

enum TipoFotoVehiculo { frontal, trasera, lateral }

class FotosVehiculoPantalla extends StatefulWidget {
  const FotosVehiculoPantalla({super.key});

  @override
  State<FotosVehiculoPantalla> createState() => _FotosVehiculoPantallaState();
}

class _FotosVehiculoPantallaState extends State<FotosVehiculoPantalla> {
  // Variables para las fotos
  File? _imagenFrontal;
  File? _imagenTrasera;
  File? _imagenLateral;

  // Bloqueo para evitar que el usuario toque botones mientras procesamos
  bool _procesando = false;

  final ImagePicker _picker = ImagePicker();
  late final ImageLabeler _imageLabeler;

  // Rutas de assets
  static const String _iconoTaxiPath = 'assets/imagenes/taxi_icono.png';
  static const String _fondoWPath = 'assets/imagenes/fondo_w.png';

  @override
  void initState() {
    super.initState();
    _configurarIA();
    _cargarDatosGuardados();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precargamos las imágenes en memoria para que la pantalla entre suave y sin parpadeos
    precacheImage(const AssetImage(_fondoWPath), context);
    precacheImage(const AssetImage(_iconoTaxiPath), context);
  }

  @override
  void dispose() {
    // Es clave cerrar el detector para no consumir memoria del celular innecesariamente
    _imageLabeler.close();
    super.dispose();
  }

  void _configurarIA() {
    // Usamos 0.5 de confianza para que la IA no sea ni muy estricta ni muy relajada
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    _imageLabeler = ImageLabeler(options: options);
  }

  Future<void> _cargarDatosGuardados() async {
    // Recuperamos lo que haya guardado el usuario por si se salió de la app
    await DatosTemporales.guardarPasoActual('foto_vehiculo');
    await DatosTemporales.cargarFase1();

    if (mounted) {
      setState(() {
        _imagenFrontal = DatosTemporales.fotoVehiculoFrontal;
        _imagenTrasera = DatosTemporales.fotoVehiculoTrasera;
        _imagenLateral = DatosTemporales.fotoVehiculoLateral;
      });
    }
  }

  // --- LÓGICA DE FOTOS ---
  Future<void> _tomarFoto(ImageSource origen, TipoFotoVehiculo tipo) async {
    if (_procesando) return;

    try {
      // Bajamos la calidad a 80 y tamaño a 1000px.
      // Esto hace que la IA funcione rápido y la app no se trabe.
      final XFile? pickedFile = await _picker.pickImage(
        source: origen,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 76,
        requestFullMetadata: false,
      );

      if (pickedFile == null) return;

      setState(() => _procesando = true);
      final archivo = File(pickedFile.path);

      // Procesamos la imagen en segundo plano con ML Kit
      final inputImage = InputImage.fromFile(archivo);
      final List<ImageLabel> etiquetas =
          await _imageLabeler.processImage(inputImage);

      if (!mounted) return;

      // Validamos si es un vehículo de verdad
      final esVehiculo = _validarSiEsCarro(etiquetas);

      if (!esVehiculo) {
        _mostrarAlerta(
            titulo: "Vehículo no detectado",
            mensaje:
                "Asegúrate de que el vehículo esté bien iluminado y centrado. Evita fotos borrosas.",
            icono: Icons.directions_car_filled_rounded,
            color: Colors.orange);
        setState(() => _procesando = false);
        return;
      }

      // Si todo OK, guardamos en la variable correspondiente
      setState(() {
        switch (tipo) {
          case TipoFotoVehiculo.frontal:
            _imagenFrontal = archivo;
            DatosTemporales.fotoVehiculoFrontal = archivo;
            break;
          case TipoFotoVehiculo.trasera:
            _imagenTrasera = archivo;
            DatosTemporales.fotoVehiculoTrasera = archivo;
            break;
          case TipoFotoVehiculo.lateral:
            _imagenLateral = archivo;
            DatosTemporales.fotoVehiculoLateral = archivo;
            break;
        }
        _procesando = false;
      });

      // Guardamos en disco sin bloquear la UI
      await DatosTemporales.guardarFase1();
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        _mostrarAlerta(
            titulo: "Error",
            mensaje: "No se pudo procesar la foto. Intenta de nuevo.",
            icono: Icons.error_outline,
            color: Colors.red);
      }
    }
  }

  bool _validarSiEsCarro(List<ImageLabel> labels) {
    // Lista de cosas que aceptamos como "Vehículo"
    const palabrasClave = [
      'Car',
      'Vehicle',
      'Automobile',
      'Transport',
      'Motor vehicle',
      'Taxi',
      'Van',
      'Truck',
      'Suv',
      'Sedan',
      'Bus',
      'Pickup truck',
      'Tire',
      'Wheel',
      'Rim',
      'Bumper',
      'Automotive exterior',
      'License plate',
      'Headlamp',
      'Grille',
      'Hood',
      'Door',
      'Window',
      'Glass',
      'Windshield',
      'Mirror'
    ];

    for (var etiqueta in labels) {
      if (palabrasClave.contains(etiqueta.label) ||
          etiqueta.label.contains('Car') ||
          etiqueta.label.contains('Vehicle') ||
          etiqueta.label.contains('Auto')) {
        return true;
      }
    }
    return false;
  }

  // --- NAVEGACIÓN ---
  void _irSiguientePaso() async {
    // Solo dejamos pasar si tiene las 3 fotos
    if (_imagenFrontal != null &&
        _imagenTrasera != null &&
        _imagenLateral != null) {
      if (_procesando) return;

      await DatosTemporales.guardarPasoActual('licencia');

      if (!mounted) return;

      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const LicenciaPantalla()));
    } else {
      _mostrarAlerta(
          titulo: "Faltan fotos",
          mensaje:
              "Es obligatorio subir las 3 fotos (Frontal, Trasera y Lateral) para continuar.",
          icono: Icons.add_a_photo_rounded,
          color: Colors.black);
    }
  }

  // --- UI Y ALERTAS ---

  // Alerta estilo vidrio optimizada (usamos Hex Codes para no calcular opacidad en cada frame)
  void _mostrarAlerta(
      {required String titulo,
      required String mensaje,
      required IconData icono,
      required Color color}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Cerrar",
      barrierColor: const Color(0x99000000), // Negro al 60%
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color:
                    const Color(0xF2FFFFFF), // Blanco casi sólido (Estilo iOS)
                borderRadius: BorderRadius.circular(25),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40000000), blurRadius: 25, spreadRadius: 5)
                ],
                border: Border.all(color: const Color(0x80FFFFFF), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: color.withAlpha(
                                25), // ~10% de opacidad del color del icono
                            shape: BoxShape.circle),
                        child: Icon(icono, size: 42, color: color)),
                    const SizedBox(height: 22),
                    Text(titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                            decoration: TextDecoration.none,
                            fontFamily: 'Segoe UI')),
                    const SizedBox(height: 12),
                    Text(mensaje,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
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
                                    borderRadius: BorderRadius.circular(16))),
                            child: const Text("Entendido",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)))),
                  ],
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

  // --- PANTALLA PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo estático (Usamos RepaintBoundary para que no se redibuje al hacer scroll)
          Positioned.fill(
            child: RepaintBoundary(
                child: Center(
                    child: Opacity(
                        opacity: 1.0,
                        child: Image.asset(_fondoWPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const SizedBox())))),
          ),

          // Contenido con scroll
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 35),

                  // Cabecera
                  Image.asset(_iconoTaxiPath,
                      height: 60,
                      errorBuilder: (_, __, ___) => const Icon(Icons.local_taxi,
                          size: 60, color: Colors.orange)),
                  const SizedBox(height: 5),

                  const Text('VEHÍCULO',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: Colors.black)),
                  const SizedBox(height: 8),
                  const Text(
                      'Sube las fotos del taxi en sus espacios correspondientes: Frontal, Lateral y Trasera.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.black54, fontSize: 13, height: 1.4)),

                  const SizedBox(height: 20),

                  // Fila superior de fotos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _cajaSelectorFoto(
                          'FRONTAL', _imagenFrontal, TipoFotoVehiculo.frontal),
                      _cajaSelectorFoto(
                          'TRASERA', _imagenTrasera, TipoFotoVehiculo.trasera),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Foto lateral abajo
                  _cajaSelectorFoto(
                      'LATERAL', _imagenLateral, TipoFotoVehiculo.lateral),

                  const SizedBox(height: 30),

                  // Botón Continuar
                  if (_procesando)
                    const CircularProgressIndicator(color: Colors.black)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _irSiguientePaso,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          shadowColor:
                              const Color(0x4D000000), // Sombra optimizada
                        ),
                        child: const Text('CONTINUAR',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.0)),
                      ),
                    ),

                  const SizedBox(height: 14),
                  const RestablecerRegistroBoton(
                    destino: FotosPerfilPantalla(),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),

          // Botón Atrás (Flotante)
          Positioned(
              top: 50,
              left: 20,
              child: CircleAvatar(
                  backgroundColor:
                      const Color(0x99FFFFFF), // Blanco transparente optimizado
                  radius: 20,
                  child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black, size: 20),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FotosPerfilPantalla()),
                        );
                      }))),
        ],
      ),
    );
  }

  // Componente para seleccionar la foto (Cuadrado gris)
  Widget _cajaSelectorFoto(String titulo, File? imagen, TipoFotoVehiculo tipo) {
    final bool fotoOK = (imagen != null);
    const Color colorVerdeApple = Color(0xFF34C759);

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE), // Gris claro
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: fotoOK ? colorVerdeApple : Colors.grey.shade400,
                    width: fotoOK ? 2 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imagen != null
                    ? Image.file(imagen, fit: BoxFit.cover)
                    : Center(
                        child: Text(titulo,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black45,
                                fontSize: 13))),
              ),
            ),

            // Chulo/Checkmark
            if (fotoOK)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: colorVerdeApple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ]),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              )
          ],
        ),

        const SizedBox(height: 8),

        // Botones de acción debajo de la foto
        _botonPequeno(
            'Subir foto', () => _tomarFoto(ImageSource.gallery, tipo)),
        const SizedBox(height: 4),
        _botonPequeno('Tomar foto', () => _tomarFoto(ImageSource.camera, tipo)),
      ],
    );
  }

  Widget _botonPequeno(String texto, VoidCallback onPressed) {
    return SizedBox(
      width: 120,
      height: 32,
      child: ElevatedButton(
        onPressed: _procesando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          side: const BorderSide(color: Colors.black, width: 1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: EdgeInsets.zero,
        ),
        child: Text(texto,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
