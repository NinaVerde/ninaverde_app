import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';

class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  final List<IconData> _icons = const [
    Icons.icecream,
    Icons.local_pizza,
    Icons.local_cafe,
    Icons.ramen_dining,
    Icons.cookie,
    Icons.park,
  ];

  late List<_CardTile> _tiles;
  int? _firstIndex;
  bool _lock = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final pairs = [..._icons, ..._icons];
    pairs.shuffle(Random());
    _tiles = pairs.map((e) => _CardTile(icon: e)).toList();
    _firstIndex = null;
    _lock = false;
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
      setState(() {
        _tiles[first].matched = true;
        _tiles[index].matched = true;
        _firstIndex = null;
      });
    } else {
      _lock = true;
      Future.delayed(const Duration(milliseconds: 700), () {
        setState(() {
          _tiles[first].flipped = false;
          _tiles[index].flipped = false;
          _firstIndex = null;
          _lock = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final solved = _tiles.every((t) => t.matched);
    final app = AppState.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final faceColor =
        isDark ? const Color(0xFF2E5F3C) : const Color(0xFF4CAF50);
    final matchColor =
        isDark ? const Color(0xFFF3A70B) : const Color(0xFFF3A70B);

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, code, __) {
        final isEs = code == 'es';
        final title = isEs ? 'Memoria' : 'Memory Match';
        final status = solved
            ? (isEs ? 'Muy bien!' : 'Great memory!')
            : (isEs ? 'Encuentra las parejas' : 'Find all the pairs');
        return Scaffold(
          appBar: NvAppBar(
            title: title,
            showBack: true,
            extraActions: [
              IconButton(
                tooltip: isEs ? 'Nuevo juego' : 'New game',
                onPressed: () => setState(_reset),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              const SizedBox(height: 12),
              Text(
                status,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _tiles.length,
                  itemBuilder: (context, i) {
                    final tile = _tiles[i];
                    return GestureDetector(
                      onTap: () => _tap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: tile.flipped || tile.matched
                              ? matchColor
                              : faceColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 10,
                              offset: Offset(0, 6),
                            )
                          ],
                        ),
                        child: Icon(
                          tile.flipped || tile.matched ? tile.icon : Icons.help,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardTile {
  final IconData icon;
  bool flipped = false;
  bool matched = false;

  _CardTile({required this.icon});
}

