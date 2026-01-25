import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:video_player/video_player.dart'; // Add video support
import 'package:cached_network_image/cached_network_image.dart'; // Add cached image support
import '../config/product_animations_map.dart';
import 'scroll_image_sequence.dart';
import '../state/app_state.dart';

class HeroCategoryCarousel extends StatefulWidget {
  final ScrollController pageScrollController;
  final Function(String category) onCategorySelected;
  final String currentCategory;

  const HeroCategoryCarousel({
    super.key,
    required this.pageScrollController,
    required this.onCategorySelected,
    required this.currentCategory,
  });

  @override
  State<HeroCategoryCarousel> createState() => _HeroCategoryCarouselState();
}

class _HeroCategoryCarouselState extends State<HeroCategoryCarousel>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _glowController;
  
  double _currentPage = 0;
  bool _isManualInteracting = false;
  Timer? _autoPlayTimer;

  // INFINITE SCROLL: Virtual index space
  static const int _virtualCenter = 10000;
  
  // Dynamic list derived from AppState
  List<String> _currentCategories = [];

  @override
  void initState() {
    super.initState();
    // Default initial categories
    _currentCategories = HeroCategoryConfig.order;
    
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: _virtualCenter,
    );
    _pageController.addListener(_onPageScroll);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _currentPage = _virtualCenter.toDouble());
      }
    });

    _startAutoPlay();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _virtualCenter.toDouble();
    setState(() => _currentPage = page);
    
    final count = _currentCategories.length;
    if (count == 0) return;

    if (page > _virtualCenter + 500 || page < _virtualCenter - 500) {
      final int currentOffset = (page % count).round();
      final int newPage = _virtualCenter + currentOffset;
      if ((page - page.round()).abs() < 0.01) {
        _pageController.jumpToPage(newPage);
      }
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    final app = AppState.of(context);
    final durationSec = app.carouselSpeed.value; 
    // We used to use a fixed 12s interval. Now we use the user setting.
    // However, if the user setting is "Speed" (rotation time), we need to calculate interval.
    // Let's stick to a fixed interval for the "Snap" to next page, 
    // OR use the setting to control the interval.
    // If setting is "60s per rotation" and there are 10 items, interval is 6s.
    
    _autoPlayTimer = Timer.periodic(Duration(milliseconds: (durationSec * 1000 / (_currentCategories.isEmpty ? 1 : _currentCategories.length)).round()), (timer) {
      if (_isManualInteracting || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    
    // Sync Categories
    final newOrder = app.categoryOrder.value;
    if (newOrder.isNotEmpty && newOrder != _currentCategories) {
        setState(() {
            _currentCategories = newOrder;
            // TODO: Handle page index shift if length changes drastically? 
            // For now, we accept a potential jump if order changes live.
        });
    }

    final shouldPlay = app.carouselAutoPlay.value;
    final currentSpeed = app.carouselSpeed.value;
    
    // Add listeners if not already done
    if (_lastSpeed == null) {
      _lastSpeed = currentSpeed;
      app.carouselSpeed.addListener(_onSpeedChanged);
    }

    if (shouldPlay && !_isManualInteracting) {
      if (!(_autoPlayTimer?.isActive ?? false)) _startAutoPlay();
    } else {
      _stopAutoPlay();
    }
  }

  double? _lastSpeed;
  void _onSpeedChanged() {
    final speed = AppState.of(context).carouselSpeed.value;
    if (speed != _lastSpeed) {
      _lastSpeed = speed;
      if (AppState.of(context).carouselAutoPlay.value && !_isManualInteracting) {
        _startAutoPlay();
      }
    }
  }

  @override
  void didUpdateWidget(HeroCategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCategory != oldWidget.currentCategory) {
      _scrollToCategory(widget.currentCategory);
    }
  }

  void _scrollToCategory(String category) {
    if (_currentCategories.isEmpty) return;
    final targetIndex = _currentCategories.indexOf(category);
    if (targetIndex == -1) return;
    
    final count = _currentCategories.length;
    final currentVirtualIndex = _pageController.page?.round() ?? _virtualCenter;
    final currentRealIndex = currentVirtualIndex % count;
    
    int offset = targetIndex - currentRealIndex;
    if (offset > count ~/ 2) {
      offset -= count;
    } else if (offset < -count ~/ 2) {
      offset += count;
    }
    
    final targetVirtualIndex = currentVirtualIndex + offset;
    
    setState(() => _isManualInteracting = true); 
    _pageController.animateToPage(
      targetVirtualIndex,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    ).then((_) {
       if (mounted) setState(() => _isManualInteracting = false);
    });
  }

  void _onCardTap(int virtualIndex) {
    final count = _currentCategories.length;
    if (count == 0) return;
    
    final realIndex = virtualIndex % count;
    final cat = _currentCategories[realIndex];
    
    if (cat == HeroCategoryConfig.specialCategory) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _isManualInteracting = true);
    _pageController.animateToPage(
      virtualIndex,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
    ).then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isManualInteracting = false);
      });
    });

    widget.onCategorySelected(cat);
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCategories.isEmpty) return const SizedBox(height: 400);

    return SizedBox(
      height: 400,
      child: Listener(
        onPointerDown: (_) {
          setState(() => _isManualInteracting = true);
          _stopAutoPlay();
        },
        onPointerUp: (_) {
           Future.delayed(const Duration(seconds: 3), () {
             if (context.mounted && AppState.of(context).carouselAutoPlay.value) {
                setState(() => _isManualInteracting = false);
                _startAutoPlay(); 
             }
           });
        },
        child: PageView.builder(
          controller: _pageController,
          itemBuilder: (context, virtualIndex) {
            final count = _currentCategories.length;
            final realIndex = virtualIndex % count;
            final category = _currentCategories[realIndex];
            
            final app = AppState.of(context);
            
            // Listen to Config Changes
            return ValueListenableBuilder<String>(
              valueListenable: app.languageCode,
              builder: (ctx, lang, _) {
                return ValueListenableBuilder<Map<String, CategoryConfig>>(
                  valueListenable: app.categoryConfigs,
                  builder: (ctx, catConfigs, _) {
                    final config = catConfigs[category] ?? const CategoryConfig();
                    
                    // Math
                    final double dist = (virtualIndex - _currentPage);
                    final double distAbs = dist.abs();
                    final double scale = (1.0 - (distAbs * 0.12)).clamp(0.82, 1.0);
                    final double opacity = (1.0 - (distAbs * 0.35)).clamp(0.45, 1.0);
                    final double zPush = distAbs * 25;
                    final double rotationY = dist * -0.25; 

                    final isSelected = widget.currentCategory == category;
                    final isFocused = distAbs < 0.5;

                    return AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        final glowIntensity = isFocused 
                            ? 0.3 + (_glowController.value * 0.3)
                            : 0.0;
                        
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0008)
                            ..translateByVector3(vector.Vector3(0.0, 0.0, isFocused ? -zPush * 0.5 : -zPush)) 
                            ..rotateY(rotationY)
                            ..rotateX(distAbs * -0.05)
                            ..scaleByVector3(vector.Vector3(
                                isFocused ? 1.05 + (_glowController.value * 0.04) : 1.0, 
                                isFocused ? 1.05 + (_glowController.value * 0.04) : 1.0, 
                                1.0)),
                          child: GestureDetector(
                            onTap: () => _onCardTap(virtualIndex),
                            onLongPress: () {
                              if (app.isManager.value) {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pushNamed('/carousel-settings');
                              }
                            },
                            child: Opacity(
                              opacity: opacity,
                              child: HeroCard(
                                categoryName: category,
                                config: config,
                                scale: scale,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                pageScrollController: widget.pageScrollController,
                                parallaxOffset: dist * 50.0,
                                glowIntensity: glowIntensity,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final String categoryName;
  final CategoryConfig config;
  final double scale;
  final bool isSelected;
  final bool isFocused;
  final ScrollController pageScrollController;
  final double parallaxOffset;
  final double glowIntensity;

  const HeroCard({
    super.key,
    required this.categoryName,
    required this.config,
    required this.scale,
    required this.isSelected,
    required this.isFocused,
    required this.pageScrollController,
    required this.parallaxOffset,
    required this.glowIntensity,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                    ? Colors.greenAccent.withValues(alpha: 0.7) 
                    : Colors.black.withValues(alpha: 0.6),
                  blurRadius: isSelected ? 50 : 25,
                  spreadRadius: isSelected ? 6 : 1,
                  offset: const Offset(0, 20),
                ),
                if (isSelected)
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                    blurRadius: 80,
                    spreadRadius: 10,
                    offset: const Offset(0, 30),
                  ),
                if (isFocused)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glowIntensity * 0.3),
                    blurRadius: 60,
                    spreadRadius: 0,
                    offset: const Offset(0, 0),
                  ),
              ],
              border: Border.all(
                color: isSelected 
                  ? Colors.greenAccent.withValues(alpha: 0.9) 
                  : Colors.white.withValues(alpha: isFocused ? 0.3 : 0.1),
                width: isSelected ? 4 : 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Gradient
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                        ? [Colors.green.withValues(alpha: 0.1), Colors.black]
                        : [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
                
                // Content Layer
                Transform.translate(
                  offset: Offset(parallaxOffset, 0),
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.center,
                    minWidth: 450,
                    child: SizedBox(
                      height: 450,
                      child: _buildContent(context),
                    ),
                  ),
                ),

                // Overlays (Gradient, Text, etc)
                _buildOverlays(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (config.effect) {
      case CarouselEffect.still:
        return _buildStillImage();
      case CarouselEffect.video:
        return _buildVideoLoop();
      case CarouselEffect.scrollSequence:
      case CarouselEffect.stopMotion:
        return _buildSequence();
    }
  }

  Widget _buildStillImage() {
    if (config.assetPath != null && config.assetPath!.isNotEmpty) {
      // Check if it's a URL or Network (Firebase Storage URLs start with http)
      if (config.assetPath!.startsWith('http')) {
        return CachedNetworkImage(
            imageUrl: config.assetPath!,
            fit: BoxFit.cover,
            placeholder: (_,__) => Container(color: Colors.black12),
        );
      } else {
        // Assume local asset
        return Image.asset(config.assetPath!, fit: BoxFit.cover);
      }
    }
    // Fallback default still based on folder logic if no override
    // We can use the first frame of the default sequence?
    final folder = HeroCategoryConfig.animationFolders[categoryName] ?? 'default';
    // Just use frame_000 assuming it exists for now, OR a placeholder
    return Image.asset('assets/images/sequences/$folder/frame_000.png', fit: BoxFit.cover, 
       errorBuilder: (_,__,___) => Container(color: Colors.black26), 
    );
  }

  Widget _buildVideoLoop() {
    if (config.videoUrl != null && config.videoUrl!.isNotEmpty) {
      return _VideoPlayerWidget(
        url: config.videoUrl!,
        isFocused: isFocused,
      );
    }
    return _buildStillImage(); // Fallback
  }

  Widget _buildSequence() {
     // Config folder override OR default map
    final folder = config.folderOverride ?? HeroCategoryConfig.animationFolders[categoryName] ?? 'default';
    final frameCount = HeroCategoryConfig.frameCounts[categoryName] ?? 24;
    
    // Convert 'CarouselEffect' -> 'CarouselMode' for the internal widget if compatible, 
    // or just pass params. 
    // ScrollImageSequence expects 'CarouselMode' (Still/Animated). 
    // Effect.scrollSequence == Animated. Effect.stopMotion == Animated (but logic might differ?).
    // Actually ScrollImageSequence implements the "3D Flip". 
    // Stop Motion needs "Frame by Frame on Scroll" OR "Auto Play Loop"?
    // The user said "Stop motion effect we are creating for Microgreens".
    // Microgreens logic currently is essentially a scroll sequence (frames change on scroll).
    // So both are essentially 'ScrollImageSequence' but maybe with different tuning?
    // I'll stick to using ScrollImageSequence for both.
    
    return ScrollImageSequence(
        folder: folder,
        height: 450,
        scrollController: pageScrollController,
        isFocused: isFocused,
        mode: CarouselMode.animated, // Always animate if in this effect
        frameCount: frameCount,
        enableScrubbing: categoryName == 'La Parrillada',
        scrubbingSensitivity: 300.0,
        isTimeLapse: categoryName == 'Microgreens',
    );
  }

  Widget _buildOverlays(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Bottom Gradient
        Container(
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
        
        // Shimmer
        if (isFocused)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: glowIntensity * 0.15),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: Container(color: Colors.white),
            ),
          ),

        // Text
        Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.greenAccent, Colors.green.shade400],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.greenAccent.withValues(alpha: 0.5),
                           blurRadius: 12,
                           spreadRadius: 2,
                         ),
                      ],
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Builder(
                      builder: (context) {
                        final isEn = AppState.of(context).languageCode.value == 'en';
                        final displayName = isEn 
                            ? HeroCategoryConfig.translations[categoryName] ?? categoryName
                            : categoryName;
                        return Text(
                          displayName.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSelected ? 32 : 30,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.8,
                            height: 1.1,
                            shadows: [
                              const Shadow(color: Colors.black, blurRadius: 15, offset: Offset(3, 3)),
                              if (isSelected)
                                Shadow(color: Colors.greenAccent.withValues(alpha: 0.5), blurRadius: 20),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Special Tag
        if (categoryName == HeroCategoryConfig.specialCategory)
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.withValues(alpha: 0.8), Colors.deepPurple.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: const Text(
                'SPECIAL EVENT',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final bool isFocused;
  const _VideoPlayerWidget({required this.url, required this.isFocused});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        _initialized = true;
        _controller.setLooping(true);
        if (widget.isFocused) {
           _controller.play();
        }
        if (mounted) setState(() {}); 
      });
  }

  @override
  void didUpdateWidget(_VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mounted || !_initialized) return;

    if (widget.isFocused && !oldWidget.isFocused) {
      _controller.play();
    } else if (!widget.isFocused && oldWidget.isFocused) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
