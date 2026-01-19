import 'dart:math';
import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../../widgets/nv_widgets.dart';

class MazeRunnerScreen extends StatefulWidget {
  const MazeRunnerScreen({super.key});

  @override
  State<MazeRunnerScreen> createState() => _MazeRunnerScreenState();
}

class _MazeRunnerScreenState extends State<MazeRunnerScreen> {
  static const int _rows = 15;
  static const int _cols = 11;
  
  late List<List<bool>> _walls; // true if wall
  late int _pRow, _pCol;
  late int _eRow, _eCol;
  
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _generateNewMaze();
  }

  void _generateNewMaze() {
    // 1. Initialize all as walls
    _walls = List.generate(_rows, (_) => List.filled(_cols, true));
    
    // 2. Recursive Backtracker to carve paths
    // We use a starting point (1,1) avoiding edges to make it cleaner
    _carve(1, 1);
    
    // 3. Set Start and End
    // Start at (1,1)
    _pRow = 1; _pCol = 1;
    _walls[_pRow][_pCol] = false;
    
    // End at bottom right-ish
    _eRow = _rows - 2;
    _eCol = _cols - 2;
    _walls[_eRow][_eCol] = false;

    setState(() {});
  }

  void _carve(int r, int c) {
    _walls[r][c] = false;
    
    final dirs = [[0, 2], [0, -2], [2, 0], [-2, 0]];
    dirs.shuffle(_rand);
    
    for (final d in dirs) {
      final nr = r + d[0];
      final nc = c + d[1];
      
      if (nr > 0 && nr < _rows - 1 && nc > 0 && nc < _cols - 1 && _walls[nr][nc]) {
        // Carve the wall in between
        _walls[r + d[0] ~/ 2][c + d[1] ~/ 2] = false;
        _carve(nr, nc);
      }
    }
  }

  void _move(int dr, int dc) {
    final nr = _pRow + dr;
    final nc = _pCol + dc;
    
    if (nr < 0 || nr >= _rows || nc < 0 || nc >= _cols) return;
    if (_walls[nr][nc]) return;
    
    setState(() {
      _pRow = nr;
      _pCol = nc;
    });
    
    if (_pRow == _eRow && _pCol == _eCol) {
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Victory!', es: 'Victoria!')),
        content: Text(tr(context, en: 'You navigated the jungle!', es: 'Navegaste la selva!')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateNewMaze();
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

    const jungleWall = Color(0xFF1B3B27);
    const junglePath = Color(0xFFE8F5E9);
    const junglePathDark = Color(0xFF0F1A14);

    return Scaffold(
      appBar: NvAppBar(
        title: tr(context, en: 'Jungle Maze', es: 'Laberinto'),
        showBack: true,
        extraActions: [
          IconButton(
            onPressed: _generateNewMaze,
            icon: const Icon(Icons.refresh),
            tooltip: tr(context, en: 'New Maze', es: 'Nuevo Mapa'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1A2E1A), const Color(0xFF0A120A)]
              : [const Color(0xFFE8F5E9), Colors.white],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _cols / _rows,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: jungleWall, width: 4),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Grid Rendering
                          Column(
                            children: List.generate(_rows, (r) => Expanded(
                              child: Row(
                                children: List.generate(_cols, (c) => Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _walls[r][c] 
                                        ? jungleWall 
                                        : (isDark ? junglePathDark : junglePath),
                                      border: Border.all(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: _walls[r][c] 
                                      ? const Icon(Icons.park, size: 10, color: Color(0xFF2E7D32)) 
                                      : null,
                                  ),
                                )),
                              ),
                            )),
                          ),
                          // Goal
                          _PositionedTile(
                            row: _eRow,
                            col: _eCol,
                            rows: _rows,
                            cols: _cols,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, color: Colors.white, size: 16),
                            ),
                          ),
                          // Player (Niña character)
                          _PositionedTile(
                            row: _pRow,
                            col: _pCol,
                            rows: _rows,
                            cols: _cols,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                image: const DecorationImage(
                                  image: AssetImage('assets/images/avatar/nina_verde_256.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _HighEndGamepad(
              onUp: () => _move(-1, 0),
              onDown: () => _move(1, 0),
              onLeft: () => _move(0, -1),
              onRight: () => _move(0, 1),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PositionedTile extends StatelessWidget {
  final int row, col, rows, cols;
  final Widget child;

  const _PositionedTile({
    required this.row,
    required this.col,
    required this.rows,
    required this.cols,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tw = constraints.maxWidth / cols;
        final th = constraints.maxHeight / rows;
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutQuad,
          top: row * th,
          left: col * tw,
          width: tw,
          height: th,
          child: child,
        );
      },
    );
  }
}

class _HighEndGamepad extends StatelessWidget {
  final VoidCallback onUp, onDown, onLeft, onRight;

  const _HighEndGamepad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    const btnSize = 65.0;
    return Column(
      children: [
        _GameButton(icon: Icons.expand_less, onTap: onUp, size: btnSize),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GameButton(icon: Icons.chevron_left, onTap: onLeft, size: btnSize),
            const SizedBox(width: 40),
            _GameButton(icon: Icons.chevron_right, onTap: onRight, size: btnSize),
          ],
        ),
        _GameButton(icon: Icons.expand_more, onTap: onDown, size: btnSize),
      ],
    );
  }
}

class _GameButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const _GameButton({required this.icon, required this.onTap, required this.size});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E5F3C) : const Color(0xFF4CAF50),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.6),
      ),
    );
  }
}
