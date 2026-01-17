import 'dart:math';
import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/nv_widgets.dart';

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
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final tiles = List<int>.generate(_size * _size, (i) => i);
    // 0 is the empty tile
    do {
      tiles.shuffle(_rand);
    } while (!_isSolvable(tiles) || _isSolved(tiles));
    
    setState(() {
      _tiles = tiles;
      _moves = 0;
      _isInit = true;
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
    // For odd grid size (like 3), solvable if inversions are even
    return inv % 2 == 0;
  }

  bool _isSolved(List<int> tiles) {
    // Solved state: [1, 2, 3, 4, 5, 6, 7, 8, 0]
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

    if (_isSolved(_tiles)) {
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Perfect Fit!', es: 'Perfecto!')),
        content: Text(tr(context, en: 'You solved the Niña Verde puzzle in $_moves moves!', es: 'Resolviste el puzzle de Niña Verde en $_moves movimientos!')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shuffle();
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
    if (!_isInit) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: NvAppBar(
        title: tr(context, en: 'Puzzle Dash', es: 'Rompecabezas'),
        showBack: true,
        extraActions: [
          IconButton(
            onPressed: _shuffle,
            icon: const Icon(Icons.shuffle),
            tooltip: tr(context, en: 'Shuffle', es: 'Mezclar'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [const Color(0xFF1A1A1A), Colors.black]
                : [const Color(0xFFF5F5F5), Colors.white],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              tr(context, en: 'Moves: $_moves', es: 'Movimientos: $_moves'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4CAF50),
                  ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _size,
                        ),
                        itemCount: _tiles.length,
                        itemBuilder: (context, i) {
                          final val = _tiles[i];
                          if (val == 0) return const SizedBox.shrink();

                          // val 1 means part at (0,0), val 2 means part at (0,1), etc.
                          final correctIdx = val - 1;
                          final row = correctIdx ~/ _size;
                          final col = correctIdx % _size;

                          // Alignment calculation for 3x3:
                          // col 0 -> -1.0, col 1 -> 0.0, col 2 -> 1.0
                          final double alX = (col / (_size - 1)) * 2 - 1;
                          final double alY = (row / (_size - 1)) * 2 - 1;

                          return GestureDetector(
                            onTap: () => _move(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: const AssetImage('assets/images/Logo.jpg'),
                                  alignment: Alignment(alX, alY),
                                  fit: BoxFit.cover,
                                  scale: 3.0, // Scale to show only 1/3 of the image
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withValues(alpha: 0.1),
                                ),
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  '$val',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                tr(context, 
                  en: 'Solve the Niña Verde logo by sliding tiles!', 
                  es: '¡Resuelve el logo de Niña Verde deslizando los cuadros!'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
