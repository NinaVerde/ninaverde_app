import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NvVideoOverlay extends StatefulWidget {
  final String? videoUrl; // For network/youtube
  final String? videoAsset; // For local asset
  final String source; // 'asset', 'youtube', 'url'
  final Rect fromRect; // Origin rect for hero animation
  final VoidCallback onClose;

  const NvVideoOverlay({
    super.key,
    this.videoUrl,
    this.videoAsset,
    required this.source,
    required this.fromRect,
    required this.onClose,
  });

  // Self-contained overlay entry manager
  static void showGlobal(
    BuildContext context, {
    String? videoUrl,
    String? videoAsset,
    String source = 'asset',
    required GlobalKey originKey,
    VoidCallback? onClose, // Added callback
  }) {
    // Get the position of the logo
    final renderBox = originKey.currentContext?.findRenderObject() as RenderBox?;
    Rect fromRect = Rect.zero;
    
    if (renderBox != null) {
      final pos = renderBox.localToGlobal(Offset.zero);
      fromRect = pos & renderBox.size;
    } else {
      // Fallback to center if we can't find the logo
      final size = MediaQuery.of(context).size;
      fromRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 120,
        height: 120,
      );
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => NvVideoOverlay(
        videoUrl: videoUrl,
        videoAsset: videoAsset,
        source: source,
        fromRect: fromRect,
        onClose: () {
          entry.remove();
          onClose?.call(); // Chain the callback
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<NvVideoOverlay> createState() => _NvVideoOverlayState();
}

enum _VideoState { loading, ready, error }

class _NvVideoOverlayState extends State<NvVideoOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Rect?> _rectAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _blurAnim;
  
  VideoPlayerController? _vp;
  YoutubePlayerController? _yt;
  _VideoState _state = _VideoState.loading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Longer, more dramatic animation
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Spring curve for that "pop out" effect
    final springCurve = Curves.easeOutBack;
    
    _scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: springCurve),
    );
    
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    
    _blurAnim = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _initVideo();

    // Defer animation setup until build to access MediaQuery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });
  }

  void _startAnimation() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final targetRect = _calculateTargetRect(size);

    _rectAnim = RectTween(
      begin: widget.fromRect,
      end: targetRect,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutCubic,
      ),
    );

    _animCtrl.forward();
  }

  Rect _calculateTargetRect(Size size) {
    // Calculate a nice video size - slightly larger for impact
    double w = size.width * 0.92;
    double h = w * 9 / 16;
    
    // Prevent overflow on narrow/tall screens
    if (h > size.height * 0.85) {
      h = size.height * 0.85;
      w = h * 16 / 9;
    }
    
    // Center vertically but slightly above center for better visual appeal
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.48),
      width: w,
      height: h,
    );
  }

  Future<void> _initVideo() async {
    try {
      if (widget.source == 'youtube') {
        await _initYouTube();
      } else {
        await _initVideoPlayer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _VideoState.error;
          _errorMessage = e.toString();
        });
      }
      debugPrint('Video initialization error: $e');
    }
  }

  Future<void> _initYouTube() async {
    final id = _extractYoutubeId(widget.videoUrl ?? '');
    
    if (id == null) {
      throw Exception('Invalid or missing YouTube URL');
    }

    _yt = YoutubePlayerController.fromVideoId(
      videoId: id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
        enableCaption: false,
        strictRelatedVideos: true,
      ),
    );
    
    if (mounted) {
      setState(() => _state = _VideoState.ready);
    }
  }

  Future<void> _initVideoPlayer() async {
    if (widget.source == 'asset') {
      final assetPath = widget.videoAsset ?? '';
      if (assetPath.isEmpty) {
        throw Exception('No video asset specified');
      }
      _vp = VideoPlayerController.asset(assetPath);
    } else {
      final url = widget.videoUrl ?? '';
      if (url.isEmpty) {
        throw Exception('No video URL specified');
      }
      _vp = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    // Initialize with timeout
    await _vp!.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Video initialization timeout');
      },
    );
    
    await _vp!.setLooping(true);
    await _vp!.setVolume(1.0);
    await _vp!.play();

    if (mounted) {
      setState(() => _state = _VideoState.ready);
    }
  }

  String? _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return uri.queryParameters['v'];
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _vp?.dispose();
    _yt?.close();
    super.dispose();
  }

  Future<void> _close() async {
    // Trigger state update to hide close button smoothly
    if (mounted) setState(() {});
    
    // Reverse the animation with same dramatic effect
    await _animCtrl.reverse();
    
    // Only call onClose after animation completes
    if (mounted) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Animated backdrop with blur effect
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (_, __) {
            return Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: _blurAnim.value,
                    sigmaY: _blurAnim.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.75 * _fadeAnim.value),
                  ),
                ),
              ),
            );
          },
        ),

        // Animated Video Container - the star of the show!
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (ctx, child) {
            final rect = _rectAnim.value ?? widget.fromRect;
            final scale = _scaleAnim.value;
            
            return Positioned.fromRect(
              rect: rect,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      ui.lerpDouble(60, 16, _animCtrl.value)!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.5 * _animCtrl.value,
                        ),
                        blurRadius: 40 * _animCtrl.value,
                        spreadRadius: 5 * _animCtrl.value,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ui.lerpDouble(60, 16, _animCtrl.value)!,
                    ),
                    child: Container(
                      color: Colors.black,
                      child: _buildVideoContent(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Close Button with smooth fade-in and fade-out
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, child) {
            // Only show when animation is mostly complete (> 80%)
            // This creates smooth fade in/out
            final shouldShow = _animCtrl.value > 0.8;
            final opacity = (((_animCtrl.value - 0.8) / 0.2).clamp(0.0, 1.0));
            
            if (!shouldShow) return const SizedBox.shrink();
            
            return Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 20,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: 0.8 + (0.2 * opacity),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: _close,
                      tooltip: 'Close',
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoContent() {
    switch (_state) {
      case _VideoState.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );

      case _VideoState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _close,
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );

      case _VideoState.ready:
        if (_yt != null) {
          return YoutubePlayer(
            controller: _yt!,
            aspectRatio: 16 / 9,
          );
        }

        if (_vp != null && _vp!.value.isInitialized) {
          return Center(
            child: AspectRatio(
              aspectRatio: _vp!.value.aspectRatio,
              child: VideoPlayer(_vp!),
            ),
          );
        }

        return const Center(
          child: Text(
            'Video ready but player unavailable',
            style: TextStyle(color: Colors.white),
          ),
        );
    }
  }
}
