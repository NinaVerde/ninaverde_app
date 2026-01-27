import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// import '../main.dart'; // Removing to avoid ambiguity
import '../state/app_state.dart';
import '../services/live_game_service.dart';
import '../models/live_game_models.dart';
import '../services/migration_service.dart';
import '../widgets/nv_widgets.dart';
import '../widgets/johns_insights_widget.dart';
import '../widgets/john_copilot_sheet.dart';
import 'kitchen_display_screen.dart';
import 'driver_dashboard_screen.dart';
import 'accounting_dashboard_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  bool _customize = false;
  bool _loadingPrefs = true;

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Timer? _saveDebounce;
  List<String> _moduleOrder = [];

  final List<_DashboardModule> _modules = [
    _DashboardModule(
      id: 'kpi',
      titleEn: 'Key Metrics',
      titleEs: 'Metricas Clave',
      subtitleEn: 'Revenue, orders, growth and conversion.',
      subtitleEs: 'Ingresos, pedidos, crecimiento y conversion.',
      icon: Icons.auto_graph,
      color: Color(0xFF2E7D32),
    ),
    _DashboardModule(
      id: 'orders',
      titleEn: 'Orders',
      titleEs: 'Pedidos',
      subtitleEn: 'Live feed, fulfillment, and refunds.',
      subtitleEs: 'Flujo en vivo, entregas y reembolsos.',
      icon: Icons.receipt_long,
      color: Color(0xFFF3A70B),
    ),
    _DashboardModule(
      id: 'customers',
      titleEn: 'Customers',
      titleEs: 'Clientes',
      subtitleEn: 'Segments, lifetime value, and trends.',
      subtitleEs: 'Segmentos, valor de vida y tendencias.',
      icon: Icons.people_alt,
      color: Color(0xFF1E88E5),
    ),
    _DashboardModule(
      id: 'loyalty',
      titleEn: 'Loyalty',
      titleEs: 'Lealtad',
      subtitleEn: 'NV Coins, rewards, tiers and retention.',
      subtitleEs: 'Monedas NV, recompensas, niveles y retencion.',
      icon: Icons.loyalty,
      color: Color(0xFF8E24AA),
    ),
    _DashboardModule(
      id: 'campaigns',
      titleEn: 'Campaigns',
      titleEs: 'Campanas',
      subtitleEn: 'Offers, SMS, push and performance.',
      subtitleEs: 'Ofertas, SMS, push y rendimiento.',
      icon: Icons.campaign,
      color: Color(0xFFEF6C00),
    ),
    _DashboardModule(
      id: 'reservations',
      titleEn: 'Reservations',
      titleEs: 'Reservas',
      subtitleEn: 'Tables, events, and VIP bookings.',
      subtitleEs: 'Mesas, eventos y reservaciones VIP.',
      icon: Icons.event_available,
      color: Color(0xFF00897B),
    ),
    _DashboardModule(
      id: 'inventory',
      titleEn: 'Inventory',
      titleEs: 'Inventario',
      subtitleEn: 'Stock, alerts, and purchasing.',
      subtitleEs: 'Stock, alertas y compras.',
      icon: Icons.inventory_2,
      color: Color(0xFF6D4C41),
    ),
    _DashboardModule(
      id: 'support',
      titleEn: 'Support',
      titleEs: 'Soporte',
      subtitleEn: 'Tickets, escalation, and SLA.',
      subtitleEs: 'Tickets, escalamiento y SLA.',
      icon: Icons.support_agent,
      color: Color(0xFF5E35B1),
    ),
    _DashboardModule(
      id: 'staff',
      titleEn: 'Staff',
      titleEs: 'Personal',
      subtitleEn: 'Schedules, roles, and performance.',
      subtitleEs: 'Horarios, roles y desempeno.',
      icon: Icons.badge,
      color: Color(0xFF3949AB),
    ),
    _DashboardModule(
      id: 'gaming',
      titleEn: 'Gaming',
      titleEs: 'Juegos',
      subtitleEn: 'Session approvals, equipment and rules.',
      subtitleEs: 'Aprobación de sesiones, equipos y reglas.',
      icon: Icons.sports_esports,
      color: Color(0xFF1B5E20),
    ),
    _DashboardModule(
      id: 'kitchen',
      titleEn: 'Kitchen Operations',
      titleEs: 'Operaciones de Cocina',
      subtitleEn: 'Order workflow, kitchen display and delivery management.',
      subtitleEs: 'Flujo de pedidos, pantalla de cocina y gestión de entregas.',
      icon: Icons.restaurant_menu,
      color: Color(0xFFD84315),
    ),
    _DashboardModule(
      id: 'accounting',
      titleEn: 'Accounting',
      titleEs: 'Contabilidad',
      subtitleEn: 'P&L, expenses, and staff costs.',
      subtitleEs: 'P&L, gastos y costos de personal.',
      icon: Icons.account_balance_wallet,
      color: Color(0xFFD4AF37), // Gold
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>? _prefsRef() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db
        .collection('users')
        .doc(uid)
        .collection('owner_dashboard')
        .doc('layout');
  }

  Future<void> _loadPrefs() async {
    final ref = _prefsRef();
    if (ref == null) {
      _applyDefaultOrder();
      return;
    }
    try {
      final snap = await ref.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        final order = (data['moduleOrder'] as List?)?.cast<String>() ?? [];
        final visibility = (data['moduleVisibility'] as Map?) ?? {};
        if (order.isNotEmpty) {
          _moduleOrder = List<String>.from(order);
        }
        visibility.forEach((key, value) {
          final id = key is String ? key : null;
          final visible = value == true;
          if (id == null) return;
          final module = _modules.firstWhere(
            (m) => m.id == id,
            orElse: () => _DashboardModule(
              id: id,
              titleEn: id,
              titleEs: id,
              subtitleEn: '',
              subtitleEs: '',
              icon: Icons.dashboard,
              color: const Color(0xFF4CAF50),
            ),
          );
          module.visible = visible;
        });
      } else {
        _applyDefaultOrder();
      }
    } catch (_) {
      _applyDefaultOrder();
    } finally {
      if (mounted) {
        setState(() => _loadingPrefs = false);
      }
    }
  }

  void _applyDefaultOrder() {
    _moduleOrder = _modules.map((m) => m.id).toList();
    if (mounted) {
      setState(() => _loadingPrefs = false);
    }
  }

  List<_DashboardModule> _orderedModules() {
    final byId = {for (final m in _modules) m.id: m};
    final ordered = <_DashboardModule>[];
    for (final id in _moduleOrder) {
      final m = byId.remove(id);
      if (m != null) ordered.add(m);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  void _reorderModules(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final ordered = _orderedModules();
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    _moduleOrder = ordered.map((m) => m.id).toList();
    _scheduleSavePrefs();
    setState(() {});
  }

  void _toggleModule(_DashboardModule module) {
    setState(() => module.visible = !module.visible);
    _scheduleSavePrefs();
  }

  void _scheduleSavePrefs() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _savePrefs);
  }

  Future<void> _savePrefs() async {
    final ref = _prefsRef();
    if (ref == null) return;
    final visibility = <String, bool>{
      for (final m in _modules) m.id: m.visible,
    };
    try {
      await ref.set({
        'moduleOrder': _moduleOrder,
        'moduleVisibility': visibility,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Silent; UI already updated locally.
    }
  }

  Future<void> _resetPrefs() async {
    for (final m in _modules) {
      m.visible = true;
    }
    _applyDefaultOrder();
    await _savePrefs();
  }

  void _handleModuleTap(_DashboardModule module, bool isEs) {
    if (_customize) return;
    
    if (module.id == 'gaming') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const _GamingManagementPage()),
      );
    } else if (module.id == 'kitchen') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const _KitchenOpsPage()),
      );
    } else if (module.id == 'accounting') {
       Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AccountingDashboardScreen()),
      );
    } else if (module.id == 'staff') {
       // Navigate to Schedule Admin
       Navigator.pushNamed(context, '/schedule-admin');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEs ? 'Módulo en desarrollo' : 'Module under development')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    return AnimatedBuilder(
      animation:
          Listenable.merge([app.languageCode, app.currencyCode, app.currencyConfigs]),
      builder: (_, __) {
        final isEs = app.languageCode.value == 'es';
        final title = isEs ? 'Panel del Propietario' : 'Owner Control Panel';
        final customizeLabel = isEs ? 'Personalizar' : 'Customize';
        final finishLabel = isEs ? 'Listo' : 'Done';
        final resetLabel = isEs ? 'Restaurar layout' : 'Reset layout';

        return Scaffold(
          appBar: NvAppBar(
            tickerVisible: app.showTicker.value,
            title: title,
            showBack: true,
            extraActions: [
              IconButton(
                tooltip: resetLabel,
                onPressed: _loadingPrefs ? null : _resetPrefs,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: customizeLabel,
                onPressed: () => setState(() => _customize = !_customize),
                icon: Icon(_customize ? Icons.check_circle : Icons.tune),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF0B2C1E)
                      : const Color(0xFFEFF7EE),
                  Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF020B08)
                      : const Color(0xFFF7F1D3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeroStrip(isEs: isEs),
                const SizedBox(height: 16),
                _QuickActions(isEs: isEs),
                const SizedBox(height: 16),
                const JohnsInsightsWidget(),
                const SizedBox(height: 16),
                _KpiGrid(isEs: isEs),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: isEs ? 'Centro CRM' : 'CRM Center',
                  subtitle: isEs
                      ? 'Gestiona relaciones, ventas y crecimiento.'
                      : 'Manage relationships, revenue, and growth.',
                ),
                const SizedBox(height: 12),
                if (_loadingPrefs)
                  const Center(child: CircularProgressIndicator())
                else
                  Builder(
                    builder: (context) {
                      final ordered = _orderedModules()
                          .where((m) => m.visible || _customize)
                          .toList();
                      return ReorderableListView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        onReorder: _customize ? _reorderModules : (_, __) {},
                        children: [
                          for (int i = 0; i < ordered.length; i++)
                            _ModuleCard(
                              key: ValueKey(ordered[i].id),
                              module: ordered[i],
                              isEs: isEs,
                              customize: _customize,
                              onToggle: () => _toggleModule(ordered[i]),
                              onTap: () => _handleModuleTap(ordered[i], isEs),
                              dragHandle: _customize
                                  ? ReorderableDragStartListener(
                                      index: i,
                                      child: const Icon(
                                        Icons.drag_handle_rounded,
                                      ),
                                    )
                                  : null,
                            ),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 16),
                _AdminLinks(isEs: isEs),
                const SizedBox(height: 24),
                // Footer padding for FAB
                const SizedBox(height: 80), 
                if (_customize)
                  FilledButton(
                    onPressed: () => setState(() => _customize = false),
                    child: Text(finishLabel),
                  ),
              ],
            ),
          ),
          floatingActionButton: _buildJohnFab(context),
        );
      },
    );
  }
  
  Widget _buildJohnFab(BuildContext context) {
      return Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
              ]
          ),
          child: FloatingActionButton.extended(
              onPressed: () => _openJohnCopilot(context),
              backgroundColor: Colors.black,
              icon: const Icon(Icons.smart_toy, color: Colors.cyanAccent),
              label: const Text('ASK JOHN', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(duration: 3.seconds, delay: 2.seconds, color: Colors.cyanAccent.withOpacity(0.3)),
      );
  }

  void _openJohnCopilot(BuildContext context) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: const JohnCopilotSheet(),
          ),
      );
  }
}

