import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/subscription_service.dart';
import '../../widgets/app_top_toast.dart';

const _driversappYellow = Color(0xFFFFD600);
const _ink = Color(0xFF1D171B);
const _muted = Color(0xFF776F75);
const _paper = Color(0xFFF6F5F2);
const _line = Color(0xFFE8E3DD);

class MembresiaPantalla extends StatefulWidget {
  const MembresiaPantalla({super.key});

  @override
  State<MembresiaPantalla> createState() => _MembresiaPantallaState();
}

class _MembresiaPantallaState extends State<MembresiaPantalla> {
  final _service = SubscriptionService();
  bool _loading = true;
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _history;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.estado(),
      _service.planes(),
      _service.historial(),
    ]);
    if (!mounted) return;
    setState(() {
      _status = results[0] as Map<String, dynamic>?;
      _plans = results[1] as List<Map<String, dynamic>>;
      _history = results[2] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _openPlan(Map<String, dynamic> plan) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MembershipPlanDetailScreen(
          plan: Map<String, dynamic>.from(plan),
          service: _service,
        ),
      ),
    );
    if (shouldRefresh == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paper,
      child: SafeArea(
        bottom: false,
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            color: _ink,
            decoration: TextDecoration.none,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _loading ? _buildLoading() : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      key: ValueKey('membership-loading'),
      child: CircularProgressIndicator(color: _ink),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      key: const ValueKey('membership-content'),
      color: _ink,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 34),
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _AnimatedEntrance(index: 0, child: _StatusCard(status: _status)),
          const SizedBox(height: 14),
          _AnimatedEntrance(
            index: 1,
            child:
                _MembershipSummary(status: _status, planCount: _plans.length),
          ),
          const SizedBox(height: 24),
          _sectionTitle('Planes disponibles'),
          const SizedBox(height: 7),
          const Text(
            'Elige una membresía para mantener activo tu acceso a DriversApp.',
            style: TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.25,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          if (_plans.isEmpty)
            _buildEmptyPlans()
          else
            ..._plans.asMap().entries.map(
                  (entry) => _AnimatedEntrance(
                    index: entry.key + 2,
                    child: _PlanSummaryCard(
                      plan: entry.value,
                      onTap: () => _openPlan(entry.value),
                    ),
                  ),
                ),
          const SizedBox(height: 22),
          _AnimatedEntrance(index: 7, child: _buildHistory()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final statusInfo = _MembershipStatusInfo.from(_status);
    return Row(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: _driversappYellow,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _driversappYellow.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: _ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Membresía',
                style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.02,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                statusInfo.headerCopy,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _ink,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        decoration: TextDecoration.none,
      ),
    );
  }

  Widget _buildEmptyPlans() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: const Text(
        'Todavía no hay planes activos. Intenta de nuevo en un momento.',
        style: TextStyle(
          color: _muted,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.35,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final invoices =
        (_history?['invoices'] as List?)?.whereType<Map>().toList() ?? [];
    if (invoices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Historial'),
        const SizedBox(height: 12),
        ...invoices.take(5).map((invoice) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(radius: 20),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _driversappYellow.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: _ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _invoiceStatus(invoice['status']),
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        invoice['due_at']?.toString() ?? 'Factura registrada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _money(invoice['total_cents']),
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MembershipPlanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plan;
  final SubscriptionService service;

  const _MembershipPlanDetailScreen({
    required this.plan,
    required this.service,
  });

  @override
  State<_MembershipPlanDetailScreen> createState() =>
      _MembershipPlanDetailScreenState();
}

class _MembershipPlanDetailScreenState
    extends State<_MembershipPlanDetailScreen> {
  final _promoController = TextEditingController();
  bool _paying = false;
  String _paymentMethod = 'NEQUI';
  Map<String, dynamic>? _promoPreview;

  int get _amountToPayCents {
    if (_promoPreview != null) return _intValue(_promoPreview?['total_cents']);
    return _intValue(widget.plan['price_cents']);
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _applyPromo() async {
    final planId = widget.plan['id']?.toString();
    final code = _promoController.text.trim().toUpperCase();
    if (planId == null || code.isEmpty) return;

    try {
      final preview =
          await widget.service.previewPromo(planId: planId, code: code);
      if (!mounted) return;
      setState(() {
        _promoController.text = code;
        _promoPreview = preview;
      });
      AppTopToast.show(
        context,
        message: 'Código aplicado.',
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _promoPreview = null);
      AppTopToast.show(
        context,
        message: e.toString(),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _pay() async {
    final planId = widget.plan['id']?.toString();
    if (planId == null || _paying) return;

    setState(() => _paying = true);
    try {
      final intent = await widget.service.crearIntentoPago(
        planId: planId,
        method: _paymentMethod,
        promotionCode: _promoController.text.trim().toUpperCase(),
      );
      if (!mounted) return;

      final checkoutUrl = intent?['checkout_url']?.toString();
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        AppTopToast.show(
          context,
          message: 'Pago creado. Revisaremos la confirmación.',
          type: AppToastType.info,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppTopToast.show(
        context,
        message: e.toString(),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final features = _planFeatures(plan);
    final duration = _intValue(plan['duration_days']);
    final trial = _intValue(plan['trial_days']);
    final grace = _intValue(plan['grace_days']);

    return Material(
      color: _paper,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailTopBar(title: 'Detalle del plan'),
                        const SizedBox(height: 18),
                        _AnimatedEntrance(
                          index: 0,
                          child: _PlanHeroCard(
                            plan: plan,
                            duration: duration,
                            trial: trial,
                            grace: grace,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AnimatedEntrance(
                          index: 1,
                          child: _BenefitsCard(features: features),
                        ),
                        const SizedBox(height: 18),
                        _AnimatedEntrance(
                          index: 2,
                          child: _buildPromoBox(),
                        ),
                        const SizedBox(height: 18),
                        _AnimatedEntrance(
                          index: 3,
                          child: _buildPaymentMethods(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBox() {
    final preview = _promoPreview;
    final hasCode = _promoController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: _driversappYellow.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_offer_rounded, color: _ink),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código promocional',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Aplícalo antes de pagar.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    decoration: TextDecoration.none,
                  ),
                  onChanged: (_) {
                    if (_promoPreview != null) {
                      setState(() => _promoPreview = null);
                    } else {
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'PROMO2026',
                    hintStyle: TextStyle(
                      color: _muted.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w800,
                    ),
                    filled: true,
                    fillColor: _paper,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: hasCode ? _driversappYellow : const Color(0xFFE6E2DD),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  onPressed: hasCode ? _applyPromo : null,
                  color: _ink,
                  disabledColor: _muted.withValues(alpha: 0.4),
                  icon: const Icon(Icons.check_rounded),
                ),
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: preview == null
                ? const SizedBox.shrink()
                : Padding(
                    key: const ValueKey('promo-preview'),
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F8EF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'Ahorras ${_money(preview['discount_cents'])}'
                        '${_intValue(preview['extra_days']) == 0 ? '' : ' y recibes ${_intValue(preview['extra_days'])} días extra'}',
                        style: const TextStyle(
                          color: Color(0xFF087A43),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    const methods = [
      ('NEQUI', 'Nequi', Icons.account_balance_wallet_rounded),
      ('PSE', 'PSE', Icons.account_balance_rounded),
      ('CARD', 'Tarjeta', Icons.credit_card_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medio de pago',
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: methods.map((item) {
              final selected = _paymentMethod == item.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = item.$1),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected ? _ink : _paper,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? _ink : _line,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            item.$3,
                            color: selected ? Colors.white : _ink,
                            size: 21,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.$2,
                            style: TextStyle(
                              color: selected ? Colors.white : _ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      decoration: BoxDecoration(
        color: _paper.withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: _line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _paying ? null : _pay,
        style: ElevatedButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFC6C0BA),
          minimumSize: const Size.fromHeight(60),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            _paying
                ? 'Preparando pago...'
                : 'Pagar ${_money(_amountToPayCents)}',
            key: ValueKey('pay-$_paying-$_amountToPayCents'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  final String title;

  const _DetailTopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(false),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _line),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _ink),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;

  const _PlanSummaryCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final features = _planFeatures(plan);
    final duration = _intValue(plan['duration_days']);
    final grace = _intValue(plan['grace_days']);
    final trial = _intValue(plan['trial_days']);
    final description = plan['description']?.toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: _driversappYellow,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.shield_rounded, color: _ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan['name']?.toString() ?? 'Plan DriversApp',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          description != null && description.isNotEmpty
                              ? description
                              : 'Acceso para operar y atender servicios.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _money(plan['price_cents']),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  _MiniPill(label: '$duration días'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (trial > 0) _MiniPill(label: '$trial días gratis'),
                  if (grace > 0) _MiniPill(label: '$grace días para renovar'),
                  if (trial == 0 && grace == 0)
                    const _MiniPill(label: 'Renovación simple'),
                ],
              ),
              if (features.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...features.take(2).map(_featureRow),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Ver detalle y pagar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanHeroCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final int duration;
  final int trial;
  final int grace;

  const _PlanHeroCard({
    required this.plan,
    required this.duration,
    required this.trial,
    required this.grace,
  });

  @override
  Widget build(BuildContext context) {
    final description = plan['description']?.toString().trim();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _driversappYellow,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _driversappYellow.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: _ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan['name']?.toString() ?? 'Plan DriversApp',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.3,
                decoration: TextDecoration.none,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            _money(plan['price_cents']),
            style: const TextStyle(
              color: _ink,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  value: '$duration',
                  label: 'días de acceso',
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricBox(
                  value: grace > 0
                      ? '$grace'
                      : trial > 0
                          ? '$trial'
                          : 'Sin',
                  label: grace > 0
                      ? 'días para renovar'
                      : trial > 0
                          ? 'días gratis'
                          : 'plazo extra',
                  icon: grace > 0
                      ? Icons.schedule_rounded
                      : trial > 0
                          ? Icons.card_giftcard_rounded
                          : Icons.event_available_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  final List<String> features;

  const _BenefitsCard({required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Qué incluye',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 14),
          ...features.map(_featureRow),
        ],
      ),
    );
  }
}

class _MembershipSummary extends StatelessWidget {
  final Map<String, dynamic>? status;
  final int planCount;

  const _MembershipSummary({required this.status, required this.planCount});

  @override
  Widget build(BuildContext context) {
    final info = _MembershipStatusInfo.from(status);
    final plan = status?['plan'] is Map ? status!['plan'] as Map : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 24),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              label: 'Plan actual',
              value: plan?['name']?.toString() ?? 'Sin plan',
              icon: Icons.verified_user_rounded,
            ),
          ),
          Container(width: 1, height: 52, color: _line),
          Expanded(
            child: _SummaryTile(
              label: 'Estado',
              value: info.shortTitle,
              icon: info.icon,
            ),
          ),
          Container(width: 1, height: 52, color: _line),
          Expanded(
            child: _SummaryTile(
              label: 'Opciones',
              value: '$planCount',
              icon: Icons.view_list_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _MetricBox({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink, size: 19),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;

  const _MiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 45).clamp(0, 240)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, dynamic>? status;

  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final info = _MembershipStatusInfo.from(status);
    final plan = status?['plan'] is Map ? status!['plan'] as Map : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: info.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: info.border),
        boxShadow: [
          BoxShadow(
            color: info.border.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(info.icon, color: info.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            info.body,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              height: 1.38,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: _ink, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan['name']?.toString() ?? 'Plan actual',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Text(
                    '${info.daysRemaining} días',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembershipStatusInfo {
  final String title;
  final String shortTitle;
  final String subtitle;
  final String body;
  final String headerCopy;
  final int daysRemaining;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final Color border;

  const _MembershipStatusInfo({
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.body,
    required this.headerCopy,
    required this.daysRemaining,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.border,
  });

  factory _MembershipStatusInfo.from(Map<String, dynamic>? status) {
    final current = status?['status']?.toString().toUpperCase() ?? 'BLOCKED';
    final canOperate = status?['can_operate'] == true;
    final days = status?['days_remaining'];
    final daysRemaining =
        days is num ? days.toInt() : int.tryParse('$days') ?? 0;

    if (canOperate && current == 'TRIAL') {
      return _MembershipStatusInfo(
        title: 'Prueba activa',
        shortTitle: 'Prueba',
        subtitle: '$daysRemaining días disponibles',
        body:
            'Puedes recibir servicios mientras terminas de elegir tu plan definitivo.',
        headerCopy: 'Tu acceso está activo en periodo de prueba.',
        daysRemaining: daysRemaining,
        icon: Icons.hourglass_top_rounded,
        iconColor: _ink,
        background: const Color(0xFFFFF4C2),
        border: _driversappYellow,
      );
    }

    if (canOperate && current == 'GRACE') {
      return _MembershipStatusInfo(
        title: 'Periodo de renovación',
        shortTitle: 'Renovar',
        subtitle: '$daysRemaining días para pagar',
        body:
            'Tu membresía venció, pero aún puedes operar durante el plazo de renovación.',
        headerCopy: 'Renueva antes de que termine tu plazo.',
        daysRemaining: daysRemaining,
        icon: Icons.schedule_rounded,
        iconColor: const Color(0xFF9A6B00),
        background: const Color(0xFFFFF4C2),
        border: _driversappYellow,
      );
    }

    if (canOperate) {
      return _MembershipStatusInfo(
        title: 'Membresía activa',
        shortTitle: 'Activa',
        subtitle: '$daysRemaining días restantes',
        body:
            'Tu cuenta está habilitada para conectarte, recibir solicitudes y atender servicios.',
        headerCopy: 'Gestiona tu acceso para seguir operando.',
        daysRemaining: daysRemaining,
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF087A43),
        background: const Color(0xFFEAF8EF),
        border: const Color(0xFFB9E8C8),
      );
    }

    return _MembershipStatusInfo(
      title: current == 'OVERDUE' ? 'Pago vencido' : 'Membresía bloqueada',
      shortTitle: 'Bloqueada',
      subtitle: 'Acceso operativo detenido',
      body:
          'Para conectarte y recibir servicios necesitas una membresía activa.',
      headerCopy: 'Activa tu acceso para operar en DriversApp.',
      daysRemaining: daysRemaining,
      icon: Icons.lock_rounded,
      iconColor: const Color(0xFFEB4D4B),
      background: const Color(0xFFFFF0F0),
      border: const Color(0xFFFFC9C9),
    );
  }
}

Widget _featureRow(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: _ink, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.25,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );

BoxDecoration _cardDecoration({double radius = 26}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );

List<String> _planFeatures(Map<String, dynamic> plan) {
  final metadata = plan['metadata'];
  final raw =
      metadata is Map ? metadata['features'] ?? metadata['bullets'] : null;
  if (raw is List) {
    final values = raw
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (values.isNotEmpty) return values;
  }
  if (raw is String) {
    final values = raw
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (values.isNotEmpty) return values;
  }
  return const [
    'Conectarte y recibir servicios cuando tu cuenta esté habilitada.',
    'Gestionar tus vehículos y escoger cuál usar en tu jornada.',
    'Consultar pagos, facturas y avisos importantes.',
  ];
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _money(dynamic cents) {
  final value = _intValue(cents);
  final pesos = (value / 100).round();
  final formatted = pesos.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  return '\$$formatted COP';
}

String _invoiceStatus(dynamic status) {
  final value = status?.toString().toUpperCase() ?? 'PENDING';
  return switch (value) {
    'PAID' => 'Pagada',
    'VOID' => 'Anulada',
    'OVERDUE' => 'Vencida',
    'FAILED' => 'Fallida',
    _ => 'Pendiente',
  };
}
