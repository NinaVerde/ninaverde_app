import 'package:flutter/material.dart';
import '../../main.dart';

class MazeRunnerScreen extends StatefulWidget {
  const MazeRunnerScreen({super.key});

  @override
  State<MazeRunnerScreen> createState() => _MazeRunnerScreenState();
}

class _MazeRunnerScreenState extends State<MazeRunnerScreen> {
  final List<String> _maze = const [
    'S..#......',
    '##.#.####.',
    '...#....#.',
    '.###.##.#.',
    '.#....#.#.',
    '.#.####.#.',
    '.#......#.',
    '.######.#.',
    '...#....#.',
    '...#..#.E.',
  ];

  late int _row;
  late int _col;

  @override
  void initState() {
    super.initState();
    _row = 0;
    _col = 0;
  }

  void _move(int dr, int dc) {
    final nr = _row + dr;
    final nc = _col + dc;
    if (nr < 0 || nc < 0 || nr >= _maze.length || nc >= _maze[0].length) {
      return;
    }
    if (_maze[nr][nc] == '#') return;
    setState(() {
      _row = nr;
      _col = nc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _maze.length;
    final cols = _maze[0].length;
    final finished = _maze[_row][_col] == 'E';
    final app = AppState.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallColor = isDark ? const Color(0xFF1B3B27) : const Color(0xFF2E7D32);
    final pathColor = isDark ? const Color(0xFF0F1A14) : const Color(0xFFE8F5E9);
    final startColor = isDark ? const Color(0xFF3A7E4C) : const Color(0xFF8BC34A);
    final endColor = isDark ? const Color(0xFF24538F) : const Color(0xFF1E88E5);
    final playerColor = isDark ? const Color(0xFFF3A70B) : const Color(0xFFF3A70B);

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, code, __) {
        final isEs = code == 'es';
        final title = isEs ? 'Laberinto' : 'Jungle Maze';
        final status = finished
            ? (isEs ? 'Lo lograste!' : 'You made it!')
            : (isEs ? 'Encuentra la salida' : 'Find the exit');
        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
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
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cols / rows,
                    child: Column(
                      children: List.generate(rows, (r) {
                        return Expanded(
                          child: Row(
                            children: List.generate(cols, (c) {
                              final ch = _maze[r][c];
                              Color color;
                              if (r == _row && c == _col) {
                                color = playerColor;
                              } else if (ch == '#') {
                                color = wallColor;
                              } else if (ch == 'E') {
                                color = endColor;
                              } else if (ch == 'S') {
                                color = startColor;
                              } else {
                                color = pathColor;
                              }
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ControlPad(
                onUp: () => _move(-1, 0),
                onDown: () => _move(1, 0),
                onLeft: () => _move(0, -1),
                onRight: () => _move(0, 1),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ControlPad extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _ControlPad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onUp,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onLeft,
              icon: const Icon(Icons.keyboard_arrow_left),
            ),
            const SizedBox(width: 24),
            IconButton(
              onPressed: onRight,
              icon: const Icon(Icons.keyboard_arrow_right),
            ),
          ],
        ),
        IconButton(
          onPressed: onDown,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }
}
