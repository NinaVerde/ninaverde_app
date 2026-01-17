import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';

class ColoringSandboxScreen extends StatefulWidget {
  const ColoringSandboxScreen({super.key});

  @override
  State<ColoringSandboxScreen> createState() => _ColoringSandboxScreenState();
}

class _ColoringSandboxScreenState extends State<ColoringSandboxScreen> {
  static const int _cols = 18;
  static const int _rows = 12;
  late List<Color> _cells;
  Color _selected = const Color(0xFF4CAF50);

  final List<Color> _palette = const [
    Color(0xFF4CAF50),
    Color(0xFFF3A70B),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF6D4C41),
    Color(0xFF26C6DA),
    Color(0xFFFF7043),
    Color(0xFF2E7D32),
    Color(0xFF283593),
  ];

  @override
  void initState() {
    super.initState();
    _cells = List<Color>.filled(_cols * _rows, Colors.white);
  }

  void _clear() {
    setState(() {
      _cells = List<Color>.filled(_cols * _rows, Colors.white);
    });
  }

  void _sprinkle() {
    final rand = Random();
    setState(() {
      for (var i = 0; i < _cells.length; i++) {
        if (rand.nextDouble() < 0.2) {
          _cells[i] = _palette[rand.nextInt(_palette.length)];
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppState.of(context);

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, code, __) {
        final isEs = code == 'es';
        final title = isEs ? 'Colorear' : 'Coloring Studio';
        final tip = isEs
            ? 'Toca los cuadros para pintar. Elige un color abajo.'
            : 'Tap tiles to paint. Pick a color below.';
        final isDark = theme.brightness == Brightness.dark;
        final tipColor = isDark
            ? theme.colorScheme.surfaceContainerHighest
            : const Color(0xFFF7F1D3);
        return Scaffold(
          appBar: NvAppBar(
            title: title,
            showBack: true,
            extraActions: [
              IconButton(
                tooltip: isEs ? 'Limpiar' : 'Clear page',
                onPressed: _clear,
                icon: const Icon(Icons.layers_clear),
              ),
              IconButton(
                tooltip: isEs ? 'Color al azar' : 'Sprinkle color',
                onPressed: _sprinkle,
                icon: const Icon(Icons.auto_awesome),
              ),
            ],
          ),
          backgroundColor: theme.colorScheme.surface,
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: tipColor,
                child: Text(
                  tip,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Expanded(
                child: AspectRatio(
                  aspectRatio: _cols / _rows,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                    ),
                    itemCount: _cells.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() => _cells[index] = _selected);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(0.3),
                          color: _cells[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _palette
                      .map((c) => GestureDetector(
                            onTap: () => setState(() => _selected = c),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(
                                  color: _selected == c
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
