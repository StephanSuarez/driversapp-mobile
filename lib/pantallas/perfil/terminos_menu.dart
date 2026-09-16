// lib/pantallas/perfil/terminos_menu.dart

import 'package:flutter/material.dart';

class TerminosMenu extends StatefulWidget {
  const TerminosMenu({super.key});

  @override
  State<TerminosMenu> createState() => _TerminosMenuState();
}

class _TerminosMenuState extends State<TerminosMenu> {
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        setState(() {
          _readingProgress = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color amarilloDriversApp = Color(0xFFFFD600);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: amarilloDriversApp,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "MARCO LEGAL",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * _readingProgress,
              height: 3.0,
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Cabecera
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 30),
              decoration: BoxDecoration(
                color: amarilloDriversApp.withOpacity(0.08),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.gavel_rounded, color: Color(0xFFC4A500), size: 48),
                  SizedBox(height: 18),
                  Text(
                    "Términos y Condiciones",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "CONTRATO DE ADHESIÓN • CONDUCTORES",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFC4A500),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
              child: Column(
                children: [
                  _seccionLegal(
                    "01. Aceptación de los Términos",
                    "Al descargar, registrarse y utilizar la aplicación para conductores de DriversApp (en adelante, \"la App\"), usted (en adelante, \"el Conductor\") acepta estar sujeto a estos Términos y Condiciones. DriversApp opera bajo un modelo donde los usuarios (pasajeros) solicitan el servicio exclusivamente a través de WhatsApp, y dichas solicitudes son canalizadas hacia esta App, la cual es de uso exclusivo para los conductores registrados.",
                  ),
                  _seccionLegal(
                    "02. Naturaleza del Servicio",
                    "DriversApp es una plataforma tecnológica de intermediación que facilita la conexión entre usuarios que solicitan viajes vía WhatsApp y conductores independientes. DriversApp no provee servicios de transporte por sí misma ni actúa como una empresa de transportes. La relación entre DriversApp y el Conductor es estrictamente comercial y tecnológica; no existe relación laboral, de subordinación o dependencia.",
                  ),
                  _seccionLegal(
                    "03. Recepción y Gestión de Viajes",
                    "El Conductor recibirá en la App las solicitudes de servicio que los usuarios generen a través del canal oficial de WhatsApp de DriversApp. El Conductor tiene total autonomía para conectarse, desconectarse, aceptar o rechazar las solicitudes. Sin embargo, al aceptar un viaje, se compromete a cumplirlo de manera oportuna, respetando la tarifa y el destino acordado.",
                  ),
                  _seccionLegal(
                    "04. Requisitos y Obligaciones del Conductor",
                    "Para utilizar la plataforma, el Conductor garantiza y se compromete a:\n• Ser mayor de edad y contar con plena capacidad legal.\n• Poseer una licencia de conducción vigente y apta para el tipo de vehículo registrado.\n• Mantener actualizada y veraz toda la documentación requerida obligatoriamente en la App (foto de perfil, tarjeta de propiedad, licencia de conducción, tarjeta de control de taxi y fotos del vehículo).\n• Mantener el vehículo en óptimas condiciones mecánicas, de seguridad e higiene.\n• Contar con los seguros obligatorios vigentes exigidos por la ley.",
                  ),
                  _seccionLegal(
                    "05. Uso de la Plataforma y Geolocalización",
                    "El Conductor acepta que la App accederá a su ubicación GPS en tiempo real mientras se encuentre \"En línea\". Esto es estrictamente necesario para:\n• Asignar los viajes solicitados por los usuarios en WhatsApp según cercanía.\n• Compartir el tiempo estimado de llegada y la ruta en vivo con el pasajero a través de WhatsApp.\n• Monitorear la seguridad integral del recorrido.",
                  ),
                  _seccionLegal(
                    "06. Tarifas, Pagos y Membresías",
                    "• El acceso y uso de la App por parte del Conductor está sujeto al pago anticipado de una membresía (según los planes y periodos establecidos en la plataforma).\n• Al mantener su membresía activa, el Conductor tendrá el derecho de recibir y gestionar las solicitudes de viaje provenientes de WhatsApp.\n• DriversApp no cobra comisiones porcentuales por cada viaje realizado. El modelo de negocio se basa de manera exclusiva en el pago de la membresía por el uso del software.\n• El Conductor cobrará directamente al pasajero, en efectivo o por el medio acordado, la tarifa exacta calculada por el sistema e informada previamente al usuario en la solicitud de WhatsApp.",
                  ),
                  _seccionLegal(
                    "07. Comportamiento y Calidad del Servicio",
                    "El Conductor se compromete a tratar a todos los usuarios con respeto y cortesía. Cualquier queja, reclamo o reporte de mala conducta recibido a través de la línea de WhatsApp de los usuarios podrá ser motivo de revisión y sanción.",
                  ),
                  _seccionLegal(
                    "08. Privacidad y Protección de Datos",
                    "DriversApp recopilará, almacenará y procesará los datos personales del Conductor con el fin exclusivo de operar el servicio tecnológico, conectar los viajes con WhatsApp y garantizar la seguridad. El tratamiento de estos datos se realiza conforme a nuestra Política de Privacidad y las leyes aplicables.",
                  ),
                  _seccionLegal(
                    "09. Suspensión de la Cuenta",
                    "DriversApp se reserva el derecho de suspender o inhabilitar permanentemente la cuenta del Conductor de la App, sin derecho a reembolso de la membresía pagada, en caso de:\n• Incumplimiento de estos Términos y Condiciones.\n• Reportes graves de seguridad, acoso o fraude por parte de los usuarios en WhatsApp.\n• Uso de documentos falsos, vencidos o suplantación de identidad.\n• Cobros indebidos o alteración intencional de las rutas.",
                  ),
                  _seccionLegal(
                    "10. Modificaciones",
                    "DriversApp podrá modificar estos Términos en cualquier momento. Las actualizaciones serán notificadas a través de la App. El uso continuado de la aplicación tras dicha notificación constituye la aceptación de los nuevos términos.",
                  ),

                  const SizedBox(height: 40),
                  const Divider(color: Colors.black12),
                  const SizedBox(height: 20),
                  const Text(
                    "DriversApp © 2026 - Todos los derechos reservados.\nLa seguridad es nuestro compromiso.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seccionLegal(String titulo, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 5,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            texto,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black.withOpacity(0.7),
              height: 1.6,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
