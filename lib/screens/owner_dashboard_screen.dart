import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';

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
                if (_customize)
                  FilledButton(
                    onPressed: () => setState(() => _customize = false),
                    child: Text(finishLabel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroStrip extends StatelessWidget {
  final bool isEs;
  const _HeroStrip({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final title = isEs ? 'Tu centro de mando' : 'Your command center';
    final subtitle = isEs
        ? 'Todo el negocio, en tiempo real.'
        : 'The entire business, in real time.';
    final surface = Theme.of(context).colorScheme.surface;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: surface.withValues(alpha: 0.94),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4CAF50),
            ),
            child: const Icon(Icons.dashboard, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: subtitleColor),
                ),
              ],
            ),
          ),
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
  final Widget? dragHandle;

  const _ModuleCard({
    super.key,
    required this.module,
    required this.isEs,
    required this.customize,
    required this.onToggle,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Container(
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
          title: isEs ? 'Angelina AI' : 'Angelina AI',
          subtitle: isEs
              ? 'Control de voz, conocimiento y apariencia.'
              : 'Voice, knowledge and persona controls.',
          icon: Icons.face_retouching_natural,
          onTap: () => Navigator.pushNamed(context, '/angelina-admin'),
        ),
        _LinkTile(
          title: isEs ? 'Idiomas y monedas' : 'Languages & Currencies',
          subtitle: isEs
              ? 'Actualiza conversiones y preferencias globales.'
              : 'Update conversions and global preferences.',
          icon: Icons.translate,
          onTap: () => Navigator.pushNamed(context, '/app-settings/localization'),
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
          onTap: () => Navigator.pushNamed(context, '/app-settings/reviews'),
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
          onTap: () => Navigator.pushNamed(context, '/app-settings/intro'),
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
