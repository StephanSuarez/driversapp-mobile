import 'package:flutter/material.dart';

import '../../services/notification_center_service.dart';

class NotificacionesPantalla extends StatefulWidget {
  const NotificacionesPantalla({super.key});

  @override
  State<NotificacionesPantalla> createState() => _NotificacionesPantallaState();
}

class _NotificacionesPantallaState extends State<NotificacionesPantalla> {
  final NotificationCenterService _service = NotificationCenterService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.listar();
  }

  void _recargar() {
    setState(() => _future = _service.listar());
  }

  void _mensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  String _estadoLegible(String? actionStatus) {
    switch (actionStatus?.toUpperCase()) {
      case 'ACCEPTED':
        return 'Aceptada';
      case 'REJECTED':
        return 'Rechazada';
      default:
        return '';
    }
  }

  Future<void> _resolver(String id, bool aceptar) async {
    final error =
        aceptar ? await _service.aceptar(id) : await _service.rechazar(id);
    if (!mounted) return;
    _mensaje(
        error ?? (aceptar ? 'Solicitud aceptada.' : 'Solicitud rechazada.'));
    if (error == null) _recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _recargar,
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
            final notificaciones = snapshot.data ?? [];
            if (notificaciones.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.notifications_none_rounded,
                      size: 72, color: Colors.black26),
                  SizedBox(height: 18),
                  Text(
                    'No tienes notificaciones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notificaciones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = notificaciones[index];
                final id = item['id']?.toString() ?? '';
                final actionStatus =
                    item['action_status']?.toString().toUpperCase();
                final pending = actionStatus == 'PENDING';
                final statusText = _estadoLegible(actionStatus);
                final readAt = item['read_at'];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (id.isNotEmpty) _service.marcarLeida(id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                readAt == null
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_none_rounded,
                                color: readAt == null
                                    ? const Color(0xFFFFD600)
                                    : Colors.black38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['title']?.toString() ?? 'Notificación',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item['body']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          if (pending && id.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _resolver(id, false),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Rechazar'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _resolver(id, true),
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Aceptar'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (statusText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: actionStatus == 'ACCEPTED'
                                    ? const Color(0xFFE1F5EA)
                                    : const Color(0xFFFDE6E6),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: actionStatus == 'ACCEPTED'
                                      ? const Color(0xFF0B8F55)
                                      : const Color(0xFFC62828),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