class _HeroStrip extends StatelessWidget {
  final bool isEs;
  const _HeroStrip({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final title = isEs ? 'Tu centro de mando' : 'Command Center';
    final surface = Theme.of(context).colorScheme.surface;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
            colors: [Color(0xFF001e36), Color(0xFF000000)], // Deep tech blue to black
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
           // User Avatar
           const CircleAvatar(
               radius: 24,
               backgroundImage: AssetImage('assets/images/avatar/default_avatar.png'), // Placeholder
               backgroundColor: Colors.grey,
           ),
           
           // Connection Line
           Expanded(child: Container(height: 1, color: Colors.cyanAccent.withOpacity(0.3))),
           const Icon(Icons.link, color: Colors.cyanAccent, size: 16),
           Expanded(child: Container(height: 1, color: Colors.cyanAccent.withOpacity(0.3))),
           
           // John Avatar
           Container(
               padding: const EdgeInsets.all(2),
               decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.cyanAccent)),
               child: const CircleAvatar(
                   radius: 22,
                   backgroundColor: Colors.black,
                   child: Icon(Icons.smart_toy, color: Colors.cyanAccent),
               ),
           ).animate(onPlay: (c) => c.repeat(reverse: true)).boxShadow(end: const BoxShadow(color: Colors.cyanAccent, blurRadius: 10)),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.08, end: 0);
  }
}

