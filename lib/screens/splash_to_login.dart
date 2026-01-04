// lib/screens/splash_to_login.dart
// INTRO LOGO POP → FLASH0 (NV) → POWERED → FLASH1 (Biz) → BY → FLASH2 (Biz)
// → BIZ APPS VIDEO (enlarged + bloom + trimmed end matte) → FINAL NV REVEAL → Login

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'login_screen.dart';

// -------- Brand palettes --------
const Color kBizTint = Color(0xFF2D8CFF);
const Color kBizTintSoft = Color(0xFF9FC2FF);
const Color kNvOrange = Color(0xFFF3A70B);
const Color kNvGreenDark = Color(0xFF022F18);

// Translate helper for gradient sheen
class _GradientTranslate extends GradientTransform {
  final Offset offset;
  const _GradientTranslate(this.offset);
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.identity()..translate(offset.dx, offset.dy);
}

class SplashToLoginScreen extends StatefulWidget {
  const SplashToLoginScreen({super.key});
  @override
  State<SplashToLoginScreen> createState() => _SplashToLoginScreenState();
}

enum _Phase {
  introLogo,
  flash0,
  powered,
  flash1,
  by,
  flash2,
  video,
  finalReveal,
  done
}

class _SplashToLoginScreenState extends State<SplashToLoginScreen>
    with TickerProviderStateMixin {
  // Timings
  static const poweredDuration = Duration(milliseconds: 1200);
  static const byDuration = Duration(milliseconds: 1200);
  static const flashDuration = Duration(milliseconds: 520);
  static const introLogoDuration = Duration(milliseconds: 720);
  static const finalRevealDuration = Duration(milliseconds: 900);

  // Video
  late final VideoPlayerController _video;
  bool _videoReady = false;
  late final AnimationController _videoBloom;
  late final Animation<double> _videoScale;
  late final Animation<double> _videoGlow;

  // Animations
  late final AnimationController _introLogoCtrl;
  late final AnimationController _flash0;
  late final AnimationController _flash1;
  late final AnimationController _flash2;
  late final AnimationController _finalReveal;

  // Phase + navigation guard
  _Phase _phase = _Phase.introLogo;
  bool _navigated = false;

  // Final whoosh guard
  bool _finalWhooshSent = false;

  // Watchdog so "video" phase can’t hang
  DateTime? _videoPhaseStart;
  Timer? _videoWatchdog;

  @override
  void initState() {
    super.initState();

    // Video
    _video = VideoPlayerController.asset(
      'assets/videos/Illuminated_Circles_Remastered_1080p.mp4',
    )
      ..setLooping(false)
      ..initialize().then((_) async {
        try {
          await _video.setVolume(1.0);
        } catch (_) {}
        if (mounted) setState(() => _videoReady = true);
      });

    // Bloom/settle
    _videoBloom = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _videoScale = Tween<double>(begin: 1.06, end: 1.0).animate(
      CurvedAnimation(parent: _videoBloom, curve: Curves.easeOutCubic),
    );
    _videoGlow = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _videoBloom, curve: Curves.easeOut),
    );

    // Controllers
    _introLogoCtrl =
        AnimationController(vsync: this, duration: introLogoDuration);
    _flash0 = AnimationController(vsync: this, duration: flashDuration);
    _flash1 = AnimationController(vsync: this, duration: flashDuration);
    _flash2 = AnimationController(vsync: this, duration: flashDuration);
    _finalReveal =
        AnimationController(vsync: this, duration: finalRevealDuration);

    _runSequence();
  }

  // ------- SFX: spawn a fresh low-latency player per whoosh -------
  Future<void> _playWhoosh([double volume = 1.0]) async {
    final p = AudioPlayer();
    try {
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.play(
        AssetSource('videos/648538__audiopapkin__cinematic-woosh-sfx-001.wav'),
        volume: volume.clamp(0.0, 1.0),
      );
    } catch (_) {}
    // dispose when done (and also after a timeout as a safety)
    unawaited(p.onPlayerComplete.first.then((_) => p.dispose()));
    unawaited(
        Future.delayed(const Duration(seconds: 4)).then((_) => p.dispose()));
  }

  Future<void> _runSequence() async {
    // Intro pop + light whoosh during bloom (unchanged)
    setState(() => _phase = _Phase.introLogo);
    unawaited(() async {
      await Future.delayed(const Duration(milliseconds: 260));
      await _playWhoosh(0.95);
    }());
    await _introLogoCtrl.forward();
    _introLogoCtrl.reset();

    // FLASH 0 (NV) — intro → POWERED
    await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash0);
    await _flash0.forward();
    _flash0.reset();

    // POWERED (holds)
    setState(() => _phase = _Phase.powered);
    await Future.delayed(poweredDuration);

    // FLASH 1 (Biz) — POWERED → BY
    await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash1);
    await _flash1.forward();
    _flash1.reset();

    // BY (holds)
    setState(() => _phase = _Phase.by);
    await Future.delayed(byDuration);

    // FLASH 2 (Biz) — BY → Video
    await _playWhoosh(1.0);
    setState(() => _phase = _Phase.flash2);
    await _flash2.forward();
    _flash2.reset();

    // Video
    setState(() => _phase = _Phase.video);
    if (_videoReady) {
      _enterVideoPhase();
    } else {
      // Fallback if init lags
      await Future.delayed(const Duration(seconds: 2));
      _doFinalReveal();
    }
  }

  void _enterVideoPhase() {
    _finalWhooshSent = false;
    _videoPhaseStart = DateTime.now();

    // Kick playback + bloom
    try {
      _video.play();
    } catch (_) {}
    _videoBloom.forward();

    // Polling loop to keep the exact timing you wanted
    unawaited(_waitForVideoEnd());

    // Watchdog: ensure we never hang here (duration + ~2s, clamped)
    final dur = _video.value.isInitialized
        ? _video.value.duration
        : const Duration(seconds: 5);
    final watchdogDelay = Duration(
      milliseconds: (dur.inMilliseconds + 2000).clamp(3000, 12000),
    );
    _videoWatchdog?.cancel();
    _videoWatchdog = Timer(watchdogDelay, () {
      if (mounted && _phase == _Phase.video) {
        _doFinalReveal();
      }
    });
  }

  Future<void> _waitForVideoEnd() async {
    while (mounted && _phase == _Phase.video) {
      if (_video.value.isInitialized) {
        final pos = _video.value.position;
        final dur = _video.value.duration;
        if (dur > Duration.zero) {
          final remain = dur - pos;

          // Final whoosh ~1.0s before the wipe
          if (!_finalWhooshSent &&
              remain <= const Duration(milliseconds: 1000)) {
            _finalWhooshSent = true;
            unawaited(_playWhoosh(1.0));
          }

          // Start final reveal near the end
          if (remain <= const Duration(milliseconds: 140)) {
            break;
          }
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (mounted) _doFinalReveal();
  }

  Future<void> _doFinalReveal() async {
    if (!mounted) return;

    // Stop watchdog once we move on
    _videoWatchdog?.cancel();
    _videoWatchdog = null;

    // Do NOT replay whoosh here; it already fired ~1s earlier.
    setState(() => _phase = _Phase.finalReveal);
    await _finalReveal.forward();
    _finalReveal.reset();
    _goToLogin();
  }

  void _goToLogin() {
    if (_navigated) return;
    _navigated = true;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (ctx, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  void dispose() {
    _videoWatchdog?.cancel();
    _introLogoCtrl.dispose();
    _flash0.dispose();
    _flash1.dispose();
    _flash2.dispose();
    _finalReveal.dispose();
    _videoBloom.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loginPreview = const LoginScreen();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            switch (_phase) {
              _Phase.introLogo => _IntroLogoPop(controller: _introLogoCtrl),
              _Phase.powered => const _TitleCard(text: 'POWERED', isBiz: true),
              _Phase.by => const _TitleCard(text: 'BY', isBiz: true),
              _Phase.video => _VideoStage(
                  controller: _video,
                  scale: _videoScale,
                  glowStrength: _videoGlow,
                  baseWidthFactor: 0.78,
                  enlarge: 1.5, // +50%
                  maxWidthFactor: 0.98,
                  verticalOffset: -0.02, // slight lift
                ),
              _Phase.flash0 ||
              _Phase.flash1 ||
              _Phase.flash2 ||
              _Phase.finalReveal ||
              _Phase.done =>
                const SizedBox.shrink(),
            },

            if (_phase == _Phase.flash0)
              _RadialFlash(
                controller: _flash0,
                center: Alignment.center,
                coreColor: Colors.white,
                tintInner: kNvOrange,
                tintOuter: kNvGreenDark.withOpacity(0.85),
              ),
            if (_phase == _Phase.flash1)
              _RadialFlash(
                controller: _flash1,
                center: Alignment.center,
                coreColor: Colors.white,
                tintInner: kBizTint,
                tintOuter: kBizTintSoft,
              ),
            if (_phase == _Phase.flash2)
              _RadialFlash(
                controller: _flash2,
                center: Alignment.center,
                coreColor: Colors.white,
                tintInner: kBizTint,
                tintOuter: kBizTintSoft,
              ),
            if (_phase == _Phase.finalReveal)
              _FinalBurstReveal(
                controller: _finalReveal,
                login: loginPreview,
                center: Alignment.center,
                coreColor: Colors.white,
                tintInner: kNvOrange,
                tintOuter: kNvGreenDark.withOpacity(0.75),
              ),

            // Skip
            Positioned(
              right: 16,
              top: 16 + MediaQuery.of(context).padding.top,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _goToLogin,
                child: const Text('Skip'),
              ),
            ),

            // Bottom safety mask (in case anything still creeps in)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 8,
              child:
                  DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Pieces ===================

class _IntroLogoPop extends StatelessWidget {
  final AnimationController controller;
  const _IntroLogoPop({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.isAnimating) controller.forward();
    final scale = Tween<double>(begin: 0.86, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    final flash = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            Center(
              child: Transform.scale(
                scale: scale.value,
                child: SizedBox(
                  width: MediaQuery.of(context).size.shortestSide * 0.38,
                  child: Image.asset('assets/images/app_icon_foreground.png',
                      fit: BoxFit.contain),
                ),
              ),
            ),
            // centered flash
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: ui.lerpDouble(0.05, 1.15, flash.value)!,
                    colors: [
                      Colors.white
                          .withOpacity(ui.lerpDouble(1.0, 0.0, flash.value)!),
                      Colors.white
                          .withOpacity(ui.lerpDouble(0.85, 0.0, flash.value)!),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            _RippleRing(progress: flash.value, center: Alignment.center),
          ],
        );
      },
    );
  }
}

class _TitleCard extends StatefulWidget {
  final String text;
  final bool isBiz;
  const _TitleCard({required this.text, this.isBiz = false});
  @override
  State<_TitleCard> createState() => _TitleCardState();
}

class _TitleCardState extends State<_TitleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _sheen;
  late final Animation<double> _glowDelay;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _sheen = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.10, 0.80, curve: Curves.easeOutCubic));
    _glowDelay = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.18, 1.0, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final fontSize = (size.shortestSide * 0.20);

    final sweepA = widget.isBiz ? kBizTintSoft : kNvOrange;
    final sweepB = widget.isBiz ? kBizTint : kNvGreenDark;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _sheen.value;
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // main type
              Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: fontSize,
                  letterSpacing: 2.0,
                  height: 1.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.85 * _glowDelay.value),
                      blurRadius: ui.lerpDouble(16, 0, 1 - _glowDelay.value)!,
                    ),
                    Shadow(
                      color: Colors.white.withOpacity(0.28 * _glowDelay.value),
                      blurRadius: ui.lerpDouble(36, 0, 1 - _glowDelay.value)!,
                    ),
                  ],
                ),
              ),
              // subtle chromatic fringe (same fontSize so no tiny duplicate text)
              Transform.translate(
                offset: const Offset(1.2, 0.0),
                child: Opacity(
                  opacity: 0.08,
                  child: Text(widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: fontSize,
                        letterSpacing: 2.0,
                        height: 1.0,
                        color: Colors.redAccent,
                      )),
                ),
              ),
              Transform.translate(
                offset: const Offset(-1.2, 0.0),
                child: Opacity(
                  opacity: 0.08,
                  child: Text(widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: fontSize,
                        letterSpacing: 2.0,
                        height: 1.0,
                        color: Colors.cyanAccent,
                      )),
                ),
              ),
              // sheen sweep
              ShaderMask(
                shaderCallback: (rect) {
                  final w = rect.width;
                  final x = ui.lerpDouble(-w * 0.6, w * 1.2, t)!;
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      sweepA.withOpacity(0.10),
                      sweepB.withOpacity(0.25),
                      sweepA.withOpacity(0.10),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.42, 0.5, 0.58, 1.0],
                    transform: _GradientTranslate(Offset(x, 0)),
                  ).createShader(rect);
                },
                blendMode: BlendMode.srcATop,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: fontSize,
                    letterSpacing: 2.0,
                    height: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Video stage with +50% enlarge and trimmed end matte (no center scrub)
