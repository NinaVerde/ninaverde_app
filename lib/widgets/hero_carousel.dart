import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/rendering.dart'; // Unnecessary
import 'dart:ui';
import 'dart:async';
import 'package:vector_math/vector_math_64.dart' as vector;
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
  // We use a simple periodic timer or standard Ticker for auto-play, 
  // but let's stick to AnimationController for frame-synced smoothness if possible.
  // Actually, for a "slow drift" or "page turn", a Timer that triggers animateToPage is often more robust against gesture fighting.
  // However, the user liked the "spinning" (continuous?). Code shows 'jumpTo' drift.
  // Let's keep the drift but make it respectful.

  // late final AnimationController _autoPlayController; // Removed unused
  late final AnimationController _glowController;
  
  double _currentPage = 0;
  bool _isManualInteracting = false;
  // bool _reverseAutoPlay = false; // Simpler to just rotate one way for now unless user asks, or restore it.
  // Let's keep it simple: Forward rotation.

  // The 11 categories
  final List<String> _categories = HeroCategoryConfig.order;
  
  // INFINITE SCROLL: Virtual index space
  static const int _virtualCenter = 10000;
  static const int _realCategoryCount = 11;

  // State listeners
  // late double _currentSpeedCfg; // Removed unused // Seconds per rotation (full cycle?) or speed factor?
  // User asked for "Speed control".
  // The control panel has "seconds per rotation" (5s to 60s).
  // _realCategoryCount items. 
  // So speed = (Total Width) / Seconds.
  // OR speed = (One Page Width) / (Seconds / Count).



  Timer? _autoPlayTimer; // 15s interval timer

  @override
  void initState() {
    super.initState();
    
    // Start at virtual center position
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: _virtualCenter,
    );
    _pageController.addListener(_onPageScroll);

    // Glow pulse effect for active card
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Force initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _currentPage = _virtualCenter.toDouble());
      }
    });

    // Start AutoPlay Timer
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    // SPEED INCREASE: Reduced from 15s to 12s (20% faster)
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (_isManualInteracting || !_pageController.hasClients) return;
      
      // Animate to next page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic, // Smooth "Snap"
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
    
    // React to AutoPlay setting
    final shouldPlay = app.carouselAutoPlay.value;
    if (shouldPlay && !_isManualInteracting) {
      if (!(_autoPlayTimer?.isActive ?? false)) _startAutoPlay();
    } else {
      _stopAutoPlay();
    }

    // _currentSpeedCfg = app.carouselSpeed.value; // Removed unused
  }

  @override
  void didUpdateWidget(HeroCategoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCategory != oldWidget.currentCategory) {
      _scrollToCategory(widget.currentCategory);
    }
  }

  void _scrollToCategory(String category) {
    // ... exact same logic ...
    final targetIndex = _categories.indexOf(category);
    if (targetIndex == -1) return;
    
    final currentVirtualIndex = _pageController.page?.round() ?? _virtualCenter;
    final currentRealIndex = currentVirtualIndex % _realCategoryCount;
    
    int offset = targetIndex - currentRealIndex;
    if (offset > _realCategoryCount ~/ 2) {
      offset -= _realCategoryCount;
    } else if (offset < -_realCategoryCount ~/ 2) {
      offset += _realCategoryCount;
    }
    
    final targetVirtualIndex = currentVirtualIndex + offset;
    
    setState(() => _isManualInteracting = true); // Pause during animation
    _pageController.animateToPage(
      targetVirtualIndex,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    ).then((_) {
       if (mounted) setState(() => _isManualInteracting = false);
    });
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page ?? _virtualCenter.toDouble();
    // Use smaller setState update or ValueNotifier for performance if needed, 
    // but setState is fine for this item count.
    setState(() => _currentPage = page);

    // INFINITE LOOP RESET
    // We only reset if we are NOT animating (user scroll or auto-play drift)? 
    // Actually we can reset silently anytime the pixel offset matches.
    // But jumpToPage might kill momentum.
    // Only reset if we are really far out to avoid jitter.
    if (page > _virtualCenter + 500 || page < _virtualCenter - 500) {
      final int currentOffset = (page % _realCategoryCount).round();
      final int newPage = _virtualCenter + currentOffset;
      if ((page - page.round()).abs() < 0.01) {
        _pageController.jumpToPage(newPage);
      }
    }
  }

  void _onCardTap(int virtualIndex) {
    final realIndex = virtualIndex % _realCategoryCount;
    final cat = _categories[realIndex];
    
    if (cat == HeroCategoryConfig.specialCategory) {
      HapticFeedback.lightImpact();
      return;
    }

    // Stop auto-play temporarily
    setState(() => _isManualInteracting = true);
    // Resume after a delay handled by Listener/Timer? 
    // Actually, let's just animate to it, then let the "idle" timer resume it.

    _pageController.animateToPage(
      virtualIndex,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
    ).then((_) {
      // Don't immediately resume; let user admire selection.
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
    return SizedBox(
      height: 400,
      // RAW LISTENER for better touch detection than NotificationListener
      child: Listener(
        onPointerDown: (_) {
          setState(() => _isManualInteracting = true);
          _stopAutoPlay();
        },
        onPointerUp: (_) {
           // Resume after delay
           Future.delayed(const Duration(seconds: 3), () {
             if (context.mounted && AppState.of(context).carouselAutoPlay.value) {
                setState(() => _isManualInteracting = false);
                _startAutoPlay(); 
             }
           });
        },
        child: PageView.builder(
          controller: _pageController,
          // null itemCount = infinite
          itemBuilder: (context, virtualIndex) {
            final realIndex = virtualIndex % _realCategoryCount;
            final category = _categories[realIndex];
            final catConfig = HeroCategoryConfig.animationFolders[category] ?? 'default';
            
            // ... Math logic (keep existing) ...
            final double dist = (virtualIndex - _currentPage);
            final double distAbs = dist.abs();
            final double scale = (1.0 - (distAbs * 0.12)).clamp(0.82, 1.0);
            final double opacity = (1.0 - (distAbs * 0.35)).clamp(0.45, 1.0);
            final double zPush = distAbs * 25;
            final double rotationY = dist * -0.25; 
            
            // Pass Configurations
            final app = AppState.of(context); // This effectively listens to AppState because it's an InheritedWidget/Provider-like access if wrapping? 
            // Wait, AppState.of(context) returns the state object. 
            // We need to LISTEN to the ValueNotifiers for rebuilds?
            // PageView.builder builds items on demand.
            // If Global Mode changes, we want these items to rebuild.
            // We should wrap the Item in a ValueListenableBuilder for the Mode.
            
            return ValueListenableBuilder<CarouselMode>(
              valueListenable: app.carouselGlobalMode,
              builder: (ctx, globalMode, _) {
                return ValueListenableBuilder<Map<String, CategoryConfig>>(
                  valueListenable: app.categoryConfigs,
                  builder: (ctx, catConfigs, _) {
                    
                    final thisCatCfg = catConfigs[category];
                    final override = thisCatCfg?.modeOverride; // still, animated, or logic for "default"
                    
                    final effectiveMode = (override != null) 
                        ? override 
                        : globalMode;

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
                            // "Stunning" Pop for active card:
                            // Increased Z-push to bring it closer
                            // Reduced rotation more drastically for focused card to flatten it
                            ..translateByVector3(vector.Vector3(0.0, 0.0, isFocused ? -zPush * 0.5 : -zPush)) 
                            ..rotateY(rotationY)
                            ..rotateX(distAbs * -0.05)
                            ..scaleByVector3(vector.Vector3(isFocused ? 1.05 : 1.0, isFocused ? 1.05 : 1.0, 1.0)), // Slight extra scale pop
                          child: GestureDetector(
                            onTap: () => _onCardTap(virtualIndex),
                            onLongPress: () {
                              // Only allow admins/managers to access carousel settings
                              if (app.isManager.value) {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pushNamed('/carousel-settings');
                              }
                            },
                            child: Opacity(
                              opacity: opacity,
                              child: HeroCard(
                                categoryName: category,
                                assetFolder: catConfig,
                                scale: scale,
                                isSelected: isSelected,
                                isFocused: isFocused,
                                pageScrollController: widget.pageScrollController,
                                parallaxOffset: dist * 50.0,
                                glowIntensity: glowIntensity,
                                mode: effectiveMode, // PASS MODE
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                );
              }
            );
          },
        ),
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final String categoryName;
  final String assetFolder;
  final double scale;
  final bool isSelected;
  final bool isFocused;
  final ScrollController pageScrollController;
  final double parallaxOffset;
  final double glowIntensity;
  final CarouselMode mode;

  const HeroCard({
    super.key,
    required this.categoryName,
    required this.assetFolder,
    required this.scale,
    required this.isSelected,
    required this.isFocused,
    required this.pageScrollController,
    required this.parallaxOffset,
    required this.glowIntensity,
    required this.mode,
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
                // Multi-layer shadow for depth
                BoxShadow(
                  color: isSelected 
                    ? Colors.greenAccent.withValues(alpha: 0.7) 
                    : Colors.black.withValues(alpha: 0.6),
                  blurRadius: isSelected ? 50 : 25,
                  spreadRadius: isSelected ? 6 : 1,
                  offset: const Offset(0, 20),
                ),
                if (isSelected) ...[
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.4),
                    blurRadius: 80,
                    spreadRadius: 10,
                    offset: const Offset(0, 30),
                  ),
                ],
                // Atmospheric glow for focused cards
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
                // Animated gradient background for extra depth
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSelected
                        ? [
                            Colors.green.withValues(alpha: 0.1),
                            Colors.black,
                          ]
                        : [
                            Colors.transparent,
                            Colors.black,
                          ],
                    ),
                  ),
                ),
                
                // The Animation with Enhanced Parallax
                Transform.translate(
                  offset: Offset(parallaxOffset, 0),
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    alignment: Alignment.center,
                    minWidth: 450,
                    child: ScrollImageSequence(
                      folder: assetFolder,
                      height: 450,
                      scrollController: pageScrollController,
                      isFocused: isFocused,
                      mode: mode,
                    ),
                  ),
                ),

                // Bottom gradient overlay for text readability
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
                
                // Shimmer effect on focused cards
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

                // Category Name with Elite Typography
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
                                colors: [
                                  Colors.greenAccent,
                                  Colors.green.shade400,
                                ],
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
                          borderRadius: BorderRadius.circular(0),
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
                                  textAlign: TextAlign.left, // Ensure left alignment

                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSelected ? 32 : 30,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                letterSpacing: -0.8,
                                height: 1.1,
                                shadows: [
                                  const Shadow(
                                    color: Colors.black,
                                    blurRadius: 15,
                                    offset: Offset(3, 3),
                                  ),
                                  if (isSelected)
                                    Shadow(
                                      color: Colors.greenAccent.withValues(alpha: 0.5),
                                      blurRadius: 20,
                                      offset: const Offset(0, 0),
                                    ),
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
                
                // VYBZ Indicator (if applicable)
                if (categoryName == HeroCategoryConfig.specialCategory)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.withValues(alpha: 0.8),
                            Colors.deepPurple.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white54, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withValues(alpha: 0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text(
                        'SPECIAL EVENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
