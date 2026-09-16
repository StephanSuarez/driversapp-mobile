import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clase encargada de la persistencia temporal del registro (Drafting).
/// Mantiene un estado síncrono en memoria RAM y una copia persistente en disco 
/// para garantizar la continuidad del proceso de onboarding.
class DatosTemporales {
  
  // ===========================================================================
  // CLAVES DE ALMACENAMIENTO (SharedPreferences)
  // ===========================================================================
  static const String _kDoc       = 'driversapp_draft_documento';
  static const String _kNom       = 'driversapp_draft_nombre';
  static const String _kApe       = 'driversapp_draft_apellidos';
  static const String _kCel       = 'driversapp_draft_celular';
  static const String _kPass      = 'driversapp_draft_password';
  static const String _kCelProp   = 'driversapp_draft_celular_propietario';
  static const String _kTipoDoc   = 'driversapp_draft_tipo_documento';
  static const String _kEsProp    = 'driversapp_draft_es_propietario';
  static const String _kPlaca     = 'driversapp_draft_placa'; 
  
  static const String _kPathPerfil    = 'path_perfil';
  static const String _kPathVFrontal  = 'path_v_frontal';
  static const String _kPathVTrasera  = 'path_v_trasera';
  static const String _kPathVLateral  = 'path_v_lateral';
  static const String _kPathCedulaFrente = 'path_cedula_frente';
  static const String _kPathCedulaReverso = 'path_cedula_reverso';
  static const String _kPathLicencia  = 'path_licencia';
  static const String _kPathLicenciaReverso = 'path_licencia_reverso';
  static const String _kPathPropiedad = 'path_propiedad';
  static const String _kPathTarjeton  = 'path_tarjeton';
  
  static const String _kPasoActual    = 'registro_paso_actual';
  static const String _kDraftDirName   = 'registro_draft';

  // ===========================================================================
  // VARIABLES DE ESTADO (RAM)
  // ===========================================================================
  static String documento = "";
  static String nombre = "";
  static String apellidos = "";
  static String celular = "";
  static String password = "";
  static String celularPropietario = "";
  static String tipoDocumento = ""; 
  static bool esPropietario = true;
  static String placa = ""; 

  static File? fotoPerfil;
  static File? fotoVehiculoFrontal;
  static File? fotoVehiculoTrasera;
  static File? fotoVehiculoLateral;
  static File? fotoCedulaFrente;
  static File? fotoCedulaReverso;
  static File? fotoLicencia;
  static File? fotoLicenciaReverso;
  static File? fotoTarjetaPropiedad;
  static File? fotoTarjeton;

  // ===========================================================================
  // PERSISTENCIA (MÉTODOS ASÍNCRONOS)
  // ===========================================================================

  /// Sincroniza los datos de la memoria con el almacenamiento físico del dispositivo.
  static Future<void> guardarFase1() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      fotoPerfil = await _persistirArchivo(fotoPerfil, 'perfil');
      fotoVehiculoFrontal = await _persistirArchivo(fotoVehiculoFrontal, 'vehiculo_frontal');
      fotoVehiculoTrasera = await _persistirArchivo(fotoVehiculoTrasera, 'vehiculo_trasera');
      fotoVehiculoLateral = await _persistirArchivo(fotoVehiculoLateral, 'vehiculo_lateral');
      fotoCedulaFrente = await _persistirArchivo(fotoCedulaFrente, 'cedula_frente');
      fotoCedulaReverso = await _persistirArchivo(fotoCedulaReverso, 'cedula_reverso');
      fotoLicencia = await _persistirArchivo(fotoLicencia, 'licencia');
      fotoLicenciaReverso = await _persistirArchivo(fotoLicenciaReverso, 'licencia_reverso');
      fotoTarjetaPropiedad = await _persistirArchivo(fotoTarjetaPropiedad, 'tarjeta_propiedad');
      fotoTarjeton = await _persistirArchivo(fotoTarjeton, 'tarjeton');
      
