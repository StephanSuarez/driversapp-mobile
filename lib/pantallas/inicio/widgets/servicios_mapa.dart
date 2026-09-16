// lib/pantallas/inicio/widgets/servicios_mapa.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:slide_to_act/slide_to_act.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../global/environment.dart';
import '../../../utils/mapa_utils.dart';
import 'tarjeta_solicitud.dart';
import '../../../services/driver_location_service.dart';
import '../../../services/push_notification_service.dart';
import 'banner_superior.dart';
import 'velocimetro.dart';
import 'panel_inferior.dart';
import 'chat_viaje_modal.dart';
import 'modal_cobro.dart';
import 'modal_rating_cliente.dart';
import 'modal_error_glass.dart';
import 'modal_cancelacion.dart';
import 'boton_glass.dart';

class ServiciosMapaTab extends StatefulWidget {
  final Function(bool)? onEstadoViajeChanged;
  const ServiciosMapaTab({super.key, this.onEstadoViajeChanged});

  @override
  State<ServiciosMapaTab> createState() => _ServiciosMapaTabState();
}

class _ServiciosMapaTabState extends State<ServiciosMapaTab>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final GlobalKey<SlideActionState> _slideKeyLlegar =
      GlobalKey<SlideActionState>();
  final GlobalKey<SlideActionState> _slideKeyFinalizar =
      GlobalKey<SlideActionState>();

  MapboxMap? _mapboxMap;
  Point? _miPuntoActual;
  Point? _gpsCrudoActual;
  geo.Position? _ultimaPosicionProcesada;
  bool _gpsIniciado = false;

  PointAnnotationManager? _pointManager;
  final List<PointAnnotation> _pinesAnnotations = [];

  // Carro 3D snappeado a la ruta (ModelLayer)
  static const String _carroSourceId = "carro-snapped-source";
  static const String _carroLayerId = "carro-snapped-layer";
  static const String _carroModelUri = "asset://assets/modelos/carro.glb";
  // Offset (en grados) para alinear el "frente" del modelo GLB con el bearing.
  // Ajustar si el carro queda mirando para el lado.
  static const double _carroBearingOffset = 0.0;
  bool _carroLayerLista = false;
  bool _carroLayerVisible = false;
  Position? _carroPosVisible;
  double _carroBearingVisible = 0.0;
  Position? _animFromPos;
  Position? _animToPos;
  double _animFromBearing = 0.0;
  double _animToBearing = 0.0;
  late AnimationController _carroAnimController;

  Uint8List? _dotVerdeBytes;
  Uint8List? _dotRojoBytes;
  Uint8List? _puntoInicioConexionBytes;

  final DriverLocationService _locationService = DriverLocationService();
  bool _modalMostrandose = false;
  int _estadoViaje = 0;
  Map<String, dynamic>? _viajeActivo;

  String _kmRuta = "0.0";
  int _minRuta = 0;
  bool _panelExpandido = false;
  String _distanciaManiobra = "0 m";
  Position? _siguienteManiobraCoords;

  final ValueNotifier<double> _velocidadActual = ValueNotifier(0.0);
  int _chatUnreadCount = 0;
  double _headingActual = 0.0;

  String _instruccionNavegacion = "Calculando ruta...";
  String _ultimaInstruccionHablada = "";
  IconData _iconoNavegacion = Icons.navigation_rounded;

  bool _isTrackingCamera = true;
  bool _vista3D = false;
  bool _sonidoActivado = true;
  bool _calculandoRuta = false;
  DateTime? _bloquearCamaraAutoHasta;
  static const double _rerouteDistanceMeters = 50.0;

  List<Position> _rutaActualCoords = [];
  List<String> _congestionActual = [];
  Position? _destinoActual;
  bool _actualizandoRutaVisible = false;

  // Viaje en curso pendiente de restaurar (si la app se reabrió con un viaje activo).
  Map<String, dynamic>? _viajePendienteRestaurar;

  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MapboxOptions.setAccessToken(Environment.mapboxToken);

    _carroAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..addListener(_onCarroAnimTick);

    _prepararIconos();
    _initTts();

    _locationService.viajeEntrante.addListener(_revisarViajeEntrante);
    _locationService.viajeCanceladoExternamente
        .addListener(_revisarCancelacionExterna);
    _locationService.chatUnreadCount.addListener(_onChatUnreadChanged);
    _locationService.chatMessagePreview.addListener(_onChatMessagePreview);

    _intentarObtenerViajeActivo();
  }

  void _onChatUnreadChanged() {
    if (!mounted) return;
    setState(() => _chatUnreadCount = _locationService.chatUnreadCount.value);
  }

  void _onChatMessagePreview() {
    final event = _locationService.chatMessagePreview.value;
    if (!mounted || event == null) return;
    if (_viajeActivo?['id']?.toString() != event.rideId) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 170,
        ),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                event.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "Abrir",
          textColor: const Color(0xFFFFD54F),
          onPressed: () => _abrirChat(event.rideId),
        ),
      ),
    );
  }

  void _abrirChat(String rideId) {
    _locationService.clearUnreadChat(rideId);
    ChatViajeModal.mostrar(context, rideId);
  }

  Future<void> _mostrarOpcionesNavegacion() async {
    final destino = _destinoActual ?? _destinoDesdeViajeActivo();
    if (destino == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay destino activo para navegar")),
      );
      return;
    }

    final tramo = _estadoViaje < 3 ? "origen" : "destino";
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.map_rounded),
                  title: const Text("Seguir en DriversApp"),
                  subtitle: Text("Navegación interna hacia el $tramo"),
                  onTap: () => Navigator.of(context).pop(),
                ),
                ListTile(
                  leading: const Icon(Icons.navigation_rounded),
                  title: const Text("Abrir Waze"),
                  subtitle: Text("Enviar coordenadas del $tramo"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _abrirNavegacionExterna(destino, _NavigationApp.waze);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.directions_rounded),
                  title: const Text("Abrir Google Maps"),
                  subtitle: Text("Enviar coordenadas del $tramo"),
                  onTap: () {
                    Navigator.of(context).pop();
                    _abrirNavegacionExterna(destino, _NavigationApp.googleMaps);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _abrirNavegacionExterna(
    Position destino,
    _NavigationApp app,
  ) async {
    final rideId = _viajeActivo?['id']?.toString();
    final isDestinationLeg = _estadoViaje >= 3;
    final lat = destino.lat.toStringAsFixed(6);
    final lng = destino.lng.toStringAsFixed(6);
    final appUri = app == _NavigationApp.waze
        ? Uri.parse('waze://?ll=$lat,$lng&navigate=yes')
        : Platform.isIOS
            ? Uri.parse(
                'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving')
            : Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final webUri = app == _NavigationApp.waze
        ? Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
          );
    final appName = app == _NavigationApp.waze ? "Waze" : "Google Maps";

    try {
      final openedApp =
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (openedApp) {
        if (rideId != null && rideId.isNotEmpty) {
          await PushNotificationService().showNavigationReturnNotification(
            rideId: rideId,
            isDestinationLeg: isDestinationLeg,
          );
        }
        return;
      }
    } catch (_) {}

    final openedWeb =
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
    if (openedWeb && rideId != null && rideId.isNotEmpty) {
      await PushNotificationService().showNavigationReturnNotification(
        rideId: rideId,
        isDestinationLeg: isDestinationLeg,
      );
    }
    if (!openedWeb && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No se pudo abrir $appName")),
      );
    }
  }

  Position? _destinoDesdeViajeActivo() {
    final viaje = _viajeActivo;
    if (viaje == null) return null;

    final key = _estadoViaje < 3 ? 'origin' : 'destination';
    final punto = viaje[key];
    if (punto is! Map) return null;

    final lat = (punto['lat'] as num?)?.toDouble();
    final lng = (punto['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return Position(lng, lat);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarYReactivarGPS();
      _intentarObtenerViajeActivo();
    }
  }

  @override
  void dispose() {
    _locationService.viajeEntrante.removeListener(_revisarViajeEntrante);
    _locationService.viajeCanceladoExternamente
        .removeListener(_revisarCancelacionExterna);
    _locationService.chatUnreadCount.removeListener(_onChatUnreadChanged);
    _locationService.chatMessagePreview.removeListener(_onChatMessagePreview);
    WidgetsBinding.instance.removeObserver(this);
    _carroAnimController.dispose();
    _velocidadActual.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<bool> _tienePermisosGPS() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return permission == geo.LocationPermission.whileInUse ||
        permission == geo.LocationPermission.always;
  }

  Future<void> _verificarYReactivarGPS() async {
    if (_gpsIniciado || _mapboxMap == null) return;
    if (await _tienePermisosGPS()) {
      _gpsIniciado = true;
      await _actualizarPuckSegunEstado();
      await _centrarUbicacionInicial();
      _iniciarNavegacionFluida();
      await _aplicarRestauracionSiPosible();
    }
  }

  // Pregunta al backend si hay un viaje activo y lo deja en cola para restaurar
  // cuando el GPS y el mapa estén listos.
  Future<void> _intentarObtenerViajeActivo() async {
    if (_estadoViaje > 0 || _modalMostrandose) return;
    final viaje = await _locationService.obtenerViajeActivo();
    if (!mounted || viaje == null) return;
    _viajePendienteRestaurar = viaje;
    await _aplicarRestauracionSiPosible();
  }

  // Restaura el estado del viaje en curso. El estado se decide según el status del backend:
  //   IN_PROGRESS / STARTED  -> estado 3 (con pasajero, navegando al destino, sin PIN)
  //   ACCEPTED / ASSIGNED…   -> estado 1 (en camino al pickup, PIN al llegar)
  Future<void> _aplicarRestauracionSiPosible() async {
    final viaje = _viajePendienteRestaurar;
    if (viaje == null) return;
    if (!_gpsIniciado || _miPuntoActual == null || _mapboxMap == null) return;
    if (_estadoViaje > 0 || _modalMostrandose) {
      _viajePendienteRestaurar = null;
      return;
    }
    _viajePendienteRestaurar = null;

    final status = viaje['status']?.toString().toUpperCase() ?? '';
    final yaConPasajero = status == 'IN_PROGRESS' || status == 'STARTED';

    final destinoRuta = yaConPasajero
        ? Position(viaje['destination']['lng'].toDouble(),
            viaje['destination']['lat'].toDouble())
        : Position(viaje['origin']['lng'].toDouble(),
            viaje['origin']['lat'].toDouble());

    widget.onEstadoViajeChanged?.call(true);
    setState(() {
      _viajeActivo = viaje;
      _estadoViaje = yaConPasajero ? 3 : 1;
      _isTrackingCamera = true;
      _ultimaPosicionProcesada = null;
      _destinoActual = destinoRuta;
      _panelExpandido = false;
    });
    await _actualizarPuckSegunEstado();
    _locationService.iniciarMonitoreoViajeActivo(viaje['id']);
    await _dibujarRutaPro(destinoRuta, esOverview: false);
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _hablarInstruccion(String texto) async {
    if (_sonidoActivado &&
        texto.isNotEmpty &&
        texto != _ultimaInstruccionHablada) {
      await _flutterTts.speak(texto);
      _ultimaInstruccionHablada = texto;
    }
  }

  void _revisarCancelacionExterna() {
    if (_locationService.viajeCanceladoExternamente.value) {
      widget.onEstadoViajeChanged?.call(false);
      setState(() {
        _estadoViaje = 0;
        _viajeActivo = null;
        _panelExpandido = false;
        _ultimaInstruccionHablada = "";
        _rutaActualCoords.clear();
        _congestionActual.clear();
        _ultimaPosicionProcesada = null;
      });
      _limpiarMapaYCentrar();
      _locationService.viajeCanceladoExternamente.value = false;
      _flutterTts.stop();
    }
  }

  // ============ SNAP TO ROUTE ============
  // Índice del segmento donde está actualmente el carro (forward-only).
  int _segmentoActualIdx = 0;

  // Proyecta una coordenada GPS sobre el segmento más cercano de la ruta.
  // Solo considera segmentos hacia adelante (no permite que el carro retroceda
  // por jitter del GPS). Si el GPS reporta una posición muy detrás del segmento
  // actual, mantiene la última proyección.
  ({Position pos, double bearing})? _snapToRoute(double lat, double lng) {
    if (_rutaActualCoords.length < 2) return null;

    if (_segmentoActualIdx >= _rutaActualCoords.length - 1) {
      _segmentoActualIdx = _rutaActualCoords.length - 2;
    }
    if (_segmentoActualIdx < 0) _segmentoActualIdx = 0;

    // Permite buscar un poquito hacia atrás (1 segmento) por si el snap anterior
    // adelantó de más, pero no más allá — eso bloquea el efecto rebote.
    final inicio =
        (_segmentoActualIdx - 1).clamp(0, _rutaActualCoords.length - 2);

    double minDist = double.infinity;
    Position? bestPoint;
    int bestSegIdx = inicio;

    for (int i = inicio; i < _rutaActualCoords.length - 1; i++) {
      final projected = _proyectarEnSegmento(
          lat, lng, _rutaActualCoords[i], _rutaActualCoords[i + 1]);
      final dist = geo.Geolocator.distanceBetween(
        lat,
        lng,
        projected.lat.toDouble(),
        projected.lng.toDouble(),
      );
      if (dist < minDist) {
        minDist = dist;
        bestPoint = projected;
        bestSegIdx = i;
      }
    }

    if (bestPoint == null) return null;
    if (minDist > _rerouteDistanceMeters) return null;

    _segmentoActualIdx = bestSegIdx;

    final a = _rutaActualCoords[bestSegIdx];
    final b = _rutaActualCoords[bestSegIdx + 1];
    final bearing = geo.Geolocator.bearingBetween(
      a.lat.toDouble(),
      a.lng.toDouble(),
      b.lat.toDouble(),
      b.lng.toDouble(),
    );

    return (pos: bestPoint, bearing: bearing);
  }

  Position _proyectarEnSegmento(
      double lat, double lng, Position a, Position b) {
    final ax = a.lng.toDouble(), ay = a.lat.toDouble();
    final bx = b.lng.toDouble(), by = b.lat.toDouble();
    final px = lng, py = lat;

    final dx = bx - ax, dy = by - ay;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return Position(ax, ay);

    double t = ((px - ax) * dx + (py - ay) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);

    return Position(ax + t * dx, ay + t * dy);
  }

  // ============ CARRO 3D SNAPPEADO A LA RUTA (ModelLayer) ============
  Future<void> _setupCarroSnapped() async {
    if (_mapboxMap == null || _carroLayerLista) return;
    try {
      await _mapboxMap!.style.addSource(GeoJsonSource(
        id: _carroSourceId,
        data: jsonEncode({"type": "FeatureCollection", "features": []}),
      ));

      await _mapboxMap!.style.addLayer(ModelLayer(
        id: _carroLayerId,
        sourceId: _carroSourceId,
        modelId: _carroModelUri,
        // Escala casi constante para que el carro no cambie de tamaño al animar la cámara.
        modelScaleExpression: [
          "interpolate",
          ["linear"],
          ["zoom"],
          14,
          [
            "literal",
            [5.8, 5.8, 5.8]
          ],
          15,
          [
            "literal",
            [5.4, 5.4, 5.4]
          ],
          17,
          [
            "literal",
            [4.7, 4.7, 4.7]
          ],
          18,
          [
            "literal",
            [4.2, 4.2, 4.2]
          ],
          19,
          [
            "literal",
            [3.8, 3.8, 3.8]
          ],
          22,
          [
            "literal",
            [3.0, 3.0, 3.0]
          ],
        ],
        modelRotation: [0.0, 0.0, 0.0],
        modelType: ModelType.COMMON_3D,
      ));
      // Empieza oculta hasta que entre en navegación
      await _mapboxMap!.style
          .setStyleLayerProperty(_carroLayerId, "visibility", "none");

      _carroLayerLista = true;
    } catch (_) {}
  }

  Future<void> _setCarroLayerVisible(bool visible) async {
    if (_mapboxMap == null ||
        !_carroLayerLista ||
        _carroLayerVisible == visible) return;
    try {
      await _mapboxMap!.style.setStyleLayerProperty(
          _carroLayerId, "visibility", visible ? "visible" : "none");
      _carroLayerVisible = visible;
    } catch (_) {}
  }

  // Escribe la posición y rotación actuales del carro al ModelLayer.
  Future<void> _renderCarroSnapped(Position pos, double bearing) async {
    if (_mapboxMap == null || !_carroLayerLista) return;
    try {
      final geojson = jsonEncode({
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "Point",
              "coordinates": [pos.lng, pos.lat]
            },
            "properties": {},
          }
        ],
      });
      await _mapboxMap!.style
          .setStyleSourceProperty(_carroSourceId, "data", geojson);
      await _mapboxMap!.style.setStyleLayerProperty(
        _carroLayerId,
        "model-rotation",
        [0.0, 0.0, bearing + _carroBearingOffset],
      );
    } catch (_) {}
  }

  // Anima el carro desde su posición visible actual hasta (target, targetBearing) en durationMs.
  void _animarCarroSnapped(
      Position target, double targetBearing, int durationMs) {
    _animFromPos = _carroPosVisible ?? target;
    _animToPos = target;
    _animFromBearing = _carroBearingVisible;
    // Tomar el camino angular más corto
    double diff = (targetBearing - _animFromBearing) % 360.0;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    _animToBearing = _animFromBearing + diff;

    _carroAnimController.duration = Duration(milliseconds: durationMs);
    _carroAnimController.stop();
    _carroAnimController.value = 0.0;
    _carroAnimController.forward();
  }

  DateTime? _ultimoTickRender;

  void _onCarroAnimTick() {
    if (_animFromPos == null || _animToPos == null) return;
    // Throttle a ~30 fps para no saturar el platform channel con setStyleSourceProperty.
    final now = DateTime.now();
    final esFinDeAnim = _carroAnimController.value >= 1.0;
    if (!esFinDeAnim &&
        _ultimoTickRender != null &&
        now.difference(_ultimoTickRender!).inMilliseconds < 33) {
      return;
    }
    _ultimoTickRender = now;

    final t = Curves.easeOut.transform(_carroAnimController.value);

    final lng = _animFromPos!.lng + (_animToPos!.lng - _animFromPos!.lng) * t;
    final lat = _animFromPos!.lat + (_animToPos!.lat - _animFromPos!.lat) * t;
    final bearing = _animFromBearing + (_animToBearing - _animFromBearing) * t;

    _carroPosVisible = Position(lng, lat);
    _carroBearingVisible = bearing % 360.0;
    _renderCarroSnapped(_carroPosVisible!, _carroBearingVisible);

    if (esFinDeAnim && _estadoViaje > 0) {
      _recortarRutaVisibleEn(_carroPosVisible!);
    }
  }

  // ============ PUCK NATIVO vs CARRO 3D SNAPPEADO ============
  // estado == 0: muestra LocationPuck3D nativo (sigue GPS crudo, OK estando quieto)
  // estado >  0: oculta puck nativo y muestra ModelLayer 3D sobre la línea (snap-to-route)
  Future<void> _actualizarPuckSegunEstado() async {
    if (_mapboxMap == null) return;

    if (_estadoViaje > 0) {
      await _mapboxMap!.location
          .updateSettings(LocationComponentSettings(enabled: false));
      await _setupCarroSnapped();
      // Inicializar posición visible al snap actual o al GPS
      if (_miPuntoActual != null && _carroPosVisible == null) {
        _carroPosVisible = _miPuntoActual!.coordinates;
        _carroBearingVisible = _headingActual;
        await _renderCarroSnapped(_carroPosVisible!, _carroBearingVisible);
      }
      await _setCarroLayerVisible(true);
    } else {
      await _setCarroLayerVisible(false);
      _carroAnimController.stop();
      _carroPosVisible = null;
      await _mapboxMap!.location.updateSettings(LocationComponentSettings(
        enabled: true,
        locationPuck: LocationPuck(
          locationPuck3D: LocationPuck3D(
            modelUri: "asset://assets/modelos/carro.glb",
            modelScale: [15.0, 15.0, 15.0],
            modelRotation: [0.0, 0.0, 0.0],
          ),
        ),
        pulsingEnabled: false,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.COURSE,
      ));
    }
  }

  DateTime? _ultimoUpdateGps;

  double get _pitchCamaraActual {
    if (!_vista3D) return 0.0;
    return _estadoViaje > 0 ? 60.0 : 45.0;
  }

  double get _zoomCamaraActual {
    if (_estadoViaje > 0) return _vista3D ? 17.6 : 16.9;
    return _vista3D ? 17.0 : 15.8;
  }

  double get _bearingCamaraActual => _vista3D ? _headingActual : 0.0;

  bool get _camaraAutoBloqueada {
    final hasta = _bloquearCamaraAutoHasta;
    return hasta != null && DateTime.now().isBefore(hasta);
  }

  Point? get _centroCamaraActual {
    if (_estadoViaje > 0 && _carroPosVisible != null) {
      return Point(coordinates: _carroPosVisible!);
    }
    return _miPuntoActual ?? _gpsCrudoActual;
  }

  void _aplicarCamaraActual({int durationMs = 500, bool seguir = false}) {
    final centro = _centroCamaraActual;
    if (centro == null) return;
    if (seguir) setState(() => _isTrackingCamera = true);
    _bloquearCamaraAutoHasta =
        DateTime.now().add(Duration(milliseconds: durationMs + 120));

    _mapboxMap?.easeTo(
      CameraOptions(
        center: centro,
        bearing: _bearingCamaraActual,
        pitch: _pitchCamaraActual,
        zoom: _zoomCamaraActual,
      ),
      MapAnimationOptions(duration: durationMs),
    );
  }

  void _iniciarNavegacionFluida() {
    geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((geo.Position pos) {
      if (!mounted) return;

      _velocidadActual.value = (pos.speed * 3.6).clamp(0.0, 999.0);
      _gpsCrudoActual =
          Point(coordinates: Position(pos.longitude, pos.latitude));

      if (_ultimaPosicionProcesada != null) {
        double distMovida = geo.Geolocator.distanceBetween(
          _ultimaPosicionProcesada!.latitude,
          _ultimaPosicionProcesada!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (distMovida < 1.5) return;
      }
      _ultimaPosicionProcesada = pos;

      // Duración de animación adaptativa: que matchee el intervalo real entre eventos GPS.
      final ahora = DateTime.now();
      int durMs = 1000;
      if (_ultimoUpdateGps != null) {
        final delta = ahora.difference(_ultimoUpdateGps!).inMilliseconds;
        durMs = delta.clamp(400, 2000);
      }
      _ultimoUpdateGps = ahora;

      if (_estadoViaje > 0 && _mapboxMap != null && !_modalMostrandose) {
        // Modo navegación: snap GPS sobre la línea.
        // Si hay un cálculo de ruta en curso, evita snappear a la ruta vieja para
        // que el carro no se "trabe" en el segmento anterior durante la transición.
        final snap =
            _calculandoRuta ? null : _snapToRoute(pos.latitude, pos.longitude);
        Position posUsada;
        double bearingUsado;

        if (snap != null) {
          posUsada = snap.pos;
          bearingUsado = snap.bearing;
        } else {
          posUsada = Position(pos.longitude, pos.latitude);
          bearingUsado = pos.heading;
        }

        _miPuntoActual = Point(coordinates: posUsada);
        _headingActual = bearingUsado;

        _animarCarroSnapped(posUsada, bearingUsado, durMs);

        // Cámara: una sola animación nativa por evento GPS (Mapbox la corre en GPU).
        if (_isTrackingCamera && !_camaraAutoBloqueada) {
          _mapboxMap!.easeTo(
            CameraOptions(
              center: _miPuntoActual,
              bearing: _vista3D ? bearingUsado : 0.0,
              pitch: _pitchCamaraActual,
              zoom: _zoomCamaraActual,
            ),
            MapAnimationOptions(duration: durMs, startDelay: 0),
          );
        }
        _procesarProgresoYDesvios(pos);
      } else if (_estadoViaje == 0 &&
          _mapboxMap != null &&
          !_modalMostrandose) {
        // Modo idle: GPS crudo + puck nativo 3D
        _miPuntoActual =
            Point(coordinates: Position(pos.longitude, pos.latitude));
        _headingActual = pos.heading;

        if (_isTrackingCamera && !_camaraAutoBloqueada) {
          _mapboxMap!.easeTo(
            CameraOptions(
              center: _miPuntoActual,
              bearing: _bearingCamaraActual,
              pitch: _pitchCamaraActual,
              zoom: _zoomCamaraActual,
            ),
            MapAnimationOptions(duration: durMs),
          );
        }
      }
    });
  }

  void _procesarProgresoYDesvios(geo.Position posActual) async {
    if (_rutaActualCoords.isEmpty || _calculandoRuta || _destinoActual == null)
      return;

    double distanciaMasCorta = double.infinity;
    Position? puntoMasCercano;

    for (int i = 0; i < _rutaActualCoords.length - 1; i++) {
      final projected = _proyectarEnSegmento(
        posActual.latitude,
        posActual.longitude,
        _rutaActualCoords[i],
        _rutaActualCoords[i + 1],
      );
      double dist = geo.Geolocator.distanceBetween(
        posActual.latitude,
        posActual.longitude,
        projected.lat.toDouble(),
        projected.lng.toDouble(),
      );
      if (dist < distanciaMasCorta) {
        distanciaMasCorta = dist;
        puntoMasCercano = projected;
      }
    }

    if (distanciaMasCorta > _rerouteDistanceMeters) {
      _dibujarRutaPro(_destinoActual!, esOverview: false);
      return;
    }

    final posicionVisual = _carroPosVisible ?? puntoMasCercano;
    if (posicionVisual != null) {
      await _recortarRutaVisibleEn(posicionVisual);
    }

    if (_siguienteManiobraCoords != null) {
      double dM = geo.Geolocator.distanceBetween(
        posActual.latitude,
        posActual.longitude,
        _siguienteManiobraCoords!.lat.toDouble(),
        _siguienteManiobraCoords!.lng.toDouble(),
      );
      setState(() {
        _distanciaManiobra = dM >= 1000
            ? "${(dM / 1000).toStringAsFixed(1)} km"
            : "${dM.round()} m";
      });
    }
  }

  void _revisarViajeEntrante() {
    final viaje = _locationService.viajeEntrante.value;
    if (viaje != null && !_modalMostrandose && _estadoViaje == 0) {
      _dispararNuevaSolicitud(viaje);
    }
  }

  Future<void> _dispararNuevaSolicitud(Map<String, dynamic> jsonViaje) async {
    _modalMostrandose = true;
    _isTrackingCamera = false;

    final origenPersona = Position(jsonViaje['origin']['lng'].toDouble(),
        jsonViaje['origin']['lat'].toDouble());
    final destinoPersona = Position(jsonViaje['destination']['lng'].toDouble(),
        jsonViaje['destination']['lat'].toDouble());

    await _dibujarRutaPro(destinoPersona,
        esOverview: true, paradaIntermedia: origenPersona);

    if (mounted) {
      await TarjetaSolicitud.mostrar(context, jsonViaje,
          (aceptado, data) async {
        _modalMostrandose = false;
        if (aceptado) {
          widget.onEstadoViajeChanged?.call(true);
          setState(() {
            _viajeActivo = data;
            _estadoViaje = 1;
            _isTrackingCamera = true;
            _ultimaPosicionProcesada = null;
            _destinoActual = origenPersona;
          });
          await _actualizarPuckSegunEstado();
          _locationService.iniciarMonitoreoViajeActivo(data['id']);
          await _dibujarRutaPro(origenPersona, esOverview: false);
          if (mounted) unawaited(_mostrarOpcionesNavegacion());
        } else {
          _limpiarMapaYCentrar();
        }
      });
    }
  }

  Future<void> _prepararIconos() async {
    _dotVerdeBytes = await MapaUtils.generarIconoPremium(
        const Color(0xFF10B981), Icons.person_rounded);
    _dotRojoBytes = await MapaUtils.generarIconoPremium(
        const Color(0xFFEF4444), Icons.location_on_rounded);
    _puntoInicioConexionBytes = await MapaUtils.generarIconoPremium(
        Colors.grey.shade800, Icons.my_location_rounded,
        size: 70.0);

    if (mounted) setState(() {});
    _verificarYReactivarGPS();
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _mapboxMap!.loadStyleURI(Environment.mapboxStyleUrl);

    await _mapboxMap!.logo.updateSettings(LogoSettings(marginBottom: -200.0));
    await _mapboxMap!.attribution
        .updateSettings(AttributionSettings(marginBottom: -200.0));
    await _mapboxMap!.compass.updateSettings(CompassSettings(enabled: false));
    await _mapboxMap!.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    try {
      await _mapboxMap!.style.addSource(GeoJsonSource(
          id: "source-ancla",
          data: jsonEncode({"type": "FeatureCollection", "features": []})));
      await _mapboxMap!.style.addLayer(
          LineLayer(id: "capa-ancla-rutas", sourceId: "source-ancla"));
    } catch (_) {}

    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    // Que el carro rote alineado con el mapa (no con la pantalla)
    try {
      await _pointManager!.setIconRotationAlignment(IconRotationAlignment.MAP);
    } catch (_) {}

    // Pre-registra el ModelLayer del carro 3D snappeado
    await _setupCarroSnapped();

    _verificarYReactivarGPS();
  }

  void _pausarSeguimientoCamara() {
    if (_isTrackingCamera) setState(() => _isTrackingCamera = false);
  }

  Future<void> _centrarUbicacionInicial() async {
    try {
      geo.Position pos = await geo.Geolocator.getCurrentPosition();
      if (mounted) {
        _gpsCrudoActual = Point(
            coordinates:
                Position(pos.longitude.toDouble(), pos.latitude.toDouble()));
        _miPuntoActual = _gpsCrudoActual;
        _mapboxMap?.setCamera(
          CameraOptions(
            center: _miPuntoActual,
            bearing: _bearingCamaraActual,
            zoom: _zoomCamaraActual,
            pitch: _pitchCamaraActual,
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _limpiarRutaVieja() async {
    final layers = [
      "ruta-shadow",
      "ruta-conexion",
      "ruta-casing",
      "ruta-inner",
      "ruta-flechas",
      "ruta-trafico-low",
      "ruta-trafico-moderate",
      "ruta-trafico-heavy",
      "ruta-trafico-severe",
    ];
    final sources = [
      "ruta-source-conexion",
      "ruta-source-main",
      "ruta-trafico-low",
      "ruta-trafico-moderate",
      "ruta-trafico-heavy",
      "ruta-trafico-severe",
    ];

    for (var l in layers) {
      try {
        if (await _mapboxMap!.style.styleLayerExists(l))
          await _mapboxMap!.style.removeStyleLayer(l);
      } catch (_) {}
    }
    for (var s in sources) {
      try {
        if (await _mapboxMap!.style.styleSourceExists(s))
          await _mapboxMap!.style.removeStyleSource(s);
      } catch (_) {}
    }

    if (_pinesAnnotations.isNotEmpty) {
      for (var ann in _pinesAnnotations) {
        try {
          await _pointManager?.delete(ann);
        } catch (_) {}
      }
      _pinesAnnotations.clear();
    }
  }

  Future<void> _agregarCapaRutaSegura(Layer layer) async {
    if (_mapboxMap == null) return;
    try {
      if (await _mapboxMap!.style.styleLayerExists("capa-ancla-rutas")) {
        await _mapboxMap!.style
            .addLayerAt(layer, LayerPosition(below: "capa-ancla-rutas"));
      } else {
        await _mapboxMap!.style.addLayer(layer);
      }
    } catch (_) {
      try {
        await _mapboxMap!.style.addLayer(layer);
      } catch (_) {}
    }
  }

  Map<String, dynamic> _lineStringData(List<Position> coords) {
    return {
      "type": "Feature",
      "geometry": {
        "type": "LineString",
        "coordinates":
            coords.map((c) => [c.lng.toDouble(), c.lat.toDouble()]).toList()
      }
    };
  }

  Map<String, List<List<List<double>>>> _buildTrafficLines() {
    final trafficLines = <String, List<List<List<double>>>>{
      "low": [],
      "moderate": [],
      "heavy": [],
      "severe": []
    };

    if (_congestionActual.isNotEmpty && _rutaActualCoords.length > 1) {
      for (int i = 0; i < _rutaActualCoords.length - 1; i++) {
        String level =
            (i < _congestionActual.length) ? _congestionActual[i] : "low";
        if (!trafficLines.containsKey(level)) level = "low";
        trafficLines[level]!.add([
          [
            _rutaActualCoords[i].lng.toDouble(),
            _rutaActualCoords[i].lat.toDouble()
          ],
          [
            _rutaActualCoords[i + 1].lng.toDouble(),
            _rutaActualCoords[i + 1].lat.toDouble()
          ]
        ]);
      }
    } else if (_rutaActualCoords.length > 1) {
      trafficLines["low"]!.add(_rutaActualCoords
          .map((c) => [c.lng.toDouble(), c.lat.toDouble()])
          .toList());
    }

    return trafficLines;
  }

  Future<void> _actualizarDatosRutaEnNavegacion() async {
    if (_mapboxMap == null || _rutaActualCoords.length < 2) return;

    try {
      const mainSourceId = "ruta-source-main";
      if (!await _mapboxMap!.style.styleSourceExists(mainSourceId)) {
        await _renderizarCapasRutaLocal(esOverview: false);
        return;
      }

      await _mapboxMap!.style.setStyleSourceProperty(
          mainSourceId, "data", jsonEncode(_lineStringData(_rutaActualCoords)));

      final trafficLines = _buildTrafficLines();
      for (final entry in trafficLines.entries) {
        final sourceId = "ruta-trafico-${entry.key}";
        if (!await _mapboxMap!.style.styleSourceExists(sourceId)) {
          await _renderizarCapasRutaLocal(esOverview: false);
          return;
        }
        await _mapboxMap!.style.setStyleSourceProperty(
            sourceId,
            "data",
            jsonEncode({
              "type": "Feature",
              "geometry": {
                "type": "MultiLineString",
                "coordinates": entry.value
              }
            }));
      }
    } catch (_) {
      await _renderizarCapasRutaLocal(esOverview: false);
    }
  }

  Future<void> _recortarRutaVisibleEn(Position posicionVisual) async {
    if (_rutaActualCoords.length < 2 || _actualizandoRutaVisible) return;

    _actualizandoRutaVisible = true;
    try {
      double distanciaMasCorta = double.infinity;
      int segmentoMasCercano = 0;
      Position? puntoMasCercano;

      for (int i = 0; i < _rutaActualCoords.length - 1; i++) {
        final projected = _proyectarEnSegmento(
          posicionVisual.lat.toDouble(),
          posicionVisual.lng.toDouble(),
          _rutaActualCoords[i],
          _rutaActualCoords[i + 1],
        );
        final dist = geo.Geolocator.distanceBetween(
          posicionVisual.lat.toDouble(),
          posicionVisual.lng.toDouble(),
          projected.lat.toDouble(),
          projected.lng.toDouble(),
        );
        if (dist < distanciaMasCorta) {
          distanciaMasCorta = dist;
          segmentoMasCercano = i;
          puntoMasCercano = projected;
        }
      }

      if (puntoMasCercano == null ||
          distanciaMasCorta > _rerouteDistanceMeters) {
        return;
      }

      final restantes = <Position>[
        puntoMasCercano,
        ..._rutaActualCoords.sublist(segmentoMasCercano + 1)
      ];

      if (restantes.length < 2) return;

      _rutaActualCoords = restantes;
      if (segmentoMasCercano > 0 && _congestionActual.isNotEmpty) {
        final hasta = segmentoMasCercano.clamp(0, _congestionActual.length);
        _congestionActual.removeRange(0, hasta);
      }
      // La ruta visible empieza en la posición realmente renderizada del carro,
      // no en el target GPS que la animación aún no ha alcanzado.
      _segmentoActualIdx = 0;
      await _actualizarDatosRutaEnNavegacion();
    } finally {
      _actualizandoRutaVisible = false;
    }
  }

  Future<void> _dibujarRutaPro(Position destino,
      {bool esOverview = false, Position? paradaIntermedia}) async {
    if (_mapboxMap == null || _miPuntoActual == null) return;
    _calculandoRuta = true;
    final origenRuta =
        _gpsCrudoActual?.coordinates ?? _miPuntoActual!.coordinates;
    debugPrint(
        '[ruta] estado=$_estadoViaje overview=$esOverview taxi=(${origenRuta.lat},${origenRuta.lng}) destino=(${destino.lat},${destino.lng}) parada=${paradaIntermedia != null ? "(${paradaIntermedia.lat},${paradaIntermedia.lng})" : "—"}');

    String coordsStr =
        '${origenRuta.lng.toDouble()},${origenRuta.lat.toDouble()}';

    if (paradaIntermedia != null) {
      coordsStr +=
          ';${paradaIntermedia.lng.toDouble()},${paradaIntermedia.lat.toDouble()}';
    }
    coordsStr += ';${destino.lng.toDouble()},${destino.lat.toDouble()}';

    String profile = esOverview ? 'driving' : 'driving-traffic';
    String extra = esOverview ? "" : "&annotations=congestion";

    final url = Uri.parse(
        '${Environment.mapboxDirectionsUrl}/$profile/$coordsStr?geometries=geojson&overview=full&steps=true&language=es&alternatives=false&continue_straight=true$extra&access_token=${Environment.mapboxToken}');
    final resp = await http.get(url);

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final route = data['routes'][0];
      final coords = (route['geometry']['coordinates'] as List)
          .map((c) => Position(c[0].toDouble(), c[1].toDouble()))
          .toList();
      final steps = route['legs'][0]['steps'] as List;

      _rutaActualCoords = coords;
      _segmentoActualIdx = 0;
      if (!esOverview && _estadoViaje > 0) {
        final snap =
            _snapToRoute(origenRuta.lat.toDouble(), origenRuta.lng.toDouble());
        if (snap != null) {
          _miPuntoActual = Point(coordinates: snap.pos);
          _headingActual = snap.bearing;
          _carroPosVisible = snap.pos;
          _carroBearingVisible = snap.bearing;
          await _renderCarroSnapped(snap.pos, snap.bearing);
        }
      }

      if (!esOverview) {
        final List<dynamic>? rawC =
            route['legs'][0]['annotation']?['congestion'];
        _congestionActual =
            rawC?.map((e) => e?.toString() ?? 'low').toList() ?? [];
      } else {
        _congestionActual = [];
      }

      if (mounted) {
        setState(() {
          _kmRuta = (route['distance'] / 1000).toStringAsFixed(1);
          _minRuta = (route['duration'] / 60).round();
          if (steps.length > 1) {
            final nextM = steps[1]['maneuver'];
            _siguienteManiobraCoords = Position(nextM['location'][0].toDouble(),
                nextM['location'][1].toDouble());
            if (_instruccionNavegacion != nextM['instruction']) {
              _instruccionNavegacion = nextM['instruction'];
              _iconoNavegacion =
                  _obtenerIconoDeModificador(nextM['modifier'] ?? '');
              if (!esOverview) _hablarInstruccion(_instruccionNavegacion);
            }
          }
        });
      }

      await _renderizarCapasRutaLocal(
          esOverview: esOverview,
          destino: destino,
          paradaIntermedia: paradaIntermedia,
          moverCamara: true);
    } else {
      debugPrint('[ruta] error status=${resp.statusCode} body=${resp.body}');
    }
    _calculandoRuta = false;
  }

  Future<void> _renderizarCapasRutaLocal(
      {required bool esOverview,
      Position? destino,
      Position? paradaIntermedia,
      bool moverCamara = false}) async {
    if (_rutaActualCoords.length < 2) return;

    await _limpiarRutaVieja();

    // La línea punteada de conexión solo tiene sentido en overview (antes de aceptar).
    // En navegación, el carro debe estar siempre sobre la ruta — cualquier rastro detrás se ve raro.
    if (esOverview) {
      final origenRuta =
          _gpsCrudoActual?.coordinates ?? _miPuntoActual!.coordinates;
      double dI = geo.Geolocator.distanceBetween(
          origenRuta.lat.toDouble(),
          origenRuta.lng.toDouble(),
          _rutaActualCoords.first.lat.toDouble(),
          _rutaActualCoords.first.lng.toDouble());
      if (dI > 10.0) {
        final cSourceId = "ruta-source-conexion";
        await _mapboxMap!.style.addSource(GeoJsonSource(
            id: cSourceId,
            data: jsonEncode({
              "type": "Feature",
              "geometry": {
                "type": "LineString",
                "coordinates": [
                  [origenRuta.lng.toDouble(), origenRuta.lat.toDouble()],
                  [
                    _rutaActualCoords.first.lng.toDouble(),
                    _rutaActualCoords.first.lat.toDouble()
                  ]
                ]
              }
            })));
        await _agregarCapaRutaSegura(LineLayer(
            id: "ruta-conexion",
            sourceId: cSourceId,
            lineColor: 0xFF64748B.toInt(),
            lineWidth: 5.0,
            lineDasharray: [1.0, 2.0],
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND));
      }
    }

    final mainSourceId = "ruta-source-main";
    await _mapboxMap!.style.addSource(GeoJsonSource(
        id: mainSourceId,
        data: jsonEncode(_lineStringData(_rutaActualCoords))));

    await _agregarCapaRutaSegura(LineLayer(
      id: "ruta-shadow",
      sourceId: mainSourceId,
      lineColor: 0xFF000000.toInt(),
      lineWidth: esOverview ? 16.0 : 26.0,
      lineBlur: esOverview ? 8.0 : 12.0,
      lineOpacity: 0.35,
      lineJoin: LineJoin.ROUND,
      lineCap: LineCap.ROUND,
    ));

    if (esOverview) {
      await _agregarCapaRutaSegura(LineLayer(
          id: "ruta-casing",
          sourceId: mainSourceId,
          lineColor: 0xFF101820.toInt(),
          lineWidth: 10.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND));
      await _agregarCapaRutaSegura(LineLayer(
          id: "ruta-inner",
          sourceId: mainSourceId,
          lineColor: 0xFF4A4A4A.toInt(),
          lineWidth: 5.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND));
    } else {
      await _agregarCapaRutaSegura(LineLayer(
          id: "ruta-casing",
          sourceId: mainSourceId,
          lineColor: 0xFF101820.toInt(),
          lineWidth: 18.0,
          lineJoin: LineJoin.ROUND,
          lineCap: LineCap.ROUND));

      final trafficLines = _buildTrafficLines();

      // Normal: azul. Algo congestionado: amarillo. Congestionado: rojo.
      final tColors = {
        "low": 0xFF2563EB.toInt(),
        "moderate": 0xFFFACC15.toInt(),
        "heavy": 0xFFEF4444.toInt(),
        "severe": 0xFFEF4444.toInt()
      };
      for (String key in trafficLines.keys) {
        if (trafficLines[key]!.isEmpty) continue;
        final sId = "ruta-trafico-$key";
        await _mapboxMap!.style.addSource(GeoJsonSource(
            id: sId,
            data: jsonEncode({
              "type": "Feature",
              "geometry": {
                "type": "MultiLineString",
                "coordinates": trafficLines[key]
              }
            })));
        await _agregarCapaRutaSegura(LineLayer(
            id: sId,
            sourceId: sId,
            lineColor: tColors[key],
            lineWidth: 10.0,
            lineJoin: LineJoin.ROUND,
            lineCap: LineCap.ROUND));
      }

      await _agregarCapaRutaSegura(SymbolLayer(
          id: "ruta-flechas",
          sourceId: mainSourceId,
          iconImage: "arrow",
          symbolPlacement: SymbolPlacement.LINE,
          iconSize: 0.5,
          symbolSpacing: 150.0,
          iconAllowOverlap: true,
          iconIgnorePlacement: true));
    }

    if (destino != null) {
      if (esOverview) {
        if (_puntoInicioConexionBytes != null)
          _pinesAnnotations.add(await _pointManager!.create(
              PointAnnotationOptions(
                  geometry: Point(
                      coordinates: Position(
                          _rutaActualCoords.first.lng.toDouble(),
                          _rutaActualCoords.first.lat.toDouble())),
                  image: _puntoInicioConexionBytes)));
        if (paradaIntermedia != null && _dotVerdeBytes != null)
          _pinesAnnotations.add(await _pointManager!.create(
              PointAnnotationOptions(
                  geometry: Point(
                      coordinates: Position(paradaIntermedia.lng.toDouble(),
                          paradaIntermedia.lat.toDouble())),
                  image: _dotVerdeBytes)));
        if (_dotRojoBytes != null)
          _pinesAnnotations.add(await _pointManager!.create(
              PointAnnotationOptions(
                  geometry: Point(
                      coordinates: Position(
                          destino.lng.toDouble(), destino.lat.toDouble())),
                  image: _dotRojoBytes)));
      } else {
        Uint8List? img = _estadoViaje == 3 ? _dotRojoBytes : _dotVerdeBytes;
        if (img != null)
          _pinesAnnotations.add(await _pointManager!.create(
              PointAnnotationOptions(
                  geometry: Point(
                      coordinates: Position(
                          destino.lng.toDouble(), destino.lat.toDouble())),
                  image: img)));
      }
    }

    // Reaplicar puck/carro según estado actual
    await _actualizarPuckSegunEstado();

    if (moverCamara) {
      if (esOverview) {
        _mapboxMap?.flyTo(
            await _mapboxMap!.cameraForGeometry(
                LineString(coordinates: _rutaActualCoords).toJson(),
                MbxEdgeInsets(top: 150, left: 60, bottom: 400, right: 60),
                0,
                0),
            MapAnimationOptions(duration: 1000));
      } else {
        _mapboxMap?.easeTo(
            CameraOptions(
                center: _miPuntoActual,
                bearing: _headingActual,
                pitch: _pitchCamaraActual,
                zoom: _zoomCamaraActual),
            MapAnimationOptions(duration: 800));
      }
    }
  }

  IconData _obtenerIconoDeModificador(String modifier) {
    if (modifier.contains('left')) return Icons.turn_left_rounded;
    if (modifier.contains('right')) return Icons.turn_right_rounded;
    if (modifier.contains('u-turn')) return Icons.u_turn_left_rounded;
    return Icons.straight_rounded;
  }

  void _limpiarMapaYCentrar() async {
    PushNotificationService().cancelNavigationReturnNotification();
    _rutaActualCoords.clear();
    _destinoActual = null;
    _siguienteManiobraCoords = null;
    _ultimaPosicionProcesada = null;
    _congestionActual.clear();
    await _limpiarRutaVieja();
    setState(() {
      _estadoViaje = 0;
      _viajeActivo = null;
      _isTrackingCamera = true;
      _ultimaInstruccionHablada = "";
    });
    if (_gpsIniciado) await _actualizarPuckSegunEstado();
    _flutterTts.stop();
    if (_gpsIniciado) _centrarUbicacionInicial();
  }

  Future<void> _handleSlideSubmit() async {
    if (_estadoViaje == 1) {
      await PushNotificationService().cancelNavigationReturnNotification();
      setState(() => _estadoViaje = 2);
      _slideKeyLlegar.currentState?.reset();
    } else {
      String? tarifaFinal =
          await _locationService.finalizarViaje(_viajeActivo!['id'].toString());

      if (tarifaFinal != null) {
        final rideId = _viajeActivo!['id'].toString();
        if (!mounted) return;
        bool pagoConfirmado = await ModalCobro.mostrar(context, tarifaFinal);

        if (pagoConfirmado) {
          if (!mounted) return;
          final rating = await ModalRatingCliente.mostrar(context);
          if (rating != null) {
            final error =
                await _locationService.calificarCliente(rideId, rating);
            if (error != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            }
          }

          widget.onEstadoViajeChanged?.call(false);
          await PushNotificationService().cancelNavigationReturnNotification();
          setState(() {
            _estadoViaje = 0;
            _viajeActivo = null;
            _limpiarMapaYCentrar();
          });
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Error al finalizar: verifica que el viaje esté en curso")),
        );
        _slideKeyFinalizar.currentState?.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Listener(
          onPointerDown: (_) => _pausarSeguimientoCamara(),
          child: MapWidget(
              onMapCreated: _onMapCreated,
              cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(-74.08, 4.60)),
                  zoom: 15.5)),
        ),
        if (_estadoViaje == 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 15,
            child: BotonGlass(
              icono: Icons.menu_rounded,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        BannerSuperior(
            estadoViaje: _estadoViaje,
            instruccionNavegacion: _instruccionNavegacion,
            distanciaManiobra: _distanciaManiobra,
            iconoNavegacion: _iconoNavegacion,
            sonidoActivado: _sonidoActivado,
            colorAcento: const Color(0xFFFFD54F),
            panelExpandido: _panelExpandido,
            onToggleSonido: () {
              setState(() => _sonidoActivado = !_sonidoActivado);
              if (!_sonidoActivado) _flutterTts.stop();
            }),
        Velocimetro(
            estadoViaje: _estadoViaje,
            panelExpandido: _panelExpandido,
            velocidadActual: _velocidadActual),
        PanelInferior(
          estadoViaje: _estadoViaje,
          viajeActivo: _viajeActivo,
          minRuta: _minRuta,
          kmRuta: _kmRuta,
          panelExpandido: _panelExpandido,
          colorAcento: const Color(0xFFFFD54F),
          slideKeyLlegar: _slideKeyLlegar,
          slideKeyFinalizar: _slideKeyFinalizar,
          onTogglePanel: () =>
              setState(() => _panelExpandido = !_panelExpandido),
          onNavigationPressed: _mostrarOpcionesNavegacion,
          chatUnreadCount: _chatUnreadCount,
          onChatPressed: () {
            if (_viajeActivo != null) {
              _abrirChat(_viajeActivo!['id'].toString());
            }
          },
          onCancelPressed: () {
            if (_viajeActivo != null) {
              ModalCancelacion.mostrar(context, _viajeActivo!['id'].toString(),
                  () {
                widget.onEstadoViajeChanged?.call(false);
                setState(() {
                  _estadoViaje = 0;
                  _viajeActivo = null;
                  _limpiarMapaYCentrar();
                });
              });
            }
          },
          onPinCompleted: (pin) async {
            String resultado = await _locationService.verificarCodigoViaje(
                _viajeActivo!['id'].toString(), pin);

            if (resultado == "OK") {
              await PushNotificationService()
                  .cancelNavigationReturnNotification();
              setState(() {
                _estadoViaje = 3;
                _panelExpandido = false;
                _isTrackingCamera = true;
              });
              _destinoActual = Position(
                  _viajeActivo!['destination']['lng'].toDouble(),
                  _viajeActivo!['destination']['lat'].toDouble());
              await _dibujarRutaPro(_destinoActual!, esOverview: false);
              if (mounted) unawaited(_mostrarOpcionesNavegacion());
            } else {
              ModalErrorGlass.mostrar(context, resultado);
            }
          },
          onSlideSubmit: _handleSlideSubmit,
        ),
        if (_estadoViaje == 0)
          Positioned(
            right: 15,
            bottom: MediaQuery.of(context).padding.bottom + 205,
            child: _BotonesCamaraMapa(
              vista3D: _vista3D,
              isTrackingCamera: _isTrackingCamera,
              onToggleVista: () {
                setState(() => _vista3D = !_vista3D);
                _aplicarCamaraActual(durationMs: 850, seguir: true);
              },
              onCentrar: () {
                _aplicarCamaraActual(durationMs: 700, seguir: true);
              },
            ),
          )
        else
          Positioned(
            right: 15,
            bottom: _panelExpandido ? 280 : 150,
            child: _BotonesCamaraMapa(
              vista3D: _vista3D,
              isTrackingCamera: _isTrackingCamera,
              onToggleVista: () {
                setState(() => _vista3D = !_vista3D);
                _aplicarCamaraActual(durationMs: 850, seguir: true);
              },
              onCentrar: () {
                _aplicarCamaraActual(durationMs: 700, seguir: true);
              },
            ),
          ),
      ],
    );
  }
}

enum _NavigationApp { waze, googleMaps }

class _BotonesCamaraMapa extends StatelessWidget {
  final bool vista3D;
  final bool isTrackingCamera;
  final VoidCallback onToggleVista;
  final VoidCallback onCentrar;

  const _BotonesCamaraMapa({
    required this.vista3D,
    required this.isTrackingCamera,
    required this.onToggleVista,
    required this.onCentrar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BotonGlass(
          icono: vista3D ? Icons.map_rounded : Icons.view_in_ar_rounded,
          colorIcono: vista3D ? const Color(0xFFFFB700) : Colors.black87,
          onPressed: onToggleVista,
        ),
        const SizedBox(height: 14),
        BotonGlass(
          icono:
              isTrackingCamera ? Icons.near_me_rounded : Icons.near_me_outlined,
          colorIcono:
              isTrackingCamera ? const Color(0xFFFFB700) : Colors.black87,
          onPressed: onCentrar,
        ),
      ],
    );
  }
}
