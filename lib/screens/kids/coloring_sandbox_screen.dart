import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/nv_widgets.dart';

class ColoringSandboxScreen extends StatefulWidget {
  const ColoringSandboxScreen({super.key});

  @override
  State<ColoringSandboxScreen> createState() => _ColoringSandboxScreenState();
}

class _ColoringSandboxScreenState extends State<ColoringSandboxScreen> {
  final List<List<Offset?>> _paths = [[]];
  final List<Color> _pathColors = [const Color(0xFF4CAF50)];
  final List<double> _pathWidths = [5.0];
  
  Color _selectedColor = const Color(0xFF4CAF50);
  double _selectedWidth = 5.0;

  final List<Color> _palette = const [
    Color(0xFF4CAF50),
    Color(0xFFF3A70B),
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFF2E7D32),
    Color(0xFF283593),
    Colors.black,
    Colors.white,
  ];

  void _clear() {
    setState(() {
      _paths.clear();
      _paths.add([]);
      _pathColors.clear();
      _pathColors.add(_selectedColor);
      _pathWidths.clear();
      _pathWidths.add(_selectedWidth);
    });
  }

  void _undo() {
    if (_paths.length > 1 || (_paths.isNotEmpty && _paths[0].isNotEmpty)) {
      setState(() {
        if (_paths.last.isEmpty) {
          _paths.removeLast();
          _pathColors.removeLast();
          _pathWidths.removeLast();
        }
        _paths.last.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: NvAppBar(
        tickerVisible: AppState.of(context).showTicker.value,
        title: tr(context, en: 'Coloring Studio', es: 'Estudio de Color'),
        showBack: true,
        extraActions: [
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo),
            tooltip: tr(context, en: 'Undo', es: 'Deshacer'),
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep),
            tooltip: tr(context, en: 'Clear', es: 'Limpiar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background Guide
                Center(
                  child: Opacity(
                    opacity: 0.1,
                    child: Image.asset(
                      'assets/images/avatar/nina_verde_base.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Drawing Canvas
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _paths.last.add(details.localPosition);
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _paths.last.add(details.localPosition);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _paths.add([]);
                      _pathColors.add(_selectedColor);
                      _pathWidths.add(_selectedWidth);
                    });
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _DrawingPainter(
                        paths: _paths,
                        colors: _pathColors,
                        widths: _pathWidths,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tool Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Width Slider
                  Row(
                    children: [
                      const Icon(Icons.brush, size: 16),
                      Expanded(
                        child: Slider(
                          value: _selectedWidth,
                          min: 2,
                          max: 30,
                          activeColor: _selectedColor,
                          onChanged: (v) => setState(() => _selectedWidth = v),
                        ),
                      ),
                      const Icon(Icons.brush, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Color Palette
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _palette.map((c) {
                        final isSelected = _selectedColor == c;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = c;
                              _pathColors[_pathColors.length - 1] = c;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            width: isSelected ? 42 : 36,
                            height: isSelected ? 42 : 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                              ] : null,
                            ),
                          ),
                        );
                      }).toList(),
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

class _DrawingPainter extends CustomPainter {
  final List<List<Offset?>> paths;
  final List<Color> colors;
  final List<double> widths;

  _DrawingPainter({
    required this.paths,
    required this.colors,
    required this.widths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      if (path.isEmpty) continue;

      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = widths[i]
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      for (int j = 0; j < path.length - 1; j++) {
        if (path[j] != null && path[j + 1] != null) {
          canvas.drawLine(path[j]!, path[j + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
