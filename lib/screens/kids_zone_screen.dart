import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
import '../services/live_game_service.dart';
import '../models/live_game_models.dart';

class KidszGamezZoneScreen extends StatefulWidget {
  const KidszGamezZoneScreen({super.key});

  @override
  State<KidszGamezZoneScreen> createState() => _KidszGamezZoneScreenState();
}

class _KidszGamezZoneScreenState extends State<KidszGamezZoneScreen> {
  List<_GameInfo> _miniGames(BuildContext context) {
     final isEs = AppState.of(context).languageCode.value == 'es';
     String t(String en, String es) => isEs ? es : en;
     
     return [
      _GameInfo(
        title: t('Coloring Studio', 'Estudio de Color'),
        subtitle: t('Paint and create your own Niña Verde world.', 'Pinta y crea tu propio mundo Niña Verde.'),
        route: '/kids/coloring',
        icon: Icons.palette,
        color: const Color(0xFFF3A70B),
      ),
      _GameInfo(
        title: t('Puzzle Dash', 'Carrera de Puzzles'),
        subtitle: t('Slide the tiles to rebuild the picture.', 'Desliza las fichas para reconstruir la imagen.'),
        route: '/kids/puzzle',
        icon: Icons.grid_3x3,
        color: const Color(0xFF4CAF50),
      ),
      _GameInfo(
        title: t('Jungle Maze', 'Laberinto Selvático'),
        subtitle: t('Guide the explorer to the finish.', 'Guía al explorador hasta la meta.'),
        route: '/kids/maze',
        icon: Icons.route,
        color: const Color(0xFF3E7A4F),
      ),
      _GameInfo(
        title: t('Memory Match', 'Parejas de Memoria'),
        subtitle: t('Find all the matching pairs.', 'Encuentra todos los pares iguales.'),
        route: '/kids/memory',
        icon: Icons.extension,
        color: const Color(0xFF8BC34A),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';

    return Scaffold(
      appBar: NvAppBar(
        title: isEs ? 'Kidsz Gamez Zone' : 'Kidsz Gamez Zone', 
        showBack: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? [const Color(0xFF0D2016), const Color(0xFF1A2B1E)]
                : [const Color(0xFFEDF7E8), const Color(0xFFF7F1D3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            _HeroHeader(
              title: isEs ? '¡Bienvenido a Kidsz Gamez!' : 'Welcome to Kidsz Gamez!',
              subtitle: isEs
                  ? 'Juegos en vivo y diversión digital.'
                  : 'Live games and digital fun.',
            ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
            
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildLiveGamesSection(context, isEs)
                      .animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 24),
                  _buildSectionTitle(isEs ? 'Mini-Juegos' : 'Mini Games', isEs)
                      .animate().fadeIn(delay: 300.ms),
                  
                  // Cascading list items
                  ..._miniGames(context).asMap().entries.map((entry) {
                     return _GameCard(info: entry.value)
                        .animate()
                        .fadeIn(delay: (400 + (entry.key * 100)).ms)
                        .slideX(begin: 0.2, end: 0, curve: Curves.easeOutQuart);
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isEs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF2E7D32),
            ),
      ),
    );
  }

  Widget _buildLiveGamesSection(BuildContext context, bool isEs) {
    return StreamBuilder<LiveGameSession?>(
      stream: LiveGameService.getUserActiveSession(),
      builder: (context, snapshot) {
        final activeSession = snapshot.data;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(isEs ? 'Juegos en Vivo' : 'Live Games', isEs),
            if (activeSession != null)
              _ActiveSessionCard(session: activeSession)
            else
              _LiveGameList(),
          ],
        );
      },
    );
  }
}

class _LiveGameList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LiveGameConfig>>(
      future: LiveGameService.getConfigs(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }
        
        final configs = snapshot.data!;
        return SizedBox(
          height: 180,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: configs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => _LiveGameBookingCard(config: configs[i]),
          ),
        );
      },
    );
  }
}

