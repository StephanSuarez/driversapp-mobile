import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/datos_temporales.dart';
import '../../widgets/app_top_toast.dart';
import 'pantalla_espera_verificacion.dart';
import 'widgets/restablecer_registro_boton.dart';

enum _DocumentoConductor {
  cedulaFrente,
  cedulaReverso,
  licenciaFrente,
  licenciaReverso,
}

class DocumentosConductorPantalla extends StatefulWidget {
  final bool abrirPrimerPendiente;

  const DocumentosConductorPantalla({
    super.key,
    this.abrirPrimerPendiente = true,
  });

  @override
  State<DocumentosConductorPantalla> createState() =>
      _DocumentosConductorPantallaState();
}

class _DocumentosConductorPantallaState
    extends State<DocumentosConductorPantalla> {
  final AuthService _authService = AuthService();
  bool _guardando = false;
  bool _autoAbierto = false;

  File? _cedulaFrente;
  File? _cedulaReverso;
  File? _licenciaFrente;
  File? _licenciaReverso;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    await DatosTemporales.guardarPasoActual('documentos_conductor');
    await DatosTemporales.cargarFase1();
    if (!mounted) return;
    setState(_sincronizarEstado);

    if (widget.abrirPrimerPendiente && !_autoAbierto) {
      _autoAbierto = true;
      final pendiente = _primerPendiente();
      if (pendiente != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _abrirDocumento(pendiente);
        });
      }
    }
  }

  void _sincronizarEstado() {
    _cedulaFrente = DatosTemporales.fotoCedulaFrente;
    _cedulaReverso = DatosTemporales.fotoCedulaReverso;
    _licenciaFrente = DatosTemporales.fotoLicencia;
    _licenciaReverso = DatosTemporales.fotoLicenciaReverso;
  }

  Future<void> _recargarResumen() async {
    await DatosTemporales.cargarFase1();
    if (!mounted) return;
    setState(_sincronizarEstado);
  }

  _DocumentoConductor? _primerPendiente() {
    if (_cedulaFrente == null) return _DocumentoConductor.cedulaFrente;
    if (_cedulaReverso == null) return _DocumentoConductor.cedulaReverso;
    if (_licenciaFrente == null) return _DocumentoConductor.licenciaFrente;
    if (_licenciaReverso == null) return _DocumentoConductor.licenciaReverso;
    return null;
  }

  Future<void> _abrirDocumento(_DocumentoConductor tipo) async {
    final actualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _CapturaDocumentoConductorPantalla(
          tipo: tipo,
          onDocumentoGuardado: _recargarResumen,
        ),
      ),
    );
    await _recargarResumen();
    if (!mounted) return;
    if (actualizado == true) {
      AppTopToast.show(
        context,
        message: 'Documento guardado.',
        type: AppToastType.success,
      );
    }
  }

  bool get _completo =>
      DatosTemporales.fotoPerfil != null &&
      _cedulaFrente != null &&
      _cedulaReverso != null &&
      _licenciaFrente != null &&
      _licenciaReverso != null;

  Future<String> _subirObligatorio(File file, String nombre) async {
    final url = await _authService.subirArchivo(file);
    if (url == null || url.isEmpty) {
      throw Exception('No se pudo subir $nombre.');
    }
    return url;
  }

  Future<void> _finalizar() async {
    if (!_completo || _guardando) {
      AppTopToast.show(
        context,
        message: 'Completa las cuatro fotos de documentos para continuar.',
        type: AppToastType.error,
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final profilePhoto = await _subirObligatorio(
          DatosTemporales.fotoPerfil!, 'la foto de perfil');
      final cedulaFrente =
          await _subirObligatorio(_cedulaFrente!, 'la cédula frontal');
      final cedulaReverso =
          await _subirObligatorio(_cedulaReverso!, 'la cédula posterior');
      final licenciaFrente =
          await _subirObligatorio(_licenciaFrente!, 'la licencia frontal');
      final licenciaReverso =
          await _subirObligatorio(_licenciaReverso!, 'la licencia posterior');

      final error = await _authService.actualizarDatosConductorConMensaje({
        'profile_photo': profilePhoto,
        'id_card_images': [cedulaFrente, cedulaReverso],
        'driver_license': [licenciaFrente, licenciaReverso],
      });

      if (!mounted) return;
      if (error != null) {
        setState(() => _guardando = false);
        AppTopToast.show(context, message: error, type: AppToastType.error);
        return;
      }

      await DatosTemporales.borrarBorrador();
      await DatosTemporales.guardarPasoActual('espera');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaEsperaVerificacion()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      AppTopToast.show(
        context,
        message: e.toString().replaceFirst('Exception: ', ''),
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD600),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.badge_rounded, color: Colors.black),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documentos del conductor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Resumen de avance. Toca un documento para editarlo.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                children: [
                  _DocumentoTile(
                    titulo: 'Cédula frontal',
                    subtitulo: 'Cara principal del documento',
                    file: _cedulaFrente,
                    onTap: () =>
                        _abrirDocumento(_DocumentoConductor.cedulaFrente),
                  ),
                  _DocumentoTile(
                    titulo: 'Cédula posterior',
                    subtitulo: 'Reverso del documento',
                    file: _cedulaReverso,
                    onTap: () =>
                        _abrirDocumento(_DocumentoConductor.cedulaReverso),
                  ),
                  _DocumentoTile(
                    titulo: 'Licencia frontal',
                    subtitulo: 'Cara principal de la licencia',
                    file: _licenciaFrente,
                    onTap: () =>
                        _abrirDocumento(_DocumentoConductor.licenciaFrente),
                  ),
                  _DocumentoTile(
                    titulo: 'Licencia posterior',
                    subtitulo: 'Reverso de la licencia',
                    file: _licenciaReverso,
                    onTap: () =>
                        _abrirDocumento(_DocumentoConductor.licenciaReverso),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _finalizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _guardando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Enviar a revisión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const RestablecerRegistroBoton(
                    destino: DocumentosConductorPantalla(
                      abrirPrimerPendiente: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapturaDocumentoConductorPantalla extends StatefulWidget {
  final _DocumentoConductor tipo;
  final Future<void> Function()? onDocumentoGuardado;

  const _CapturaDocumentoConductorPantalla({
    required this.tipo,
    this.onDocumentoGuardado,
  });

  @override
  State<_CapturaDocumentoConductorPantalla> createState() =>
      _CapturaDocumentoConductorPantallaState();
}

class _CapturaDocumentoConductorPantallaState
    extends State<_CapturaDocumentoConductorPantalla> {
  final ImagePicker _picker = ImagePicker();
  late final TextRecognizer _textRecognizer;
  late _DocumentoConductor _tipo;
  File? _file;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _tipo = widget.tipo;
    _file = _fileActual(_tipo);
    _recuperarImagenPerdida();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/imagenes/fondo_w.png'), context);
    precacheImage(const AssetImage('assets/imagenes/logito.png'), context);
  }

  File? _fileActual(_DocumentoConductor tipo) {
    return switch (tipo) {
      _DocumentoConductor.cedulaFrente => DatosTemporales.fotoCedulaFrente,
      _DocumentoConductor.cedulaReverso => DatosTemporales.fotoCedulaReverso,
      _DocumentoConductor.licenciaFrente => DatosTemporales.fotoLicencia,
      _DocumentoConductor.licenciaReverso =>
        DatosTemporales.fotoLicenciaReverso,
    };
  }

  void _guardarEnTemporal(File file) {
    switch (_tipo) {
      case _DocumentoConductor.cedulaFrente:
        DatosTemporales.fotoCedulaFrente = file;
        break;
      case _DocumentoConductor.cedulaReverso:
        DatosTemporales.fotoCedulaReverso = file;
        break;
      case _DocumentoConductor.licenciaFrente:
        DatosTemporales.fotoLicencia = file;
        break;
      case _DocumentoConductor.licenciaReverso:
        DatosTemporales.fotoLicenciaReverso = file;
        break;
    }
  }

  Future<void> _seleccionar(ImageSource source) async {
    if (_procesando) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1100,
        maxHeight: 1100,
        imageQuality: 76,
        requestFullMetadata: false,
      );
      if (picked == null) return;

      await _procesarArchivo(File(picked.path));
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      _mostrarModalVidrio(
        titulo: 'Error técnico',
        mensaje: 'No pudimos procesar la imagen. Inténtalo nuevamente.',
        icono: Icons.cloud_off_rounded,
        colorIcono: Colors.red,
      );
    }
  }

  Future<void> _recuperarImagenPerdida() async {
    try {
      final response = await _picker.retrieveLostData();
      final picked = response.file;
      if (response.isEmpty || picked == null) return;
      await _procesarArchivo(File(picked.path));
    } catch (_) {
      // Si Android no tiene nada pendiente, continuamos normal.
    }
  }

  Future<void> _procesarArchivo(File archivo) async {
    setState(() => _procesando = true);

    final validacion = await _validarImagenDocumento(archivo, _tipo);
    if (!mounted) return;

    if (!validacion.esValido) {
      setState(() => _procesando = false);
      _mostrarModalVidrio(
        titulo: validacion.titulo,
        mensaje: validacion.mensaje,
        icono: validacion.icono,
        colorIcono: validacion.color,
      );
      return;
    }

    setState(() => _file = archivo);
    _guardarEnTemporal(archivo);
    await DatosTemporales.guardarFase1();
    await widget.onDocumentoGuardado?.call();
    if (!mounted) return;
    setState(() {
      _file = _fileActual(_tipo) ?? _file;
      _procesando = false;
    });
    AppTopToast.show(
      context,
      message: 'Documento validado.',
      type: AppToastType.success,
    );
  }

  Future<_ValidacionDocumento> _validarImagenDocumento(
    File archivo,
    _DocumentoConductor tipo,
  ) async {
    final inputImage = InputImage.fromFile(archivo);
    final reconocido = await _textRecognizer.processImage(inputImage);
    final texto = reconocido.text.toUpperCase();
    final textoLimpio = _normalizarTexto(texto);
    final documentoUsuario = _normalizarTexto(DatosTemporales.documento);

    if (textoLimpio.length < 18) {
      return _ValidacionDocumento.invalido(
        titulo: 'Documento no legible',
        mensaje:
            'No pudimos leer texto suficiente. Toma la foto de frente, con buena luz y sin reflejos.',
        icono: Icons.visibility_off_rounded,
        color: Colors.orange,
      );
    }

    final esCedula = _pareceCedula(textoLimpio);
    final esLicencia = _pareceLicencia(textoLimpio);
    final coincideDocumento = documentoUsuario.isEmpty ||
        textoLimpio.contains(documentoUsuario) ||
        textoLimpio.contains(documentoUsuario.replaceAll(RegExp(r'^0+'), ''));

    if (_esTipoCedula(tipo)) {
      if (esLicencia && !esCedula) {
        return _ValidacionDocumento.invalido(
          titulo: 'Documento incorrecto',
          mensaje:
              'Parece una licencia. Aquí debes cargar la cédula de ciudadanía.',
          icono: Icons.credit_card_off_rounded,
          color: Colors.red,
        );
      }

      if (!esCedula && !coincideDocumento) {
        return _ValidacionDocumento.invalido(
          titulo: 'Cédula no detectada',
          mensaje:
              'La imagen no parece ser una cédula válida. Revisa que el documento ocupe la foto completa.',
          icono: Icons.badge_outlined,
          color: Colors.red,
        );
      }
    } else {
      if (esCedula && !esLicencia) {
        return _ValidacionDocumento.invalido(
          titulo: 'Documento incorrecto',
          mensaje:
              'Parece una cédula. Aquí debes cargar la licencia de conducción.',
          icono: Icons.badge_outlined,
          color: Colors.red,
        );
      }

      if (!esLicencia) {
        return _ValidacionDocumento.invalido(
          titulo: 'Licencia no detectada',
          mensaje: 'La imagen no parece ser una licencia de conducción válida.',
          icono: Icons.credit_card_off_rounded,
          color: Colors.red,
        );
      }
    }

    if (documentoUsuario.isNotEmpty &&
        (_esFrontal(tipo) || textoLimpio.contains(RegExp(r'\d{6,}'))) &&
        !coincideDocumento) {
      return _ValidacionDocumento.invalido(
        titulo: 'Documento no coincide',
        mensaje:
            'El número del documento no coincide con el registrado (${DatosTemporales.documento}).',
        icono: Icons.person_off_rounded,
        color: Colors.red,
      );
    }

    return const _ValidacionDocumento.valido();
  }

  bool _esTipoCedula(_DocumentoConductor tipo) {
    return tipo == _DocumentoConductor.cedulaFrente ||
        tipo == _DocumentoConductor.cedulaReverso;
  }

  bool _esFrontal(_DocumentoConductor tipo) {
    return tipo == _DocumentoConductor.cedulaFrente ||
        tipo == _DocumentoConductor.licenciaFrente;
  }

  String _normalizarTexto(String texto) {
    return texto
        .toUpperCase()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  bool _pareceCedula(String texto) {
    final senales = [
      'CEDULA',
      'CIUDADANIA',
      'IDENTIFICACION',
      'REPUBLICADECOLOMBIA',
      'REGISTRADOR',
      'NUIP',
      'DOCUMENTODEIDENTIDAD',
    ];
    return senales.any(texto.contains);
  }

  bool _pareceLicencia(String texto) {
    final senales = [
      'LICENCIA',
      'CONDUCCION',
      'CONDUCCION',
      'TRANSITO',
      'CATEGORIA',
      'MINISTERIO',
      'ORGANISMODETRANSITO',
      'SERVICIO',
    ];
    return texto.contains('LICENCIA') ||
        senales.where(texto.contains).length >= 2;
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
      barrierLabel: 'Cerrar',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 260),
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
                  color: const Color(0xF5FFFFFF),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 30, 25, 25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorIcono.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, size: 42, color: colorIcono),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        mensaje,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Entendido',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  _DocumentoConductor? _siguiente() {
    return switch (_tipo) {
      _DocumentoConductor.cedulaFrente => _DocumentoConductor.cedulaReverso,
      _DocumentoConductor.cedulaReverso => _DocumentoConductor.licenciaFrente,
      _DocumentoConductor.licenciaFrente => _DocumentoConductor.licenciaReverso,
      _DocumentoConductor.licenciaReverso => null,
    };
  }

  void _continuar() {
    if (_file == null) {
      AppTopToast.show(
        context,
        message: 'Carga este documento para continuar.',
        type: AppToastType.error,
      );
      return;
    }

    final siguiente = _siguiente();
    if (siguiente == null) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _tipo = siguiente;
      _file = _fileActual(siguiente);
      _procesando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _documentoData(_tipo);
    final colorBorde =
        _file == null ? const Color(0xFFFFEB28) : const Color(0xFF2E7D32);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.06,
                child: Image.asset(
                  'assets/imagenes/fondo_w.png',
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width * 0.68,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 10,
                      ),
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
                                      icon: const Icon(
                                        Icons.arrow_back_ios_new,
                                        color: Colors.black,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Text(
                                    data.title.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      color: Colors.black,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Column(
                                children: [
                                  Text(
                                    data.subtitle,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data.note,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 35),
                            AspectRatio(
                              aspectRatio: 1.58,
                              child: Stack(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEEEEE),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: colorBorde,
                                        width: 3,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1A000000),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: _file != null
                                        ? Image.file(_file!, fit: BoxFit.cover)
                                        : _DocumentoPlaceholder(data: data),
                                  ),
                                  if (_file != null)
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
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.check_circle,
                                          color: Color(0xFF2E7D32),
                                          size: 24,
                                        ),
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
                                  color: Colors.black,
                                ),
                              )
                            else ...[
                              _ActionButton(
                                icon: Icons.photo_library,
                                label: 'Galería',
                                onTap: () => _seleccionar(ImageSource.gallery),
                              ),
                              const SizedBox(height: 15),
                              _ActionButton(
                                icon: Icons.camera_alt,
                                label: 'Cámara',
                                onTap: () => _seleccionar(ImageSource.camera),
                              ),
                            ],
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _procesando ? null : _continuar,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 5,
                                  shadowColor: const Color(0x40000000),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  _siguiente() == null
                                      ? 'Volver al resumen'
                                      : 'Continuar',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Image.asset(
                              'assets/imagenes/logito.png',
                              height: 70,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                            const SizedBox(height: 15),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentoPlaceholder extends StatelessWidget {
  final _DocumentoData data;

  const _DocumentoPlaceholder({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEEEEEE),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 70, color: const Color(0xFF78909C)),
          const SizedBox(height: 10),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentoData {
  final String title;
  final String subtitle;
  final String note;
  final IconData icon;

  const _DocumentoData({
    required this.title,
    required this.subtitle,
    required this.note,
    required this.icon,
  });
}

class _ValidacionDocumento {
  final bool esValido;
  final String titulo;
  final String mensaje;
  final IconData icono;
  final Color color;

  const _ValidacionDocumento.valido()
      : esValido = true,
        titulo = '',
        mensaje = '',
        icono = Icons.check_circle_rounded,
        color = const Color(0xFF00A86B);

  const _ValidacionDocumento.invalido({
    required this.titulo,
    required this.mensaje,
    required this.icono,
    required this.color,
  }) : esValido = false;
}

_DocumentoData _documentoData(_DocumentoConductor tipo) {
  return switch (tipo) {
    _DocumentoConductor.cedulaFrente => const _DocumentoData(
        title: 'Cédula frontal',
        subtitle: 'Sube o toma una foto de la cara principal.',
        note:
            'Nota: asegúrate de que el documento se vea completo, nítido y bien iluminado.',
        icon: Icons.badge_rounded,
      ),
    _DocumentoConductor.cedulaReverso => const _DocumentoData(
        title: 'Cédula posterior',
        subtitle: 'Sube o toma una foto del reverso.',
        note: 'Nota: evita reflejos y procura que el texto quede legible.',
        icon: Icons.badge_outlined,
      ),
    _DocumentoConductor.licenciaFrente => const _DocumentoData(
        title: 'Licencia frontal',
        subtitle: 'Sube o toma una foto de la cara principal.',
        note: 'Nota: la licencia debe verse completa y sin bordes cortados.',
        icon: Icons.credit_card_rounded,
      ),
    _DocumentoConductor.licenciaReverso => const _DocumentoData(
        title: 'Licencia posterior',
        subtitle: 'Sube o toma una foto del reverso.',
        note: 'Nota: confirma que códigos, texto y datos sean visibles.',
        icon: Icons.credit_card_outlined,
      ),
  };
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _DocumentoTile extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final File? file;
  final VoidCallback onTap;

  const _DocumentoTile({
    required this.titulo,
    required this.subtitulo,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cargado = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 74,
                    height: 58,
                    color: Colors.white,
                    child: cargado
                        ? Image.file(file!, fit: BoxFit.cover)
                        : const Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.black38,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  cargado
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: cargado ? const Color(0xFF00A86B) : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
