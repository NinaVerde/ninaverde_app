import 'package:flutter/material.dart';
import '../main.dart';

class KidsZoneScreen extends StatelessWidget {
  const KidsZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final games = const [
      _GameInfo(
        title: 'Coloring Studio',
        subtitle: 'Paint and create your own Niña Verde world.',
        route: '/kids/coloring',
        icon: Icons.palette,
        color: Color(0xFFF3A70B),
      ),
      _GameInfo(
        title: 'Puzzle Dash',
        subtitle: 'Slide the tiles to rebuild the picture.',
        route: '/kids/puzzle',
        icon: Icons.grid_3x3,
        color: Color(0xFF4CAF50),
      ),
      _GameInfo(
        title: 'Jungle Maze',
        subtitle: 'Guide the explorer to the finish.',
        route: '/kids/maze',
        icon: Icons.route,
        color: Color(0xFF3E7A4F),
      ),
      _GameInfo(
        title: 'Memory Match',
        subtitle: 'Find all the matching pairs.',
        route: '/kids/memory',
        icon: Icons.extension,
        color: Color(0xFF8BC34A),
      ),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: AppState.of(context).languageCode,
      builder: (_, code, __) {
        final isEs = code == 'es';
        final appTitle = isEs ? 'Zona Kids' : 'Kids Zone';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final gradientColors = isDark
            ? [const Color(0xFF0D2016), const Color(0xFF1A2B1E)]
            : [const Color(0xFFEDF7E8), const Color(0xFFF7F1D3)];
        return Scaffold(
          appBar: NvAppBar(title: appTitle, showBack: true),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeroHeader(
                  title: isEs ? 'Zona Kids Niña Verde' : 'Niña Verde Kids Zone',
                  subtitle: isEs
                      ? 'Juega, aprende y explora con minijuegos seguros.'
                      : 'Play, learn, and explore with safe mini games.',
                ),
                const SizedBox(height: 16),
                Column(
                  children: games.map((g) {
                    final title =
                        isEs ? _KidsText.esTitle(g.title) : g.title;
                    final subtitle =
                        isEs ? _KidsText.esSubtitle(g.title) : g.subtitle;
                    return _GameCard(
                      info: g.copyWith(title: title, subtitle: subtitle),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final subtitleColor =
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: surface.withValues(alpha: 0.94),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4CAF50),
            ),
            child: const Icon(Icons.icecream, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: subtitleColor,
                  ),
                ),
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

  _GameInfo copyWith({String? title, String? subtitle}) => _GameInfo(
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        route: route,
        icon: icon,
        color: color,
      );
}

class _GameCard extends StatelessWidget {
  final _GameInfo info;
  const _GameCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final subtitleColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.pushNamed(context, info.route),
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(info.icon, color: info.color, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        info.subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KidsText {
  static String esTitle(String enTitle) {
    switch (enTitle) {
      case 'Coloring Studio':
        return 'Colorear';
      case 'Puzzle Dash':
        return 'Rompecabezas';
      case 'Jungle Maze':
        return 'Laberinto';
      case 'Memory Match':
        return 'Memoria';
      default:
        return enTitle;
    }
  }

  static String esSubtitle(String enTitle) {
    switch (enTitle) {
      case 'Coloring Studio':
        return 'Pinta y crea tu mundo Niña Verde.';
      case 'Puzzle Dash':
        return 'Desliza las piezas para completar la imagen.';
      case 'Jungle Maze':
        return 'Guia al explorador hasta la meta.';
      case 'Memory Match':
        return 'Encuentra todas las parejas.';
      default:
        return '';
    }
  }
}
