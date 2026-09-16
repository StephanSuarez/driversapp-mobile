import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/driver_location_service.dart';
import '../../services/notification_center_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/app_top_toast.dart';

class MisVehiculosPantalla extends StatefulWidget {
  const MisVehiculosPantalla({super.key});

  @override
  State<MisVehiculosPantalla> createState() => _MisVehiculosPantallaState();
}

class _MisVehiculosPantallaState extends State<MisVehiculosPantalla> {
  final VehicleService _vehicleService = VehicleService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _vehicleService.listarVehiculos();
    NotificationCenterService.changes.addListener(_recargar);
  }

  @override
  void dispose() {
    NotificationCenterService.changes.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    setState(() => _future = _vehicleService.listarVehiculos());
  }

  Future<void> _abrirRegistro() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _RegistrarVehiculoPantalla()),
    );
    if (creado == true) _recargar();
  }

  Future<void> _solicitarPorPlaca() async {
    final placa = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => const _SolicitarVehiculoSheet(),
    );
    if (placa == null || placa.isEmpty) return;

    final error = await _vehicleService.solicitarVehiculoPorPlaca(placa);
    if (!mounted) return;
    AppTopToast.show(
      context,
      message: error ?? 'Solicitud enviada al propietario.',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
    if (error == null) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text('Mis vehículos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Solicitar por placa',
            icon: const Icon(Icons.manage_search_rounded),
            onPressed: _solicitarPorPlaca,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _recargar(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final vehiculos = snapshot.data ?? [];
            if (vehiculos.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.local_taxi_rounded,
                      size: 72, color: Colors.black26),
                  const SizedBox(height: 18),
                  const Text(
                    'Todavía no tienes vehículos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _abrirRegistro,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar vehículo'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _solicitarPorPlaca,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Solicitar por placa'),
                  ),
                ],
              );
            }
            final propios = vehiculos
                .where((vehicle) => vehicle['is_owner'] == true)
                .toList();
            final asociados = vehiculos
                .where((vehicle) => vehicle['is_owner'] != true)
                .toList();
            Map<String, dynamic>? activo;
            for (final vehicle in vehiculos) {
              final availability =
                  vehicle['availability_status']?.toString().toUpperCase();
              if (availability == 'IN_USE_BY_ME') {
                activo = vehicle;
                break;
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (activo != null) ...[
                  _VehiculoActivoBanner(vehicle: activo),
                  const SizedBox(height: 18),
                ] else ...[
                  const _SinVehiculoActivoBanner(),
                  const SizedBox(height: 18),
                ],
                _VehicleSection(
                  title: 'A mi nombre',
                  subtitle: 'Vehículos que registraste como propietario.',
                  emptyText: 'No tienes vehículos propios registrados.',
                  vehicles: propios,
                  onChanged: _recargar,
                ),
                const SizedBox(height: 18),
                _VehicleSection(
                  title: 'Asociados',
                  subtitle:
                      'Vehículos que puedes conducir cuando estén aprobados.',
                  emptyText: 'No tienes vehículos asociados todavía.',
                  vehicles: asociados,
                  onChanged: _recargar,
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirRegistro,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar'),
      ),
    );
  }
}

class _SolicitarVehiculoSheet extends StatefulWidget {
  const _SolicitarVehiculoSheet();

  @override
  State<_SolicitarVehiculoSheet> createState() =>
      _SolicitarVehiculoSheetState();
}

class _SolicitarVehiculoSheetState extends State<_SolicitarVehiculoSheet> {
  final _controller = TextEditingController();
  final _placaFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized =
        newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  });

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enviar() {
    final placa = _controller.text.trim().toUpperCase();
    if (placa.isEmpty) return;
    Navigator.pop(context, placa);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.manage_search_rounded,
                      color: Colors.black),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitar vehículo',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Busca la placa y envía una solicitud al propietario.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [_placaFormatter],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _enviar(),
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                labelText: 'Placa del taxi',
                hintText: 'ABC123',
                prefixIcon: const Icon(Icons.local_taxi_rounded),
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _enviar,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Solicitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final List<Map<String, dynamic>> vehicles;
  final VoidCallback onChanged;

  const _VehicleSection({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.vehicles,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 10),
        if (vehicles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: Text(
              emptyText,
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          ...vehicles.map(
            (vehicle) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VehiculoTile(vehicle: vehicle, onChanged: onChanged),
            ),
          ),
      ],
    );
  }
}