class _QuickActions extends StatelessWidget {
  final bool isEs;
  const _QuickActions({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionItem(
        icon: Icons.person_add_alt_1,
        label: isEs ? 'Nuevo cliente' : 'New customer',
      ),
      _ActionItem(
        icon: Icons.campaign,
        label: isEs ? 'Nueva campana' : 'New campaign',
      ),
      _ActionItem(
        icon: Icons.local_offer,
        label: isEs ? 'Crear oferta' : 'Create offer',
      ),
      _ActionItem(
        icon: Icons.support_agent,
        label: isEs ? 'Nuevo ticket' : 'New ticket',
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((i) => _ActionChip(item: i)).toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  const _ActionItem({required this.icon, required this.label});
}

class _ActionChip extends StatelessWidget {
  final _ActionItem item;
  const _ActionChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final labelColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(item.icon, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: labelColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final bool isEs;
  const _KpiGrid({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        title: isEs ? 'Ingresos' : 'Revenue',
        value: formatCurrency(context, 2400000),
        delta: '+12.4%',
        color: const Color(0xFF2E7D32),
      ),
      _KpiItem(
        title: isEs ? 'Pedidos' : 'Orders',
        value: '1,284',
        delta: '+6.1%',
        color: const Color(0xFFF3A70B),
      ),
      _KpiItem(
        title: isEs ? 'Clientes' : 'Customers',
        value: '4,980',
        delta: '+9.7%',
        color: const Color(0xFF1E88E5),
      ),
      _KpiItem(
        title: isEs ? 'Retencion' : 'Retention',
        value: '82%',
        delta: '+2.1%',
        color: const Color(0xFF8E24AA),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items.map((k) => _KpiCard(item: k)).toList(),
    );
  }
}

class _KpiItem {
  final String title;
  final String value;
  final String delta;
  final Color color;

  const _KpiItem({
    required this.title,
    required this.value,
    required this.delta,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: subtitleColor),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item.delta,
              style: TextStyle(color: item.color, fontWeight: FontWeight.w600),
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.98, 0.98));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: subtitleColor),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _DashboardModule module;
  final bool isEs;
  final bool customize;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final Widget? dragHandle;

  const _ModuleCard({
    super.key,
    required this.module,
    required this.isEs,
    required this.customize,
    required this.onToggle,
    required this.onTap,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: module.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(module.icon, color: module.color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEs ? module.titleEs : module.titleEn,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  isEs ? module.subtitleEs : module.subtitleEn,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: subtitleColor),
                ),
              ],
            ),
          ),
          if (customize && dragHandle != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: dragHandle!,
            ),
          if (customize)
            IconButton(
              tooltip: tr(
                context,
                en: module.visible ? 'Hide' : 'Show',
                es: module.visible ? 'Ocultar' : 'Mostrar',
              ),
              onPressed: onToggle,
              icon: Icon(
                module.visible ? Icons.visibility : Icons.visibility_off,
                color: Colors.black54,
              ),
            ),
        ],
      ),
    ),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0);
}
}

