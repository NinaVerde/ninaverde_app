import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart'; // Unused
// import 'dart:ui'; // Unnecessary
// // import 'dart:math' as math; // Unused // Unused
import '../state/app_state.dart';

class ScrollImageSequence extends StatefulWidget {
  final String folder;
  final int frameCount;
  final ScrollController? scrollController;
  final bool isFocused;
  final double height;
  final CarouselMode mode;

  const ScrollImageSequence({
    super.key,
    required this.folder,
    this.frameCount = 60,
    this.scrollController,
    this.isFocused = false,
    required this.height,
    this.mode = CarouselMode.animated,
  });

  @override
  State<ScrollImageSequence> createState() => _ScrollImageSequenceState();
}

class _ScrollImageSequenceState extends State<ScrollImageSequence>
    with TickerProviderStateMixin {

  late AnimationController _introController;
  late AnimationController _warpController;
  bool _introPlayed = false;
  bool _imageLoaded = false;
  String? _cachedImagePath;

  @override
  void initState() {
    super.initState();
    
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _warpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    // Preload image
    _cachedImagePath = 'assets/images/sequences/${widget.folder}/frame_000.png';
    // _preloadImage() moved to didChangeDependencies to safely access context

    if (widget.isFocused) {
      _playIntro();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadImage();
  }

  void _preloadImage() {
    if (_cachedImagePath == null) return;
    
    // Preload the asset image
    precacheImage(AssetImage(_cachedImagePath!), context).then((_) {
      if (mounted) {
        setState(() => _imageLoaded = true);
      }
    }).catchError((error) {
      if (mounted) {
        // If preload fails, we still want to try rendering the Image widget (which might work, or might hit errorBuilder)
        // But crucially, we must hide the shimmer so the fallback is visible.
        setState(() {
           _imageLoaded = true; 
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScrollImageSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && !oldWidget.isFocused) {
      _playIntro();
    }
  }

  void _playIntro() {
    _introController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _introPlayed = true);
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _warpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. STILL MODE
    if (widget.mode == CarouselMode.still) {
      final assetPath = 'assets/images/sequences/${widget.folder}/frame_000.png';
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              assetPath,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _buildFallback(error: "Still Mode Asset Not Found"),
            ),
             if (widget.isFocused)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        _introController,
        _warpController,
        if (widget.scrollController != null) widget.scrollController!,
      ]),
      builder: (context, _) {
        // Calculate dynamic warp effects based on scroll
        final double scrollProgress = (widget.scrollController != null && widget.scrollController!.hasClients)
            ? (widget.scrollController!.position.pixels / 500).clamp(0.0, 1.0)
            : 0.0;

        // Enhanced 10D warp effects
        final double introProgress = _introController.value;
        final double warpPulse = _warpController.value;
        
        // Rotation removed as per request
        // final double baseRotation = ...
        // final double scrollRotation = ...
        // final double totalRotation = ...
        
        // Scale: Grows during intro, then breathes
        final double introScale = _introPlayed
            ? 1.0
            : (0.8 + (introProgress * 0.2));
        
        final double breathingScale = 1.0 + (warpPulse * 0.03);
        final double scrollScale = 1.0 + (scrollProgress * 0.05);
        final double totalScale = introScale * breathingScale * scrollScale;
        
        // Opacity: Always visible once loaded
        // const double opacity = 1.0; // Unused

        final assetPath = _cachedImagePath ?? 'assets/images/sequences/${widget.folder}/frame_000.png';

        return LayoutBuilder(
          builder: (context, constraints) {
            // Use explicit sizing from constraints - THIS IS KEY TO MAKING IMAGES WORK
            final width = constraints.maxWidth.isFinite ? constraints.maxWidth : widget.height * 1.5;
            
            return SizedBox(
              width: width,
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image - must have explicit size
                  SizedBox(
                    width: width,
                    height: widget.height,
                    // removed color: Colors.black to avoid black box borders when scaled
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(totalScale, totalScale, 1.0), // Use 3 args to resolve deprecation 1.0), // Use 3 args for standard scale, or explicit scale calculation
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (frame != null && !_imageLoaded) {
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (mounted && !_imageLoaded) {
                                 setState(() => _imageLoaded = true);
                               }
                             });
                          }
                          return child; 
                        },
                        errorBuilder: (context, error, stackTrace) {
                          if (!_imageLoaded) {
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (mounted && !_imageLoaded) setState(() => _imageLoaded = true);
                             });
                          }
                          return _buildFallback(error: "Err: $assetPath");
                        },
                      ),
                    ),
                  ),
                  
                  // Bottom gradient for text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.0, 0.60, 0.85, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    );
}

  Widget _buildFallback({String? error}) {
    return AnimatedBuilder(
      animation: _warpController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Colors.black, Colors.blueAccent, _warpController.value * 0.3)!,
                Color.lerp(Colors.deepPurple, Colors.black, _warpController.value * 0.5)!,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category,
                  size: 50 + (_warpController.value * 10),
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.folder.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.white30,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                if (error != null) ...[
                   const SizedBox(height: 8),
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16.0),
                     child: Text(
                       error,
                       textAlign: TextAlign.center,
                       style: const TextStyle(
                         color: Colors.redAccent, 
                         fontSize: 10
                       ),
                     ),
                   )
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