class _VehiculoTile extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onChanged;

  const _VehiculoTile({
    required this.vehicle,
    required this.onChanged,
  });

  bool get _isOwner => vehicle['is_owner'] == true;

  @override
  Widget build(BuildContext context) {
    final placa = vehicle['vehicle_plate']?.toString() ?? 'Sin placa';
    final order = vehicle['order_number']?.toString();
    final status = vehicle['relationship_status']?.toString() ?? '';
    final verified = vehicle['verified'] == true;
    final availability =
        vehicle['availability_status']?.toString().toUpperCase() ?? 'AVAILABLE';
    final activeDriver = vehicle['active_driver_name']?.toString();
    final inUseByMe = availability == 'IN_USE_BY_ME';
    final inUseByOther = availability == 'IN_USE_BY_OTHER';
    final assigned = vehicle['assigned_drivers'];
    final drivers =
        assigned is List ? assigned.whereType<Map>().toList() : <Map>[];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: inUseByMe ? const Color(0xFFFFF8D6) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: inUseByMe ? const Color(0xFFFFD600) : Colors.transparent,
            width: inUseByMe ? 2 : 0,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inUseByMe) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.key_rounded,
                          color: Color(0xFFFFD600), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vehículo que estás usando ahora',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      placa,
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _EstadoChip(
                    text: verified ? 'Validado' : 'Pendiente',
                    color: verified
                        ? const Color(0xFF0B8F55)
                        : const Color(0xFFB07900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _EstadoChip(
                text: inUseByMe
                    ? 'En uso por mí'
                    : inUseByOther
                        ? 'En uso por ${activeDriver == null || activeDriver.isEmpty ? 'otro conductor' : activeDriver}'
                        : verified
                            ? 'Disponible'
                            : 'No validado',
                color: inUseByMe
                    ? Colors.black
                    : inUseByOther
                        ? const Color(0xFF1359A8)
                        : availability == 'AVAILABLE'
                            ? const Color(0xFF555555)
                            : const Color(0xFFB07900),
              ),
              if (order != null && order.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Número de orden: $order',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
              if (status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Relación: $status',
                    style: const TextStyle(color: Colors.black54)),
              ],
              const SizedBox(height: 12),
              if (_isOwner)
                _OwnerActions(
                    vehicle: vehicle, drivers: drivers, onChanged: onChanged)
              else
                const Text(
                  'Este vehículo está asociado a tu cuenta cuando el propietario acepte la solicitud.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehiculoActivoBanner extends StatelessWidget {
  final Map<String, dynamic> vehicle;

  const _VehiculoActivoBanner({required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final placa = vehicle['vehicle_plate']?.toString() ?? 'Sin placa';
    final order = vehicle['order_number']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_taxi_rounded, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vehículo en uso ahora',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order == null || order.isEmpty
                      ? placa
                      : '$placa · Orden $order',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFFFFD600), size: 28),
        ],
      ),
    );
  }
}