      // Ejecución concurrente para optimizar el tiempo de escritura
      await Future.wait([
        prefs.setString(_kDoc, documento),
        prefs.setString(_kNom, nombre),
        prefs.setString(_kApe, apellidos),
        prefs.setString(_kCel, celular),
        prefs.setString(_kPass, password),
        prefs.setString(_kCelProp, celularPropietario),
        prefs.setString(_kTipoDoc, tipoDocumento),
        prefs.setBool(_kEsProp, esPropietario),
        prefs.setString(_kPlaca, placa),
      ]);
      
      await Future.wait([
        _guardarRutaArchivo(prefs, _kPathPerfil, fotoPerfil),
        _guardarRutaArchivo(prefs, _kPathVFrontal, fotoVehiculoFrontal),
        _guardarRutaArchivo(prefs, _kPathVTrasera, fotoVehiculoTrasera),
        _guardarRutaArchivo(prefs, _kPathVLateral, fotoVehiculoLateral),
        _guardarRutaArchivo(prefs, _kPathCedulaFrente, fotoCedulaFrente),
        _guardarRutaArchivo(prefs, _kPathCedulaReverso, fotoCedulaReverso),
        _guardarRutaArchivo(prefs, _kPathLicencia, fotoLicencia),
        _guardarRutaArchivo(prefs, _kPathLicenciaReverso, fotoLicenciaReverso),
        _guardarRutaArchivo(prefs, _kPathPropiedad, fotoTarjetaPropiedad),
        _guardarRutaArchivo(prefs, _kPathTarjeton, fotoTarjeton),
      ]);
      
    } catch (e) {
      debugPrint("[DatosTemporales] Error al guardar borrador: $e");
    }
  }

  /// Recupera la información del disco y reconstruye el estado en RAM.
  static Future<void> cargarFase1() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      documento          = prefs.getString(_kDoc) ?? "";
      nombre             = prefs.getString(_kNom) ?? "";
      apellidos          = prefs.getString(_kApe) ?? "";
      celular            = prefs.getString(_kCel) ?? "";
      password           = prefs.getString(_kPass) ?? "";
      celularPropietario = prefs.getString(_kCelProp) ?? "";
      tipoDocumento      = prefs.getString(_kTipoDoc) ?? "";
      esPropietario      = prefs.getBool(_kEsProp) ?? true;
      placa              = prefs.getString(_kPlaca) ?? ""; 

      // Hidratación segura de archivos binarios
      fotoPerfil           = _cargarArchivoSeguro(prefs, _kPathPerfil);
      fotoVehiculoFrontal  = _cargarArchivoSeguro(prefs, _kPathVFrontal);
      fotoVehiculoTrasera  = _cargarArchivoSeguro(prefs, _kPathVTrasera);
      fotoVehiculoLateral  = _cargarArchivoSeguro(prefs, _kPathVLateral);
      fotoCedulaFrente     = _cargarArchivoSeguro(prefs, _kPathCedulaFrente);
      fotoCedulaReverso    = _cargarArchivoSeguro(prefs, _kPathCedulaReverso);
      fotoLicencia         = _cargarArchivoSeguro(prefs, _kPathLicencia);
      fotoLicenciaReverso  = _cargarArchivoSeguro(prefs, _kPathLicenciaReverso);
      fotoTarjetaPropiedad = _cargarArchivoSeguro(prefs, _kPathPropiedad);
      fotoTarjeton         = _cargarArchivoSeguro(prefs, _kPathTarjeton);
      
    } catch (e) {
      debugPrint("[DatosTemporales] Error al cargar datos: $e");
    }
  }

  /// Valida la existencia física de un archivo antes de cargarlo a memoria.
  static File? _cargarArchivoSeguro(SharedPreferences prefs, String key) {
    final String? path = prefs.getString(key);
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) return file;
    }
    return null;
  }

  static Future<File?> _persistirArchivo(File? archivo, String nombreBase) async {
    if (archivo == null) return null;

    try {
      if (!await archivo.exists()) return null;

      final draftDir = await _directorioBorrador();
      final extension = p.extension(archivo.path).isEmpty ? '.jpg' : p.extension(archivo.path);
      final destino = File(p.join(draftDir.path, '$nombreBase$extension'));

      if (p.equals(archivo.path, destino.path)) return archivo;

      if (await destino.exists()) {
        await destino.delete();
      }

      return archivo.copy(destino.path);
    } catch (e) {
      debugPrint("[DatosTemporales] Error al persistir archivo $nombreBase: $e");
      return archivo.existsSync() ? archivo : null;
    }
  }

  static Future<Directory> _directorioBorrador() async {
    final baseDir = await getApplicationSupportDirectory();
    final draftDir = Directory(p.join(baseDir.path, _kDraftDirName));
    if (!await draftDir.exists()) {
      await draftDir.create(recursive: true);
    }
    return draftDir;
  }

  static Future<void> _guardarRutaArchivo(SharedPreferences prefs, String key, File? archivo) async {
    if (archivo != null && await archivo.exists()) {
      await prefs.setString(key, archivo.path);
    } else {
      await prefs.remove(key);
    }
  }

  // ===========================================================================
  // MÁQUINA DE ESTADOS (FLUJO)
  // ===========================================================================

  static Future<void> guardarPasoActual(String paso) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPasoActual, paso);
  }

  static Future<String> obtenerPasoActual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPasoActual) ?? 'inicio';
  }

  // ===========================================================================
  // LIMPIEZA DE DATOS (PURGA)
  // ===========================================================================

  /// Elimina de forma definitiva el borrador local tras completar el registro.
  static Future<void> borrarBorrador() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Limpieza de estado en RAM
      documento = ""; nombre = ""; apellidos = ""; celular = ""; 
      password = ""; celularPropietario = ""; tipoDocumento = "";
      esPropietario = true; placa = ""; 
      
      fotoPerfil = null; fotoVehiculoFrontal = null; fotoVehiculoTrasera = null; 
      fotoVehiculoLateral = null; fotoCedulaFrente = null; fotoCedulaReverso = null;
      fotoLicencia = null; fotoLicenciaReverso = null; fotoTarjetaPropiedad = null; 
      fotoTarjeton = null;

      // Definición de claves para eliminación masiva
      final keysToRemove = [
        _kDoc, _kNom, _kApe, _kCel, _kPass, _kCelProp, _kTipoDoc, 
        _kEsProp, _kPlaca, _kPathPerfil, _kPathVFrontal, _kPathVTrasera, 
        _kPathVLateral, _kPathCedulaFrente, _kPathCedulaReverso, _kPathLicencia,
        _kPathLicenciaReverso, _kPathPropiedad, _kPathTarjeton, _kPasoActual
      ];

      // Borrado en paralelo para liberar el hilo principal
      await Future.wait(keysToRemove.map((key) => prefs.remove(key)));

      final draftDir = await _directorioBorrador();
      if (await draftDir.exists()) {
        await draftDir.delete(recursive: true);
      }
      
    } catch (e) {
      debugPrint("[DatosTemporales] Error durante la purga de datos: $e");
    }
  }

  /// Limpia solo los documentos/fotos del onboarding y conserva datos basicos.
  static Future<void> borrarDocumentosRegistro() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      placa = "";
      fotoPerfil = null;
      fotoVehiculoFrontal = null;
      fotoVehiculoTrasera = null;
      fotoVehiculoLateral = null;
      fotoCedulaFrente = null;
      fotoCedulaReverso = null;
      fotoLicencia = null;
      fotoLicenciaReverso = null;
      fotoTarjetaPropiedad = null;
      fotoTarjeton = null;

      final keysToRemove = [
        _kPlaca,
        _kPathPerfil,
        _kPathVFrontal,
        _kPathVTrasera,
        _kPathVLateral,
        _kPathCedulaFrente,
        _kPathCedulaReverso,
        _kPathLicencia,
        _kPathLicenciaReverso,
        _kPathPropiedad,
        _kPathTarjeton,
        'path_licencia_seguro',
        'licencia_validada',
      ];

      await Future.wait(keysToRemove.map((key) => prefs.remove(key)));
      await prefs.setString(_kPasoActual, 'foto_perfil');

      final draftDir = await _directorioBorrador();
      if (await draftDir.exists()) {
        await draftDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint("[DatosTemporales] Error al limpiar documentos: $e");
    }
  }
}
