import 'package:flutter/material.dart';
import '../state/app_state.dart';

class ScrollImageSequence extends StatefulWidget {
  final String folder;
  final int frameCount;
  final ScrollController? scrollController;
  final bool isFocused;
  final double height;
  final CarouselMode mode;
  final bool enableScrubbing;
  final double scrubbingSensitivity;
  final bool isTimeLapse;

  const ScrollImageSequence({
    super.key,
    required this.folder,
    this.frameCount = 60,
    this.scrollController,
    this.isFocused = false,
    required this.height,
    this.mode = CarouselMode.animated,
    this.enableScrubbing = false,
    this.scrubbingSensitivity = 300.0,
    this.isTimeLapse = false,
  });

  @override
  State<ScrollImageSequence> createState() => _ScrollImageSequenceState();
}

class _ScrollImageSequenceState extends State<ScrollImageSequence>
    with TickerProviderStateMixin {

  late AnimationController _introController;
  late AnimationController _warpController;
  late AnimationController _timeLapseController;
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

    _timeLapseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Loop full sequence in 4s
    );

    // Preload image
    _cachedImagePath = 'assets/images/sequences/${widget.folder}/frame_000.png';
    // _preloadImage() moved to didChangeDependencies to safely access context

    if (widget.isFocused) {
      _playEffects();
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

    // Generic precache for scrubbing-enabled sequences
    if (widget.enableScrubbing && widget.frameCount > 1) {
       for (int i = 1; i < widget.frameCount; i++) {
          precacheImage(AssetImage('assets/images/sequences/${widget.folder}/frame_${i.toString().padLeft(3, '0')}.png'), context);
       }
    }
  }

  @override
  void didUpdateWidget(covariant ScrollImageSequence oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Resume effects when focused, stop when lost focus
    if (widget.isFocused && !oldWidget.isFocused) {
      _playEffects();
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _stopEffects();
    }
  }

  void _playEffects() {
    // 1. Play Intro
    _introController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _introPlayed = true);
      }
    });

    // 2. Resume warp/breathing
    if (!_warpController.isAnimating) {
      _warpController.repeat(reverse: true);
    }
    
    // 3. Play Timelapse
    if (widget.isTimeLapse && !_timeLapseController.isAnimating) {
      _timeLapseController.repeat();
    }
  }

  void _stopEffects() {
    _warpController.stop(); 
    _timeLapseController.stop(); 
    // We don't reset introPlayed because we don't want it to 'pop' again if we scroll back quickly,
    // unless the user wants that. For "stop immediately", stopping the breathing is key.
  }

  @override
  void dispose() {
    _introController.dispose();
    _warpController.dispose();
    _timeLapseController.dispose();
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
        _timeLapseController,
        if (widget.isFocused && widget.scrollController != null) widget.scrollController!,
      ]),
      builder: (context, _) {
        // Calculate dynamic warp effects based on scroll
        final double scrollProgress = (widget.scrollController != null && widget.scrollController!.hasClients)
            ? (widget.scrollController!.position.pixels / 500).clamp(0.0, 1.0)
            : 0.0;

        // Enhanced 10D warp effects
        final double introProgress = _introController.value;
        final double warpPulse = _warpController.value;
        
        // Rotation: Subtle breathing rotation only (no spin entrance)
        // Disable for Time-Lapse to ensure stability
        final double baseRotation = widget.isTimeLapse ? 0.0 : (warpPulse * 0.02); 
        
        final double scrollRotation = scrollProgress * 0.15;
        final double totalRotation = baseRotation + scrollRotation;
        
        // Scale: Grows during intro, then breathes
        final double introScale = _introPlayed
            ? 1.0
            : (0.8 + (introProgress * 0.2));
        
        final double breathingScale = widget.isTimeLapse ? 1.0 : (1.0 + (warpPulse * 0.03));
        final double scrollScale = 1.0 + (scrollProgress * 0.05);
        final double totalScale = introScale * breathingScale * scrollScale;
        
        // Opacity: Always visible once loaded
        const double opacity = 1.0;

        String assetPath;
        if (widget.isTimeLapse) {
            // TimeLapse Mode: Loop frames 0 to N based on controller
            final int frameIndex = (_timeLapseController.value * (widget.frameCount - 1)).floor();
            assetPath = 'assets/images/sequences/${widget.folder}/frame_${frameIndex.toString().padLeft(3, '0')}.png';
        } else if (widget.enableScrubbing && widget.frameCount > 1) {
            // Scrubbing Logic
            if (widget.isFocused) {
               final double scrollOffset = widget.scrollController?.hasClients == true 
                  ? widget.scrollController!.position.pixels 
                  : 0.0;
              
               // Sensitivity: complete sequence over 'scrubbingSensitivity' pixels
               final double scrollSpan = widget.scrubbingSensitivity;
               final double progress = (scrollOffset.clamp(0.0, scrollSpan)) / scrollSpan;
               final int frameIndex = (progress * (widget.frameCount - 1)).round().clamp(0, widget.frameCount - 1);
               assetPath = 'assets/images/sequences/${widget.folder}/frame_${frameIndex.toString().padLeft(3, '0')}.png';
            } else {
               // BACKGROUND LOCK: Force frame 0 (or stay at last frame? frame 0 is safer/cleaner)
               assetPath = 'assets/images/sequences/${widget.folder}/frame_000.png';
            }
        } else {
            // Standard Static/Breathing Logic
            assetPath = _cachedImagePath ?? 'assets/images/sequences/${widget.folder}/frame_000.png';
        }

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
                        ..rotateZ(totalRotation)
                        ..scale(totalScale, totalScale),
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
