import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../widgets/angelina_widget.dart';
import '../theme/brand_colors.dart' as brand;
import '../state/app_state.dart';

/// Universal Angelina chat bubble overlay for user-facing screens
/// Excludes admin/owner screens
class AngelinaBubbleOverlay extends StatefulWidget {
  const AngelinaBubbleOverlay({super.key});

  @override
  State<AngelinaBubbleOverlay> createState() => _AngelinaBubbleOverlayState();
}

class _AngelinaBubbleOverlayState extends State<AngelinaBubbleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Offset _dragOffset = Offset.zero;
  bool _minimized = false;
  bool _hidden = false;
  Timer? _greetingTimer;
  Timer? _greetingHideTimer;
  String? _greeting;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    
    // Show greeting after a delay
    _greetingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _greeting = _getGreeting();
        });
        // Hide greeting after 5 secs
        _greetingHideTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _greeting = null);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update greeting if language changes while visible
    if (_greeting != null) {
      setState(() {
        _greeting = _getGreeting();
      });
    }
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';
    
    if (hour < 12) {
      return isEs ? '¡Buenos días corazón!' : 'Good morning, darling!';
    } else if (hour < 18) {
      return isEs ? '¡Buenas tardes amor!' : 'Good afternoon, hun!';
    } else {
      return isEs ? '¡Buenas noches! ¿Todo tuani?' : 'Evening! Everything tuani?';
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _greetingTimer?.cancel();
    _greetingHideTimer?.cancel();
    super.dispose();
  }

  void _restore() {
    setState(() {
      _hidden = false;
      _minimized = false;
      _dragOffset = Offset.zero;
      _greeting = _getGreeting();
    });
  }

  void _handleDragEnd() {
    final dx = _dragOffset.dx;
    setState(() {
      if (dx < -80) {
        _hidden = true;
      } else if (dx > 80) {
        _minimized = true;
      }
      _dragOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _restore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Angelina',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
      onPanEnd: (_) => _handleDragEnd(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final glow = 0.5 + (_pulse.value * 0.5);
          final size = _minimized ? 50.0 : 80.0;
          
          return Transform.translate(
            offset: _dragOffset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speech Bubble
                if (!_minimized && _greeting != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _greeting!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ).animate().fade().scale(),

                // Angelina Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: brand.nvAccentOrange
                            .withValues(alpha: _minimized ? 0.2 : glow * 0.5),
                        blurRadius: _minimized ? 10 : 25,
                        spreadRadius: _minimized ? 2 : 5,
                      )
                    ],
                  ),
                  child: AngelinaWidget(
                    pose: AngelinaPose.bubbleAvatar,
                    compact: true,
                    height: size,
                    onTap: _minimized 
                      ? _restore 
                      : () => Navigator.pushNamed(context, '/contact'),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(period: 10.seconds))
                .shake(delay: 5.seconds, duration: 1.seconds, hz: 3, rotation: 0.1)
                .shimmer(delay: 5.seconds, duration: 1.seconds, color: Colors.white54),
              ],
            ),
          );
        },
      ),
    );
  }
}