class _VideoStage extends StatefulWidget {
  final VideoPlayerController controller;
  final Animation<double> scale;
  final Animation<double> glowStrength;
  final double baseWidthFactor;
  final double enlarge;
  final double maxWidthFactor;
  final double verticalOffset;

  const _VideoStage({
    required this.controller,
    required this.scale,
    required this.glowStrength,
    this.baseWidthFactor = 0.78,
    this.enlarge = 1.5,
    this.maxWidthFactor = 0.98,
    this.verticalOffset = -0.02,
    Key? key,
  }) : super(key: key);

  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  bool get _atTail {
    if (_dur == Duration.zero) return false;
    final remain = _dur - _pos;
    return remain <= const Duration(milliseconds: 1800);
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
    _onTick();
  }

  @override
  void didUpdateWidget(covariant _VideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTick);
      widget.controller.addListener(_onTick);
      _onTick();
    }
  }

  void _onTick() {
    final v = widget.controller.value;
    if (!v.isInitialized) return;
    setState(() {
      _pos = v.position;
      _dur = v.duration;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    if (!v.isInitialized)
      return const Center(child: CircularProgressIndicator.adaptive());

    final vidSize = v.size;
    final screen = MediaQuery.of(context).size;

    final desiredW = screen.width * widget.baseWidthFactor * widget.enlarge;
    final targetW = desiredW.clamp(0.0, screen.width * widget.maxWidthFactor);
    final targetH = targetW * (vidSize.height / vidSize.width);

    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.scale, widget.glowStrength]),
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, screen.height * widget.verticalOffset),
                child: Transform.scale(
                  scale: widget.scale.value,
                  child: SizedBox(
                    width: targetW,
                    height: targetH,
                    child: Stack(
                      children: [
                        Positioned.fill(child: VideoPlayer(widget.controller)),

                        // very subtle radial edge matte (kept away from logo center)
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, 0.15),
                                radius: 0.95,
                                colors: [
                                  Colors.transparent,
                                  Color.fromARGB(14, 0, 0, 0),
                                  Color.fromARGB(36, 0, 0, 0),
                                ],
                                stops: [0.78, 0.90, 1.0],
                              ),
                            ),
                            child: SizedBox.expand(),
                          ),
                        ),

                        // end “creep killer” — only at very bottom, shallower
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _atTail ? 1.0 : 0.0,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: targetH * 0.16, // was 0.22
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color.fromARGB(0, 0, 0, 0),
                                      Color.fromARGB(220, 0, 0, 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // entrance glow
              IgnorePointer(
                child: Opacity(
                  opacity: widget.glowStrength.value * 0.7,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, 0.08),
                        radius: 0.65,
                        colors: [
                          Color.fromARGB(77, 255, 255, 255),
                          Color.fromARGB(20, 255, 255, 255),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadialFlash extends StatelessWidget {
  final AnimationController controller;
  final Alignment center;
  final Color coreColor;
  final Color tintInner;
  final Color tintOuter;
  const _RadialFlash({
    required this.controller,
    required this.center,
    required this.coreColor,
    required this.tintInner,
    required this.tintOuter,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isAnimating) controller.forward();
    final curve = CurvedAnimation(
        parent: controller, curve: const Cubic(0.2, 0.0, 0.0, 1.0));
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        final t = curve.value;
        final radius = ui.lerpDouble(0.06, 1.15, t)!;
        final intensity = (1.0 - t * 0.9).clamp(0.0, 1.0);
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: center,
                    radius: radius,
                    colors: [
                      coreColor.withOpacity(1.0 * intensity),
                      tintInner.withOpacity(0.65 * intensity),
                      tintOuter.withOpacity(0.25 * intensity),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.25, 0.55, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              _RippleRing(progress: t, center: center),
              _TinySpecks(progress: t, center: center),
            ],
          ),
        );
      },
    );
  }
}

