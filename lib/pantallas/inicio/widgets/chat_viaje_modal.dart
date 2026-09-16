// lib/pantallas/inicio/widgets/chat_viaje_modal.dart

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../global/environment.dart';
import '../../../services/driver_location_service.dart';

class MensajeChat {
  final String texto;
  final bool esMio;
  MensajeChat({required this.texto, required this.esMio});
}

class ChatViajeModal extends StatefulWidget {
  final String rideId;
  final double height;
  const ChatViajeModal({super.key, required this.rideId, required this.height});

  static Future<void> mostrar(BuildContext context, String rideId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final viewQuery = MediaQueryData.fromView(View.of(context));
        final keyboardHeight = viewQuery.viewInsets.bottom;
        final topSafeArea = viewQuery.padding.top;
        final maxAvailableHeight =
            viewQuery.size.height - topSafeArea - keyboardHeight - 12;
        final safeMaxHeight =
            maxAvailableHeight.clamp(220.0, viewQuery.size.height).toDouble();
        final modalHeight = (viewQuery.size.height * 0.70)
            .clamp(220.0, safeMaxHeight)
            .toDouble();

        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: ChatViajeModal(
            rideId: rideId,
            height: modalHeight,
          ),
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  State<ChatViajeModal> createState() => _ChatViajeModalState();
}

class _ChatViajeModalState extends State<ChatViajeModal> {
  WebSocketChannel? _canal;
  final TextEditingController _controladorMensaje = TextEditingController();
  final ScrollController _controladorScroll = ScrollController();
  final List<MensajeChat> _mensajes = [];
  final List<String> _mensajesPendientesEco = [];
  bool _conectando = false;
  bool _cargandoHistorial = true;
  bool _wsConectado = false;

  @override
  void initState() {
    super.initState();
    DriverLocationService().chatActivoRideId = widget.rideId;
    _cargarHistorial();
    _conectarWebSocket();
  }

  Future<void> _cargarHistorial() async {
    try {
      final response = await http.get(
        Uri.parse('${Environment.apiUrl}/ride/${widget.rideId}/messages'),
        headers: {
          'Content-Type': 'application/json',
          if (Environment.driverToken.isNotEmpty)
            'Authorization': 'Bearer ${Environment.driverToken}',
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final mensajes = data is List ? data : const [];
        setState(() {
          _mensajes
            ..clear()
            ..addAll(mensajes.map((item) {
              final json = Map<String, dynamic>.from(item as Map);
              return MensajeChat(
                texto: json['text']?.toString() ?? '',
                esMio: json['senderType'] == 'DRIVER',
              );
            }));
          _cargandoHistorial = false;
        });
        _hacerScrollAbajo();
      } else {
        setState(() => _cargandoHistorial = false);
        debugPrint(
            '[chat] historial status=${response.statusCode} body=${response.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoHistorial = false);
      debugPrint('[chat] error cargando historial: $e');
    }
  }

  void _conectarWebSocket() {
    if (_conectando) return;
    _conectando = true;

    final url = '${Environment.wsApiUrl}/ws/rides/${widget.rideId}/chat';
    _canal = WebSocketChannel.connect(Uri.parse(url));

    _canal!.stream.listen(
      (data) {
        _conectando = false;
        _wsConectado = true;
        if (mounted) {
          try {
            // DECODIFICAR EL JSON PARA EXTRAER SOLO EL TEXTO
            final Map<String, dynamic> decoded = jsonDecode(data.toString());
            final texto = decoded['text']?.toString() ?? '';
            final esMio = decoded['senderType'] == 'DRIVER';
            if (esMio && _mensajesPendientesEco.remove(texto)) {
              return;
            }
            setState(() {
              _mensajes.add(MensajeChat(texto: texto, esMio: esMio));
            });
            _hacerScrollAbajo();
          } catch (e) {
            debugPrint("Error al procesar mensaje: $e");
          }
        }
      },
      onError: (error) {
        debugPrint('[chat] websocket error: $error');
        _reintentar();
      },
      onDone: () => _reintentar(),
    );
  }

  void _reintentar() {
    _conectando = false;
    if (mounted) {
      Timer(const Duration(seconds: 3), () => _conectarWebSocket());
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _controladorMensaje.text.trim();
    if (texto.isEmpty) return;

    _controladorMensaje.clear();
    setState(() {
      _mensajes.add(MensajeChat(texto: texto, esMio: true));
    });
    _hacerScrollAbajo();

    var enviadoPorWs = false;
    if (_canal != null && _wsConectado) {
      try {
        _mensajesPendientesEco.add(texto);
        _canal!.sink.add(texto);
        enviadoPorWs = true;
      } catch (e) {
        _mensajesPendientesEco.remove(texto);
        debugPrint('[chat] error enviando por websocket: $e');
      }
    }

    if (!enviadoPorWs) {
      await _enviarMensajeHttp(texto);
    }
  }

  Future<void> _enviarMensajeHttp(String texto) async {
    try {
      final response = await http
          .post(
            Uri.parse('${Environment.apiUrl}/ride/${widget.rideId}/messages'),
            headers: {
              'Content-Type': 'application/json',
              if (Environment.driverToken.isNotEmpty)
                'Authorization': 'Bearer ${Environment.driverToken}',
            },
            body: jsonEncode({'text': texto}),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '[chat] envio http status=${response.statusCode} body=${response.body}');
      }
    } catch (e) {
      debugPrint('[chat] error enviando por http: $e');
    }
  }

  void _hacerScrollAbajo() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_controladorScroll.hasClients) {
        _controladorScroll.animateTo(
            _controladorScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    if (DriverLocationService().chatActivoRideId == widget.rideId) {
      DriverLocationService().chatActivoRideId = null;
    }
    _canal?.sink.close();
    _controladorMensaje.dispose();
    _controladorScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: Row(
              children: [
                const CircleAvatar(
                    backgroundColor: Color(0xFFE0E0E0),
                    child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 15),
                const Expanded(
                  child: Text("Chat con Pasajero",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.pop(context);
                  },
                )
              ],
            ),
          ),

          // Mensajes
          Expanded(
            child: _cargandoHistorial
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFFD54F),
                    ),
                  )
                : ListView.builder(
                    controller: _controladorScroll,
                    padding: const EdgeInsets.all(15),
                    itemCount: _mensajes.length,
                    itemBuilder: (context, index) => _burbuja(_mensajes[index]),
                  ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(25)),
                      child: TextField(
                        controller: _controladorMensaje,
                        decoration: const InputDecoration(
                            hintText: "Escribe un mensaje...",
                            border: InputBorder.none),
                        onSubmitted: (_) => _enviarMensaje(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFFFD54F),
                    child: IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.black87, size: 20),
                        onPressed: _enviarMensaje),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _burbuja(MensajeChat msj) {
    return Align(
      alignment: msj.esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: msj.esMio ? const Color(0xFFFFD54F) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Text(msj.texto,
            style: const TextStyle(color: Colors.black87, fontSize: 15)),
      ),
    );
  }
}
