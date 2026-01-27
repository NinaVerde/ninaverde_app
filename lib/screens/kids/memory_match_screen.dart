import 'dart:math';
import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/nv_widgets.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  final List<IconData> _icons = const [
    Icons.apple,
    Icons.eco,
    Icons.energy_savings_leaf,
    Icons.water_drop,
    Icons.auto_awesome,
    Icons.bolt,
  ];

  late List<_CardTileData> _tiles;
  int? _firstIndex;
  bool _lock = false;
  int _matches = 0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final pairs = [..._icons, ..._icons];
    pairs.shuffle(Random());
    _tiles = pairs.map((e) => _CardTileData(icon: e)).toList();
    _firstIndex = null;
    _lock = false;
    _matches = 0;
  }

  void _tap(int index) {
    if (_lock || _tiles[index].matched || _tiles[index].flipped) return;
    
    setState(() => _tiles[index].flipped = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final first = _firstIndex!;
    if (_tiles[first].icon == _tiles[index].icon) {
      _matches++;
      setState(() {
        _tiles[first].matched = true;
        _tiles[index].matched = true;
        _firstIndex = null;
      });
      if (_matches == _icons.length) {
        _showWinDialog();
      }
    } else {
      _lock = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          _tiles[first].flipped = false;
          _tiles[index].flipped = false;
          _firstIndex = null;
          _lock = false;
        });
      });
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Match Master!', es: 'Maestro de Memoria!')),
        content: Text(tr(context, en: 'Great job! You found all pairs!', es: '¡Buen trabajo! ¡Encotraste todas las parejas!')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reset();
              setState(() {});
            },
            child: Text(tr(context, en: 'Play Again', es: 'Jugar de Nuevo')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(tr(context, en: 'Exit', es: 'Salir')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: NvAppBar(
        tickerVisible: AppState.of(context).showTicker.value,
        title: tr(context, en: 'Memory Match', es: 'Memoria'),
        showBack: true,
        extraActions: [
          IconButton(
            onPressed: () {
              _reset();
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: tr(context, en: 'New Game', es: 'Nuevo Juego'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1B3B27).withValues(alpha: 0.3), Colors.black]
              : [const Color(0xFFE8F5E9), Colors.white],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              tr(context, en: 'Matches: $_matches / ${_icons.length}', es: 'Parejas: $_matches / ${_icons.length}'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.8,
                ),
                itemCount: _tiles.length,
                itemBuilder: (context, i) {
                  return _FlipCard(
                    isFlipped: _tiles[i].flipped || _tiles[i].matched,
                    icon: _tiles[i].icon,
                    onTap: () => _tap(i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTileData {
  final IconData icon;
  bool flipped = false;
  bool matched = false;
  _CardTileData({required this.icon});
}

class _FlipCard extends StatelessWidget {
  final bool isFlipped;
  final IconData icon;
  final VoidCallback onTap;

  const _FlipCard({
    required this.isFlipped,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isFlipped ? 180 : 0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, angle, child) {
          final isBack = angle >= 90;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle * pi / 180),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildFront(context),
                  )
                : _buildBack(context),
          );
        },
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3A70B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Icon(icon, color: Colors.white, size: 48),
      ),
    );
  }

  Widget _buildBack(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Image.asset(
          'assets/images/Logo.jpg',
          width: 40,
          opacity: const AlwaysStoppedAnimation(0.3),
        ),
      ),
    );
  }
}

