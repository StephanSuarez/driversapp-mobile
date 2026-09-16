// lib/pantallas/inicio/widgets/panel_inferior.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:pinput/pinput.dart';

class PanelInferior extends StatelessWidget {
  final int estadoViaje;
  final Map<String, dynamic>? viajeActivo;
  final int minRuta;
  final String kmRuta;
  final bool panelExpandido;
  final Color colorAcento;
  final VoidCallback onTogglePanel;
  final VoidCallback onNavigationPressed;
  final VoidCallback onChatPressed;
  final int chatUnreadCount;
  final VoidCallback onCancelPressed;
  final Function(String) onPinCompleted;
  final Future<void> Function() onSlideSubmit;

  // estas llaves son las que controlan que el boton no se quede pegado
  final GlobalKey<SlideActionState> slideKeyLlegar;
  final GlobalKey<SlideActionState> slideKeyFinalizar;

  const PanelInferior({
    super.key,
    required this.estadoViaje,
    required this.viajeActivo,
    required this.minRuta,
    required this.kmRuta,
    required this.panelExpandido,
    required this.colorAcento,
    required this.onTogglePanel,
    required this.onNavigationPressed,
    required this.onChatPressed,
    required this.chatUnreadCount,
    required this.onCancelPressed,
    required this.onPinCompleted,
    required this.onSlideSubmit,
    required this.slideKeyLlegar,
    required this.slideKeyFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    if (estadoViaje == 0 || viajeActivo == null) return const SizedBox.shrink();

    final String horaLlegada = DateFormat('h:mm a')
        .format(DateTime.now().add(Duration(minutes: minRuta)));

    // cambiamos el texto dependiendo de si vamos por el cliente o al destino
    final String direccion = (estadoViaje < 3)
        ? (viajeActivo!['origin']['place_name'] ?? "Punto de recogida")
        : (viajeActivo!['destination']['place_name'] ?? "Destino final");

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
                top: panelExpandido ? 10 : 0,
                left: 18,
                right: 18,
                bottom: MediaQuery.of(context).padding.bottom +
                    (panelExpandido ? 12 : 0)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(51),
                  Colors.white.withAlpha(13),
                ],
                stops: const [0.1, 1.0],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
              border:
                  Border.all(color: Colors.white.withAlpha(128), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 30,
                    offset: const Offset(0, -5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onTogglePanel,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 40,
                          height: 4,
                          margin: EdgeInsets.only(
                              top: panelExpandido ? 0 : 4,
                              bottom: panelExpandido ? 14 : 0),
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300.withAlpha(204),
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(204),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white.withAlpha(128),
                                      width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withAlpha(13),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/imagenes/logito.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.local_taxi_rounded,
                                          color: colorAcento, size: 24),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("$minRuta min",
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87,
                                          letterSpacing: -0.5)),
                                  Row(
                                    children: [
                                      Text("Llegada $horaLlegada",
                                          style: TextStyle(
                                              color: Colors.grey.shade800,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black87,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                                color:
                                                    Colors.black.withAlpha(26),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2))
                                          ],
                                        ),
                                        child: Text(
                                          "$kmRuta km",
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: colorAcento),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                                panelExpandido
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.keyboard_arrow_up_rounded,
                                color: Colors.black45,
                                size: 28),
                          ]),
                    ],
                  ),
                ),
                if (panelExpandido) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withAlpha(64),
                          Colors.white.withAlpha(13),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withAlpha(102), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            color: colorAcento, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(direccion,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Colors.black87),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.white.withAlpha(77),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side:
                                BorderSide(color: Colors.white.withAlpha(128)),
                          ),
                          child: InkWell(
                            onTap: onNavigationPressed,
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.navigation_rounded,
                                      color: Colors.black87, size: 16),
                                  SizedBox(width: 6),
                                  Text("Navegar",
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Material(
                          color: Colors.white.withAlpha(77),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                  color: Colors.white.withAlpha(128))),
                          child: InkWell(
                            onTap: () {
                              onChatPressed();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: Colors.black87,
                                          size: 16),
                                      if (chatUnreadCount > 0)
                                        Positioned(
                                          top: -8,
                                          right: -10,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 18, minHeight: 18),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 1.5),
                                            ),
                                            child: Text(
                                              chatUnreadCount > 9
                                                  ? "9+"
                                                  : "$chatUnreadCount",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  const Text("Mensaje",
                                      style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (estadoViaje < 3) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Material(
                            color: Colors.red.withAlpha(26),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                    color: Colors.red.withAlpha(51))),
                            child: InkWell(
                              onTap: onCancelPressed,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.close_rounded,
                                        color: Colors.red.shade700, size: 16),
                                    const SizedBox(width: 6),
                                    Text("Cancelar",
                                        style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (estadoViaje == 2)
                  Column(
                    children: [
                      const Text("CÓDIGO DE VERIFICACIÓN",
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54,
                              fontSize: 11,
                              letterSpacing: 1.0)),
                      const SizedBox(height: 8),
                      Pinput(
                        length: 4,
                        onCompleted: onPinCompleted,
                        defaultPinTheme: PinTheme(
                          width: 50,
                          height: 55,
                          textStyle: const TextStyle(
                              fontSize: 24,
                              color: Colors.black87,
                              fontWeight: FontWeight.w900),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(153),
                            border: Border.all(color: Colors.white, width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  )
                else if (panelExpandido)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.black.withAlpha(166),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(26),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: SlideAction(
                      key:
                          estadoViaje == 1 ? slideKeyLlegar : slideKeyFinalizar,
                      outerColor: Colors.transparent,
                      innerColor: colorAcento,
                      sliderButtonIcon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.black87,
                          size: 18),
                      submittedIcon: const Icon(Icons.check_rounded,
                          color: Colors.black87, size: 22),
                      text: estadoViaje == 1
                          ? "DESLIZA PARA LLEGAR"
                          : "FINALIZAR VIAJE",
                      textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2),
                      elevation: 0,
                      sliderRotate: false,
                      borderRadius: 100,
                      height: 50,
                      // Aquí está el arreglo: obligamos al botón a reiniciarse tras completar la animación
                      onSubmit: () async {
                        await onSlideSubmit();

                        if (estadoViaje == 1) {
                          slideKeyLlegar.currentState?.reset();
                        } else {
                          slideKeyFinalizar.currentState?.reset();
                        }
                        return null;
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