class _SinVehiculoActivoBanner extends StatelessWidget {
  const _SinVehiculoActivoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E4E4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.black45),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No tienes un vehículo en uso. Al conectarte, debes escoger cuál manejarás en esta jornada.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final List<Map> drivers;
  final VoidCallback onChanged;

  const _OwnerActions({
    required this.vehicle,
    required this.drivers,
    required this.onChanged,
  });

  Future<void> _invitar(BuildContext context) async {
    final documento = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => const _InvitarConductorSheet(),
    );
    if (documento == null || documento.isEmpty) return;
    final error = await VehicleService().invitarConductor(
      vehicleId: vehicle['id']?.toString() ?? '',
      documento: documento,
    );
    if (!context.mounted) return;
    AppTopToast.show(
      context,
      message: error ?? 'Invitación enviada al conductor.',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
    if (error == null) onChanged();
  }

  Future<void> _retirar(BuildContext context, Map driver) async {
    final driverId = driver['driver_id']?.toString();
    if (driverId == null || driverId.isEmpty) return;
    final error = await VehicleService().retirarConductor(
      vehicleId: vehicle['id']?.toString() ?? '',
      driverId: driverId,
    );
    if (!context.mounted) return;
    AppTopToast.show(
      context,
      message: error ?? 'Conductor retirado.',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
    if (error == null) onChanged();
  }

  Future<void> _resolverSolicitud(
    BuildContext context,
    Map driver,
    bool aceptar,
  ) async {
    final notificationId = driver['notification_id']?.toString();
    if (notificationId == null || notificationId.isEmpty) return;
    final service = NotificationCenterService();
    final error = aceptar
        ? await service.aceptar(notificationId)
        : await service.rechazar(notificationId);
    if (!context.mounted) return;
    AppTopToast.show(
      context,
      message:
          error ?? (aceptar ? 'Solicitud aceptada.' : 'Solicitud rechazada.'),
      type: error == null ? AppToastType.success : AppToastType.error,
    );
    if (error == null) onChanged();
  }

  Future<void> _liberar(BuildContext context) async {
    final availability =
        vehicle['availability_status']?.toString().toUpperCase() ?? 'AVAILABLE';
    final isMyActiveVehicle = availability == 'IN_USE_BY_ME';
    final error = await VehicleService().liberarVehiculo(
      vehicleId: vehicle['id']?.toString() ?? '',
    );
    if (!context.mounted) return;
    if (error == null && isMyActiveVehicle) {
      DriverLocationService().detenerJornadaLocal();
    }
    AppTopToast.show(
      context,
      message: error ??
          (isMyActiveVehicle
              ? 'Vehículo liberado y jornada finalizada.'
              : 'Vehículo liberado.'),
      type: error == null ? AppToastType.success : AppToastType.error,
    );
    if (error == null) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final availability =
        vehicle['availability_status']?.toString().toUpperCase() ?? 'AVAILABLE';
    final inUse =
        availability == 'IN_USE_BY_ME' || availability == 'IN_USE_BY_OTHER';
    final pendingDrivers = drivers
        .where(
            (driver) => driver['status']?.toString().toUpperCase() == 'PENDING')
        .toList();
    final activeDrivers = drivers
        .where(
            (driver) => driver['status']?.toString().toUpperCase() == 'ACTIVE')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _invitar(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Invitar'),
            ),
            if (inUse) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _liberar(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Liberar'),
              ),
            ],
          ],
        ),
        if (pendingDrivers.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Solicitudes pendientes',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...pendingDrivers.map((driver) {
            final requestType =
                driver['request_type']?.toString().toUpperCase();
            final canResolve = requestType == 'DRIVER_REQUEST' &&
                (driver['notification_id']?.toString().isNotEmpty ?? false);
            final subtitle = canResolve
                ? 'Quiere manejar este vehículo'
                : 'Invitación enviada al conductor';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8D6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD600)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_search_rounded,
                          color: Colors.black87),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driver['full_name']?.toString() ??
                                  driver['id_document']?.toString() ??
                                  'Conductor',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (canResolve)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _resolverSolicitud(context, driver, false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Rechazar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _resolverSolicitud(context, driver, true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Aceptar'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD600)),
                      ),
                      child: const Text(
                        'Pendiente de respuesta',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
        if (activeDrivers.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Conductores asociados',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          ...activeDrivers.map((driver) {
            final status = driver['status']?.toString() ?? '';
            final isOwner = driver['driver_id']?.toString() ==
                vehicle['owner_id']?.toString();
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_rounded),
              title: Text(driver['full_name']?.toString() ??
                  driver['id_document']?.toString() ??
                  'Conductor'),
              subtitle: Text(status),
              trailing: isOwner
                  ? null
                  : IconButton(
                      tooltip: 'Retirar conductor',
                      icon: const Icon(Icons.person_remove_alt_1_rounded),
                      onPressed: () => _retirar(context, driver),
                    ),
            );
          }),
        ],
      ],
    );
  }
}

class _InvitarConductorSheet extends StatefulWidget {
  const _InvitarConductorSheet();