class _LiveGameBookingCard extends StatelessWidget {
  final LiveGameConfig config;
  const _LiveGameBookingCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';

    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showBookingDialog(context, config, isEs),
          onLongPress: () {
            if (app.isManager.value) {
              _showEditorSheet(context, config);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(config.icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                TranslatedText(
                  config.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isEs ? '1/4 hora: \$${config.pricePerQuarterHour}' : '1/4 hr: \$${config.pricePerQuarterHour}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    .animate(onPlay: (c) => c.repeat(reverse: true))
    .shimmer(duration: 3.seconds, color: Colors.white.withValues(alpha: 0.3)) // Subtle surface shimmer
    .scaleXY(begin: 1.0, end: 1.02, duration: 2.seconds, curve: Curves.easeInOut); // Breathing effect
  }

  void _showBookingDialog(BuildContext context, LiveGameConfig config, bool isEs) {
    int players = 1;
    bool acceptedRules = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEs ? 'Reservar ${config.name}' : 'Book ${config.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TranslatedText(config.rules, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEs ? 'Jugadores:' : 'Players:'),
                  DropdownButton<int>(
                    value: players,
                    items: List.generate(config.maxPlayers, (i) => i + 1)
                        .map((p) => DropdownMenuItem(value: p, child: Text('$p')))
                        .toList(),
                    onChanged: (v) => setState(() => players = v ?? 1),
                  ),
                ],
              ),
              CheckboxListTile(
                title: Text(
                  isEs ? 'Acepto responsabilidad por equipo' : 'I accept responsibility for equipment',
                  style: const TextStyle(fontSize: 11),
                ),
                value: acceptedRules,
                onChanged: (v) => setState(() => acceptedRules = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEs ? 'Cancelar' : 'Cancel')),
            ElevatedButton(
              onPressed: acceptedRules ? () async {
                try {
                  await LiveGameService.startSession(gameId: config.id, playerCount: players);
                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              } : null,
              child: Text(isEs ? '¡Comenzar!' : 'Start!'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditorSheet(BuildContext context, LiveGameConfig config) {
    final nameCtrl = TextEditingController(text: config.name);
    final priceCtrl = TextEditingController(text: config.pricePerQuarterHour.toString());
    final depositCtrl = TextEditingController(text: config.deposit.toString());
    final rulesCtrl = TextEditingController(text: config.rules);
    final iconCtrl = TextEditingController(text: config.icon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16, right: 16, top: 16
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Edit Game Config', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            Row(
              children: [
                Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price / 15min'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: depositCtrl, decoration: const InputDecoration(labelText: 'Deposit'), keyboardType: TextInputType.number)),
              ],
            ),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon Emoji')),
            TextField(controller: rulesCtrl, decoration: const InputDecoration(labelText: 'Rules'), maxLines: 3),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newConfig = config.copyWith(
                  name: nameCtrl.text,
                  pricePerQuarterHour: double.tryParse(priceCtrl.text) ?? config.pricePerQuarterHour,
                  deposit: double.tryParse(depositCtrl.text) ?? config.deposit,
                  rules: rulesCtrl.text,
                  icon: iconCtrl.text,
                );
                await LiveGameService.upsertConfig(newConfig);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game config updated')));
                }
              },
              child: const Text('Save Changes'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatefulWidget {
  final LiveGameSession session;
  const _ActiveSessionCard({required this.session});

  @override
  State<_ActiveSessionCard> createState() => _ActiveSessionCardState();
}

class _ActiveSessionCardState extends State<_ActiveSessionCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.session.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.session.startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEs = AppState.of(context).languageCode.value == 'es';
    final hours = _elapsed.inHours.toString().padLeft(2, '0');
    final mins = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3A70B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Sesión en curso' : 'Active Session',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$hours:$mins:$secs',
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => LiveGameService.requestEndSession(widget.session.id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red),
                child: Text(isEs ? 'Terminar' : 'End'),
              ),
            ],
          ),
          if (widget.session.endTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                isEs ? 'Esperando aprobación del personal...' : 'Waiting for staff approval...',
                style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CAF50)),
            child: const Icon(Icons.videogame_asset, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameInfo {
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final Color color;

  const _GameInfo({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.color,
  });
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  const _GameCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: info.color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(info.icon, color: info.color, size: 30),
        ),
        title: Text(info.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(info.subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.pushNamed(context, info.route),
      ),
    );
  }
}