class _FinalBurstReveal extends StatelessWidget {
  final AnimationController controller;
  final Widget login;
  final Alignment center;
  final Color coreColor;
  final Color tintInner;
  final Color tintOuter;

  const _FinalBurstReveal({
    required this.controller,
    required this.login,
    required this.center,
    required this.coreColor,
    required this.tintInner,
    required this.tintOuter,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isAnimating) controller.forward();
    final curve =
        CurvedAnimation(parent: controller, curve: Curves.easeInOutCubic);
    return AnimatedBuilder(
      animation: curve,
      builder: (_, __) {
        final t = curve.value;
        final radius = ui.lerpDouble(0.06, 1.20, t)!;
        final fade =
            CurvedAnimation(parent: controller, curve: Curves.easeOut).value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: fade, child: login),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: center,
                    radius: radius,
                    colors: [
                      coreColor.withOpacity(ui.lerpDouble(1.0, 0.0, t)!),
                      tintInner.withOpacity(ui.lerpDouble(0.65, 0.0, t)!),
                      tintOuter.withOpacity(ui.lerpDouble(0.18, 0.0, t)!),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.28, 0.62, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
            _RippleRing(progress: t, center: center),
            _TinySpecks(progress: t, center: center),
          ],
        );
      },
    );
  }
}