  @override
  State<_InvitarConductorSheet> createState() => _InvitarConductorSheetState();
}

class _InvitarConductorSheetState extends State<_InvitarConductorSheet> {
  final _controller = TextEditingController();
  bool _mostrarError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enviar() {
    final documento = _controller.text.trim();
    if (documento.isEmpty) {
      setState(() => _mostrarError = true);
      return;
    }
    Navigator.pop(context, documento);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 14, 22, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitar conductor',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Enviaremos una solicitud para que la acepte.',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_mostrarError) setState(() => _mostrarError = false);
              },
              onSubmitted: (_) => _enviar(),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                labelText: 'Documento de identidad',
                errorText:
                    _mostrarError ? 'Ingresa el documento del conductor' : null,
                prefixIcon: const Icon(Icons.badge_rounded),
                filled: true,
                fillColor: const Color(0xFFF6F6F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide:
                      const BorderSide(color: Color(0xFFFFD600), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black26),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _enviar,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Enviar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrarVehiculoPantalla extends StatefulWidget {
  const _RegistrarVehiculoPantalla();

  @override
  State<_RegistrarVehiculoPantalla> createState() =>
      _RegistrarVehiculoPantallaState();
}

class _RegistrarVehiculoPantallaState
    extends State<_RegistrarVehiculoPantalla> {
  final _placaController = TextEditingController();
  final _ordenController = TextEditingController();
  final _placaFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized =
        newValue.text.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  });
  final _authService = AuthService();
  final _vehicleService = VehicleService();

  bool _guardando = false;
  File? _propiedadFrente;
  File? _propiedadReverso;
  File? _frontal;
  File? _lateral;
  File? _trasera;

  @override
  void dispose() {
    _placaController.dispose();
    _ordenController.dispose();
    super.dispose();
  }

  Future<void> _abrirTarjeta(_TarjetaPropiedadLado lado) async {
    final placa = _placaController.text.trim().toUpperCase();
    if (placa.isEmpty) {
      _mensaje('Ingresa la placa antes de validar la tarjeta.');
      return;
    }

    final file = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => _CapturaTarjetaPropiedadRegistroPantalla(
          lado: lado,
          placa: placa,
          imagenInicial: lado == _TarjetaPropiedadLado.frontal
              ? _propiedadFrente
              : _propiedadReverso,
        ),
      ),
    );
    if (file == null) return;
    setState(() {
      if (lado == _TarjetaPropiedadLado.frontal) {
        _propiedadFrente = file;
      } else {
        _propiedadReverso = file;
      }
    });
  }

  Future<void> _abrirFotosTaxi() async {
    final fotos = await Navigator.push<_FotosTaxiResultado>(
      context,
      MaterialPageRoute(
        builder: (_) => _CapturaFotosTaxiRegistroPantalla(
          frontal: _frontal,
          lateral: _lateral,
          trasera: _trasera,
        ),
      ),
    );
    if (fotos == null) return;
    setState(() {
      _frontal = fotos.frontal;
      _lateral = fotos.lateral;
      _trasera = fotos.trasera;
    });
  }

  Future<String> _subir(File file, String nombre) async {
    final url = await _authService.subirArchivo(file);
    if (url == null || url.isEmpty) {
      throw Exception('No se pudo subir $nombre.');
    }
    return url;
  }

  Future<void> _guardar() async {
    final placa = _placaController.text.trim().toUpperCase();
    final orden = _ordenController.text.trim();
    if (placa.isEmpty ||
        orden.isEmpty ||
        _propiedadFrente == null ||
        _propiedadReverso == null ||
        _frontal == null ||
        _lateral == null ||
        _trasera == null) {
      _mensaje('Completa los datos y todas las fotos del vehículo.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final propiedadFrente =
          await _subir(_propiedadFrente!, 'tarjeta de propiedad frontal');
      final propiedadReverso =
          await _subir(_propiedadReverso!, 'tarjeta de propiedad posterior');
      final frontal = await _subir(_frontal!, 'foto frontal');
      final lateral = await _subir(_lateral!, 'foto lateral');
      final trasera = await _subir(_trasera!, 'foto trasera');
      final error = await _vehicleService.registrarVehiculo(
        placa: placa,
        numeroOrden: orden,
        tarjetaPropiedad: [propiedadFrente, propiedadReverso],
        fotosVehiculo: [frontal, lateral, trasera],
      );
      if (!mounted) return;
      if (error != null) {
        setState(() => _guardando = false);
        _mensaje(error);
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mensaje(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _mensaje(String mensaje) {
    AppTopToast.show(context, message: mensaje, type: AppToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Registrar vehículo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600),
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.local_taxi_rounded, color: Colors.black),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del taxi',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Placa, tarjeta de propiedad y fotos del vehículo',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _placaController,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_placaFormatter],
            decoration: const InputDecoration(
              labelText: 'Placa',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ordenController,
            decoration: const InputDecoration(
              labelText: 'Número de orden',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 22),
          const _RegistroSeccionTitulo(
            titulo: 'Tarjeta de propiedad',
            subtitulo: 'Carga ambas caras del documento del vehículo.',
          ),
          const SizedBox(height: 10),
          _PhotoRow(
            title: 'Tarjeta propiedad frontal',
            subtitle: 'Cara principal',
            file: _propiedadFrente,
            onTap: () => _abrirTarjeta(_TarjetaPropiedadLado.frontal),
          ),
          _PhotoRow(
            title: 'Tarjeta propiedad posterior',
            subtitle: 'Reverso del documento',
            file: _propiedadReverso,
            onTap: () => _abrirTarjeta(_TarjetaPropiedadLado.posterior),
          ),
          const SizedBox(height: 12),
          const _RegistroSeccionTitulo(
            titulo: 'Fotos del taxi',
            subtitulo: 'Frontal, lateral y parte trasera del vehículo.',
          ),
          const SizedBox(height: 10),
          _PhotoRow(
            title: 'Taxi frontal',
            subtitle: 'Parte delantera',
            file: _frontal,
            onTap: _abrirFotosTaxi,
          ),
          _PhotoRow(
            title: 'Taxi lateral',
            subtitle: 'Vista de costado',
            file: _lateral,
            onTap: _abrirFotosTaxi,
          ),
          _PhotoRow(
            title: 'Taxi atrás',
            subtitle: 'Parte trasera',
            file: _trasera,
            onTap: _abrirFotosTaxi,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              style: FilledButton.styleFrom(backgroundColor: Colors.black),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Guardar vehículo'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TarjetaPropiedadLado { frontal, posterior }

class _CapturaTarjetaPropiedadRegistroPantalla extends StatefulWidget {
  final _TarjetaPropiedadLado lado;
  final String placa;
  final File? imagenInicial;

  const _CapturaTarjetaPropiedadRegistroPantalla({
    required this.lado,
    required this.placa,
    this.imagenInicial,
  });

  @override
  State<_CapturaTarjetaPropiedadRegistroPantalla> createState() =>
      _CapturaTarjetaPropiedadRegistroPantallaState();
}

class _CapturaTarjetaPropiedadRegistroPantallaState
    extends State<_CapturaTarjetaPropiedadRegistroPantalla> {
  final _picker = ImagePicker();
  File? _imagen;
  bool _procesando = false;

  bool get _esFrontal => widget.lado == _TarjetaPropiedadLado.frontal;

  @override
  void initState() {
    super.initState();
    _imagen = widget.imagenInicial;
    _recuperarImagenPerdida();
  }

  Future<void> _procesar(ImageSource source) async {
    if (_procesando) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1100,
      maxHeight: 1100,
      imageQuality: 76,
      requestFullMetadata: false,
    );
    if (picked == null) return;

    await _procesarArchivo(File(picked.path));
  }

  Future<void> _recuperarImagenPerdida() async {
    try {
      final response = await _picker.retrieveLostData();
      final picked = response.file;
      if (response.isEmpty || picked == null) return;
      await _procesarArchivo(File(picked.path));
    } catch (_) {
      // Android no siempre tiene datos pendientes; es normal.
    }
  }

  Future<void> _procesarArchivo(File file) async {
    setState(() => _procesando = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final text = await recognizer.processImage(InputImage.fromFile(file));
      final raw = text.text.toUpperCase();
      final limpio = raw.replaceAll(RegExp(r'[\s\-]'), '');
      final placa =
          widget.placa.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

      if (raw.contains('CONDUCCION') || raw.contains('CONDUCCIÓN')) {
        _mostrarError(
          'Documento incorrecto',
          'Parece una licencia de conducción. Sube la tarjeta de propiedad del vehículo.',
          Icons.credit_card_off_rounded,
          Colors.red,
        );
        return;
      }

      final pareceTarjeta = raw.contains('TRANSITO') ||
          raw.contains('TRÁNSITO') ||
          raw.contains('PROPIEDAD') ||
          raw.contains('VEHICULO') ||
          raw.contains('VEHÍCULO') ||
          raw.contains('LICENCIA DE TRÁNSITO') ||
          raw.contains('LICENCIA DE TRANSITO') ||
          raw.contains('PLACA');

      if (!pareceTarjeta) {
        _mostrarError(
          'Documento no detectado',
          'No parece una tarjeta de propiedad. Toma la foto completa, nítida y bien iluminada.',
          Icons.find_in_page_rounded,
          Colors.orange,
        );
        return;
      }

      if (_esFrontal && !limpio.contains(placa)) {
        _mostrarError(
          'La placa no coincide',
          'La tarjeta debe corresponder al vehículo ${widget.placa}.',
          Icons.directions_car_filled_rounded,
          Colors.red,
        );
        return;
      }

      setState(() => _imagen = file);
      if (!mounted) return;
      AppTopToast.show(
        context,
        message: 'Tarjeta validada.',
        type: AppToastType.success,
      );
    } catch (_) {
      _mostrarError(
        'No se pudo validar',
        'Intenta con una imagen más clara o tomada de frente.',
        Icons.error_outline_rounded,
        Colors.red,
      );
    } finally {
      recognizer.close();
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _mostrarError(
    String titulo,
    String mensaje,
    IconData icono,
    Color color,
  ) {
    if (!mounted) return;
    _CaptureAlert.show(
      context,
      titulo: titulo,
      mensaje: mensaje,
      icono: icono,
      color: color,
    );
  }

  void _continuar() {
    if (_imagen == null) {
      _mostrarError(
        'Foto requerida',
        'Carga y valida esta cara de la tarjeta para continuar.',
        Icons.add_a_photo_rounded,
        Colors.black,
      );
      return;
    }
    Navigator.pop(context, _imagen);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = _esFrontal ? 'TARJETA FRONTAL' : 'TARJETA POSTERIOR';
    final descripcion = _esFrontal
        ? 'Sube la cara principal de la tarjeta de propiedad.'
        : 'Sube el reverso de la tarjeta de propiedad.';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _CircleBackButton(onTap: () => Navigator.pop(context)),
              ),
              const SizedBox(height: 28),
              _CaptureIconBubble(
                icon: Icons.badge_rounded,
                image: _imagen,
                aspectRatio: 1.58,
              ),
              const SizedBox(height: 28),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF252020),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _esFrontal
                    ? 'Nota: debe verse completa y coincidir con la placa ${widget.placa}.'
                    : 'Nota: asegúrate de que el texto del documento sea legible.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF252020),
                ),
              ),
              const SizedBox(height: 28),
              if (_procesando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: CircularProgressIndicator(color: Colors.black),
                )
              else ...[
                _CaptureActionButton(
                  label: 'Galería',
                  icon: Icons.photo_library_rounded,
                  onTap: () => _procesar(ImageSource.gallery),
                ),
                const SizedBox(height: 14),
                _CaptureActionButton(
                  label: 'Cámara',
                  icon: Icons.camera_alt_rounded,
                  onTap: () => _procesar(ImageSource.camera),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: FilledButton(
                  onPressed: _procesando ? null : _continuar,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'SIGUIENTE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Image.asset(
                'assets/imagenes/logito.png',
                height: 76,
                errorBuilder: (_, __, ___) => const Text(
                  'driversapp',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _FotoTaxiTipo { frontal, lateral, trasera }

class _FotosTaxiResultado {
  final File? frontal;
  final File? lateral;
  final File? trasera;

  const _FotosTaxiResultado({
    required this.frontal,
    required this.lateral,
    required this.trasera,
  });
}

class _CapturaFotosTaxiRegistroPantalla extends StatefulWidget {
  final File? frontal;
  final File? lateral;
  final File? trasera;

  const _CapturaFotosTaxiRegistroPantalla({
    this.frontal,
    this.lateral,
    this.trasera,
  });

  @override
  State<_CapturaFotosTaxiRegistroPantalla> createState() =>
      _CapturaFotosTaxiRegistroPantallaState();
}

class _CapturaFotosTaxiRegistroPantallaState
    extends State<_CapturaFotosTaxiRegistroPantalla> {
  final _picker = ImagePicker();
  late final ImageLabeler _labeler;
  File? _frontal;
  File? _lateral;
  File? _trasera;
  bool _procesando = false;
  _FotoTaxiTipo? _ultimoTipoSolicitado;

  @override
  void initState() {
    super.initState();
    _frontal = widget.frontal;
    _lateral = widget.lateral;
    _trasera = widget.trasera;
    _labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    _recuperarImagenPerdida();
  }

  @override
  void dispose() {
    _labeler.close();
    super.dispose();
  }

  Future<void> _tomarFoto(ImageSource source, _FotoTaxiTipo tipo) async {
    if (_procesando) return;
    _ultimoTipoSolicitado = tipo;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1100,
      maxHeight: 1100,
      imageQuality: 76,
      requestFullMetadata: false,
    );
    if (picked == null) return;

    await _procesarFotoTaxi(File(picked.path), tipo);
  }

  Future<void> _recuperarImagenPerdida() async {
    try {
      final response = await _picker.retrieveLostData();
      final picked = response.file;
      final tipo = _ultimoTipoSolicitado;
      if (response.isEmpty || picked == null || tipo == null) return;
      await _procesarFotoTaxi(File(picked.path), tipo);
    } catch (_) {
      // No hay imagen pendiente que recuperar.
    }
  }

  Future<void> _procesarFotoTaxi(File file, _FotoTaxiTipo tipo) async {
    setState(() => _procesando = true);

    try {
      final labels = await _labeler.processImage(InputImage.fromFile(file));
      if (!_esVehiculo(labels)) {
        if (!mounted) return;
        _CaptureAlert.show(
          context,
          titulo: 'Vehículo no detectado',
          mensaje:
              'Asegúrate de que el taxi esté completo, centrado y bien iluminado.',
          icono: Icons.directions_car_filled_rounded,
          color: Colors.orange,
        );
        return;
      }

      setState(() {
        switch (tipo) {
          case _FotoTaxiTipo.frontal:
            _frontal = file;
            break;
          case _FotoTaxiTipo.lateral:
            _lateral = file;
            break;
          case _FotoTaxiTipo.trasera:
            _trasera = file;
            break;
        }
      });
      if (!mounted) return;
      AppTopToast.show(
        context,
        message: 'Foto del taxi validada.',
        type: AppToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      _CaptureAlert.show(
        context,
        titulo: 'No se pudo validar',
        mensaje: 'Intenta con otra imagen del vehículo.',
        icono: Icons.error_outline_rounded,
        color: Colors.red,
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  bool _esVehiculo(List<ImageLabel> labels) {
    const keys = [
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
      'Bumper',
      'Automotive exterior',
      'License plate',
      'Headlamp',
      'Door',
      'Window',
      'Windshield',
      'Mirror',
    ];
    return labels.any((label) {
      final value = label.label;
      return keys.contains(value) ||
          value.contains('Car') ||
          value.contains('Vehicle') ||
          value.contains('Auto');
    });
  }

  void _continuar() {
    if (_frontal == null || _lateral == null || _trasera == null) {
      _CaptureAlert.show(
        context,
        titulo: 'Faltan fotos',
        mensaje: 'Carga las fotos frontal, lateral y trasera del taxi.',
        icono: Icons.add_a_photo_rounded,
        color: Colors.black,
      );
      return;
    }
    Navigator.pop(
      context,
      _FotosTaxiResultado(
        frontal: _frontal,
        lateral: _lateral,
        trasera: _trasera,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.45,
                child: Image.asset(
                  'assets/imagenes/fondo_w.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child:
                        _CircleBackButton(onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(height: 24),
                  Image.asset(
                    'assets/imagenes/taxi_icono.png',
                    height: 70,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_taxi_rounded,
                      size: 70,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'VEHÍCULO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.3,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sube las fotos del taxi en sus espacios correspondientes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _TaxiPhotoBox(
                        title: 'FRONTAL',
                        file: _frontal,
                        enabled: !_procesando,
                        onGallery: () => _tomarFoto(
                            ImageSource.gallery, _FotoTaxiTipo.frontal),
                        onCamera: () => _tomarFoto(
                            ImageSource.camera, _FotoTaxiTipo.frontal),
                      ),
                      _TaxiPhotoBox(
                        title: 'TRASERA',
                        file: _trasera,
                        enabled: !_procesando,
                        onGallery: () => _tomarFoto(
                            ImageSource.gallery, _FotoTaxiTipo.trasera),
                        onCamera: () => _tomarFoto(
                            ImageSource.camera, _FotoTaxiTipo.trasera),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _TaxiPhotoBox(
                    title: 'LATERAL',
                    file: _lateral,
                    enabled: !_procesando,
                    onGallery: () =>
                        _tomarFoto(ImageSource.gallery, _FotoTaxiTipo.lateral),
                    onCamera: () =>
                        _tomarFoto(ImageSource.camera, _FotoTaxiTipo.lateral),
                  ),
                  const SizedBox(height: 30),
                  if (_procesando)
                    const CircularProgressIndicator(color: Colors.black)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        onPressed: _continuar,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'CONTINUAR',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiPhotoBox extends StatelessWidget {
  final String title;
  final File? file;
  final bool enabled;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _TaxiPhotoBox({
    required this.title,
    required this.file,
    required this.enabled,
    required this.onGallery,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final ok = file != null;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ok ? const Color(0xFF19B371) : Colors.black26,
                  width: ok ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: file == null
                  ? Center(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.black45,
                        ),
                      ),
                    )
                  : Image.file(file!, fit: BoxFit.cover),
            ),
            if (ok)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF19B371),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _SmallCaptureButton(
          label: 'Galería',
          enabled: enabled,
          onTap: onGallery,
        ),
        const SizedBox(height: 6),
        _SmallCaptureButton(
          label: 'Cámara',
          enabled: enabled,
          onTap: onCamera,
        ),
      ],
    );
  }
}

class _SmallCaptureButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _SmallCaptureButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      height: 34,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _CaptureIconBubble extends StatelessWidget {
  final IconData icon;
  final File? image;
  final double aspectRatio;

  const _CaptureIconBubble({
    required this.icon,
    required this.image,
    this.aspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 224,
      height: 224 / aspectRatio,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(aspectRatio == 1 ? 120 : 24),
        border: Border.all(color: const Color(0xFFFFEA00), width: 5),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Icon(icon, color: const Color(0xFF78909C), size: 72)
          : Image.file(image!, fit: BoxFit.cover),
    );
  }
}

class _CaptureActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CaptureActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.black, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
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

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CircleBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F1DE),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 54,
          height: 54,
          child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
        ),
      ),
    );
  }
}

class _CaptureAlert {
  static void show(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required IconData icono,
    required Color color,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) {
        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.84,
                padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                decoration: BoxDecoration(
                  color: const Color(0xF7FFFFFF),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icono, color: color, size: 38),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      mensaje,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }
}

class _RegistroSeccionTitulo extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const _RegistroSeccionTitulo({
    required this.titulo,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitulo,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? file;
  final VoidCallback onTap;

  const _PhotoRow({
    required this.title,
    required this.subtitle,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(18),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 76,
              height: 58,
              color: Colors.white,
              child: file == null
                  ? const Icon(Icons.camera_alt_rounded, color: Colors.black38)
                  : Image.file(file!, fit: BoxFit.cover),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            file == null
                ? Icons.chevron_right_rounded
                : Icons.check_circle_rounded,
            color: file == null ? Colors.black26 : const Color(0xFF0B8F55),
          ),
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String text;
  final Color color;

  const _EstadoChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
