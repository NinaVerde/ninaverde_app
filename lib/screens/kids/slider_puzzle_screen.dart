import 'dart:math';
import 'package:flutter/material.dart';
import '../../main.dart';

class SliderPuzzleScreen extends StatefulWidget {
  const SliderPuzzleScreen({super.key});

  @override
  State<SliderPuzzleScreen> createState() => _SliderPuzzleScreenState();
}

class _SliderPuzzleScreenState extends State<SliderPuzzleScreen> {
  static const int _size = 3;
  late List<int> _tiles;
  int _moves = 0;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final tiles = List<int>.generate(_size * _size, (i) => i);
    do {
      tiles.shuffle(_rand);
    } while (!_isSolvable(tiles) || _isSolved(tiles));
    setState(() {
      _tiles = tiles;
      _moves = 0;
    });
  }

  bool _isSolvable(List<int> tiles) {
    int inv = 0;
    for (var i = 0; i < tiles.length; i++) {
      for (var j = i + 1; j < tiles.length; j++) {
        if (tiles[i] != 0 && tiles[j] != 0 && tiles[i] > tiles[j]) {
          inv++;
        }
      }
    }
    return inv % 2 == 0;
  }

  bool _isSolved(List<int> tiles) {
    for (var i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] != i + 1) return false;
    }
    return tiles.last == 0;
  }

  void _move(int index) {
    final empty = _tiles.indexOf(0);
    final row = index ~/ _size;
    final col = index % _size;
    final erow = empty ~/ _size;
    final ecol = empty % _size;
    final isNeighbor = (row == erow && (col - ecol).abs() == 1) ||
        (col == ecol && (row - erow).abs() == 1);
    if (!isNeighbor) return;

    setState(() {
      _tiles[empty] = _tiles[index];
      _tiles[index] = 0;
      _moves++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final solved = _isSolved(_tiles);
    final app = AppState.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor =
        isDark ? const Color(0xFF2E5F3C) : const Color(0xFF4CAF50);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, code, __) {
        final isEs = code == 'es';
        final title = isEs ? 'Rompecabezas' : 'Puzzle Dash';
        final moves = isEs ? 'Movimientos: $_moves' : 'Moves: $_moves';
        final solvedText = isEs ? 'Listo!' : 'You solved it!';
        return Scaffold(
          appBar: NvAppBar(
            title: title,
            showBack: true,
            extraActions: [
              IconButton(
                tooltip: isEs ? 'Mezclar' : 'Shuffle',
                onPressed: _shuffle,
                icon: const Icon(Icons.shuffle),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                moves,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _size,
                      ),
                      itemCount: _tiles.length,
                      itemBuilder: (context, i) {
                        final val = _tiles[i];
                        if (val == 0) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: () => _move(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 6),
                                )
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '$val',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (solved)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    solvedText,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