class _RippleRing extends StatelessWidget {
  final double progress; // 0..1
  final Alignment center;
  const _RippleRing({required this.progress, required this.center});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _RippleRingPainter(progress: progress, center: center),
        size: Size.infinite,
      );
}

class _RippleRingPainter extends CustomPainter {
  final double progress; // 0..1
  final Alignment center;
  _RippleRingPainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final c = Offset(size.width * (center.x * 0.5 + 0.5),
        size.height * (center.y * 0.5 + 0.5));
    final maxR = size.longestSide * 0.9;
    final r = ui.lerpDouble(20, maxR, Curves.easeOut.transform(progress))!;
    final w = ui.lerpDouble(6, 1, progress)!;
    final paint = Paint()
      ..color = Colors.white.withOpacity((1.0 - progress) * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawCircle(c, r, paint);
  }

  @override
  bool shouldRepaint(covariant _RippleRingPainter old) =>
      old.progress != progress || old.center != center;
}

class _TinySpecks extends StatelessWidget {
  final double progress; // 0..1
  final Alignment center;
  const _TinySpecks({required this.progress, required this.center});
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _SpeckPainter(progress: progress, center: center),
          size: Size.infinite,
        ),
      );
}

class _SpeckPainter extends CustomPainter {
  final double progress;
  final Alignment center;
  static const _count = 26;
  final List<Offset> _seeds = List.generate(
      _count, (i) => Offset(math.cos(i) * (i + 1), math.sin(i) * (i + 1)));

  _SpeckPainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05 || progress >= 0.95) return;
    final origin = Offset(size.width * (center.x * 0.5 + 0.5),
        size.height * (center.y * 0.5 + 0.5));
    final rng = math.Random(7);
    final spread = ui.lerpDouble(8, size.longestSide * 0.55, progress)!;
    final alpha =
        (ui.lerpDouble(0.65, 0.0, progress)! * 255).clamp(0, 255).toInt();
    final paint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < _count; i++) {
      final theta = rng.nextDouble() * math.pi * 2;
      final d = rng.nextDouble() * spread;
      final o = Offset(math.cos(theta) * d, math.sin(theta) * d);
      final p = origin + o + _seeds[i] * 0.6;
      final r = ui.lerpDouble(0.5, 1.8, 1 - progress)!;
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeckPainter old) =>
      old.progress != progress || old.center != center;
}