class _AdminLinks extends StatelessWidget {
  final bool isEs;
  const _AdminLinks({required this.isEs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: isEs ? 'Configuraciones' : 'Settings',
          subtitle: isEs
              ? 'Paneles y configuraciones clave.'
              : 'Key admin panels and settings.',
        ),
        const SizedBox(height: 12),
        _LinkTile(
          title: isEs ? 'Estandarizar Datos' : 'Standardize All Data',
          subtitle: isEs
              ? 'Traduce todo el contenido de Firestore a Inglés.'
              : 'Translate all Firestore content to English standard.',
          icon: Icons.auto_awesome,
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(isEs ? '¿Estandarizar Datos?' : 'Standardize Data?'),
                content: Text(isEs
                    ? 'Esto escaneará todos los productos, eventos y juegos, traduciéndolos al inglés en Firestore para cumplir con el nuevo estándar universal.'
                    : 'This will scan all products, events, and games, translating them all to English in Firestore to meet the new universal standard.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(isEs ? 'Cancelar' : 'Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(isEs ? 'Traducir todo' : 'Translate All')),
                ],
              ),
            );
            if (ok == true) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEs
                        ? 'Iniciando traducción...'
                        : 'Starting translation...')));
              }
              await MigrationService.standardizeAllToEnglish();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isEs
                        ? '¡Datos estandarizados a Inglés!'
                        : 'Data standardized to English!')));
              }
            }
          },
        ),
        _LinkTile(
          title: isEs ? 'Categorias Hero' : 'Hero Categories',
          subtitle: isEs
              ? 'Orden, efectos y contenido visual.'
              : 'Order, effects, and visual assets.',
          icon: Icons.view_carousel,
          onTap: () => Navigator.pushNamed(context, '/carousel-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Angelina AI' : 'Angelina AI',
          subtitle: isEs
              ? 'Control de voz, conocimiento y apariencia.'
              : 'Voice, knowledge and persona controls.',
          icon: Icons.face_retouching_natural,
          onTap: () => Navigator.pushNamed(context, '/angelina-admin'),
        ),
        _LinkTile(
          title: isEs ? 'John AI' : 'John AI',
          subtitle: isEs
              ? 'Anfitrión alternativo y configuraciones.'
              : 'Alternative host and settings.',
          icon: Icons.face_retouching_natural,
          onTap: () => Navigator.pushNamed(context, '/john-admin'),
        ),


        _LinkTile(
          title: isEs ? 'Idiomas' : 'Languages',
          subtitle: isEs
              ? 'Gestiona idiomas disponibles y traducciones.'
              : 'Manage available languages and translations.',
          icon: Icons.language,
          onTap: () => Navigator.pushNamed(context, '/language-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Monedas' : 'Currencies',
          subtitle: isEs
              ? 'Gestiona monedas y tasas de cambio.'
              : 'Manage currencies and exchange rates.',
          icon: Icons.attach_money,
          onTap: () => Navigator.pushNamed(context, '/currency-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Gestor de Temas' : 'Theme Manager',
          subtitle: isEs
              ? 'Personaliza colores y apariencia.'
              : 'Customize colors and appearance.',
          icon: Icons.palette,
          onTap: () => Navigator.pushNamed(context, '/theme-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Catalogo' : 'Catalog',
          subtitle: isEs
              ? 'Productos, categorias e imagenes.'
              : 'Products, categories, and media.',
          icon: Icons.inventory_2,
          onTap: () => Navigator.pushNamed(context, '/app-settings/catalog'),
        ),
        _LinkTile(
          title: isEs ? 'Eventos y promos' : 'Events & Promos',
          subtitle: isEs
              ? 'Gestiona campañas, videos y fechas.'
              : 'Manage campaigns, media, and dates.',
          icon: Icons.event,
          onTap: () => Navigator.pushNamed(context, '/app-settings/events'),
        ),
        _LinkTile(
          title: isEs ? 'Monedas NV' : 'NV Coins',
          subtitle: isEs
              ? 'Configura recompensas y bonos.'
              : 'Configure rewards and bonuses.',
          icon: Icons.stars,
          onTap: () => Navigator.pushNamed(context, '/app-settings/rewards'),
        ),
        _LinkTile(
          title: isEs ? 'Campanas' : 'Campaigns',
          subtitle: isEs
              ? 'Email, SMS y push programados.'
              : 'Email, SMS, and push scheduling.',
          icon: Icons.send,
          onTap: () => Navigator.pushNamed(context, '/app-settings/campaigns'),
        ),
        _LinkTile(
          title: isEs ? 'Config. comunicaciones' : 'Comms Settings',
          subtitle: isEs
              ? 'Canales, opt-in y ajustes.'
              : 'Channels, opt-in, and defaults.',
          icon: Icons.settings_input_component,
          onTap: () =>
              Navigator.pushNamed(context, '/app-settings/comms-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Leads' : 'Leads',
          subtitle: isEs
              ? 'Importa y gestiona listas.'
              : 'Import and manage lists.',
          icon: Icons.list_alt,
          onTap: () => Navigator.pushNamed(context, '/app-settings/leads'),
        ),
        _LinkTile(
          title: isEs ? 'Resenas' : 'Reviews',
          subtitle: isEs
              ? 'Moderacion y aprobaciones.'
              : 'Moderation and approvals.',
          icon: Icons.rate_review,
          onTap: () => Navigator.pushNamed(context, '/reviews-admin'),
        ),
        _LinkTile(
          title: isEs ? 'Favoritos' : 'Favorites',
          subtitle: isEs
              ? 'Tendencias y productos mas queridos.'
              : 'Trends and most loved products.',
          icon: Icons.favorite,
          onTap: () => Navigator.pushNamed(context, '/app-settings/favorites'),
        ),
        _LinkTile(
          title: isEs ? 'Ticker' : 'Ticker',
          subtitle: isEs
              ? 'Mensajes y apariencia de la cinta superior.'
              : 'Top banner messages and appearance.',
          icon: Icons.view_carousel,
          onTap: () => Navigator.pushNamed(context, '/ticker-settings'),
        ),
        _LinkTile(
          title: isEs ? 'Intro y Logo' : 'Intro & Logo',
          subtitle: isEs
              ? 'Configura el logo y el video de bienvenida.'
              : 'Configure login logo and welcome video.',
          icon: Icons.play_circle_outline,
          onTap: () => Navigator.pushNamed(context, '/login-video-settings'),
        ),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        child: Icon(icon, color: const Color(0xFF4CAF50)),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _DashboardModule {
  final String id;
  final String titleEn;
  final String titleEs;
  final String subtitleEn;
  final String subtitleEs;
  final IconData icon;
  final Color color;
  bool visible = true;

  _DashboardModule({
    required this.id,
    required this.titleEn,
    required this.titleEs,
    required this.subtitleEn,
    required this.subtitleEs,
    required this.icon,
    required this.color,
  });
}

class _GamingManagementPage extends StatelessWidget {
  const _GamingManagementPage();

  @override
  Widget build(BuildContext context) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    
    return Scaffold(
      appBar: NvAppBar(
        tickerVisible: AppState.of(context).showTicker.value,
        title: isEs ? 'Gestión de Juegos' : 'Gaming Management',
        showBack: true,
      ),
      body: StreamBuilder<List<LiveGameSession>>(
        stream: LiveGameService.getActiveSessions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final sessions = snapshot.data!;
          
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_esports, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(isEs ? 'No hay sesiones activas' : 'No active sessions'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, i) => _SessionApprovalCard(session: sessions[i], isEs: isEs),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => LiveGameService.seedInitialConfigs(),
        label: Text(isEs ? 'Sembrar Juegos' : 'Seed Games'),
        icon: const Icon(Icons.data_saver_on),
      ),
    );
  }
}

class _SessionApprovalCard extends StatelessWidget {
  final LiveGameSession session;
  final bool isEs;
  const _SessionApprovalCard({required this.session, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LiveGameConfig>>(
      future: LiveGameService.getConfigs(),
      builder: (context, snapshot) {
        final config = snapshot.data?.firstWhere((c) => c.id == session.gameId, orElse: () => LiveGameConfig(id: '', name: 'Unknown', icon: '❓', pricePerQuarterHour: 0, maxPlayers: 1, rules: '', deposit: 0));
        
        final duration = (session.endTime ?? DateTime.now()).difference(session.startTime);
        final charge = LiveGameService.calculateCharge(session.startTime, session.endTime ?? DateTime.now(), config?.pricePerQuarterHour ?? 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(config?.icon ?? '?', style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              TranslatedText(config?.name ?? 'Unknown'),
                              Text(' • ${session.playerCount} ${isEs ? "jugadores" : "players"}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text('\$${charge.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s'),
                    if (session.endTime != null)
                      ElevatedButton(
                        onPressed: () => LiveGameService.approveEndSession(session.id, charge),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        child: Text(isEs ? 'Aprobar Salida' : 'Approve Checkout'),
                      )
                    else
                      Text(isEs ? 'En curso...' : 'In progress...', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kitchen Operations hub - combines KDS and driver dashboard
class _KitchenOpsPage extends StatelessWidget {
  const _KitchenOpsPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFD84315),
          title: const Text(
            '🔥 Kitchen Operations',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.restaurant), text: 'Kitchen Display'),
              Tab(icon: Icon(Icons.delivery_dining), text: 'Drivers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            KitchenDisplayScreen(),
            DriverDashboardScreen(),
          ],
        ),
      ),
    );
  }
}

