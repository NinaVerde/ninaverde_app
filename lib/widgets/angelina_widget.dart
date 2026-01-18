import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui' as ui;
import '../theme/brand_colors.dart';

enum AngelinaPose {
  conciergeWaving,
  conciergeDog,
  conciergeHappy,
  conciergeTablet,
  waitressMenu,
  waitressFullBody,
  bartender,
  bartenderPose,
  cocktailCasual,
  beachTowel1,
  beachTowel2,
  // New poses for registration flow
  languageWelcome,
  themeSelector,
  currencyCoins,
  microphoneFriendly,
  // Bubble avatar headshot
  bubbleAvatar,
}

class AngelinaWidget extends StatelessWidget {
  final AngelinaPose pose;
  final String? speech;
  final VoidCallback? onTap;
  
  /// If true, shows a smaller circular/avatar version (good for headers)
  final bool compact;

  /// Custom height constraint (defaults depend on [compact])
  final double? height;

  const AngelinaWidget({
    super.key,
    required this.pose,
    this.speech,
    this.onTap,
    this.compact = false,
    this.height,
  });

  String get _assetPath {
    switch (pose) {
      case AngelinaPose.conciergeWaving:
      case AngelinaPose.conciergeHappy:
        return 'assets/images/angelina/angelina_concierge_waving.jpg';
      case AngelinaPose.conciergeDog:
      case AngelinaPose.conciergeTablet:
        return 'assets/images/angelina/angelina_concierge_dog.jpg';
      case AngelinaPose.waitressMenu:
        return 'assets/images/angelina/angelina_transparent_fix.png';
      case AngelinaPose.waitressFullBody:
        return 'assets/images/angelina/angelina_waitress_fullbody.jpg';
      case AngelinaPose.bartender:
        return 'assets/images/angelina/angelina_bartender.jpg';
      case AngelinaPose.bartenderPose:
        return 'assets/images/angelina/angelina_bartender_pose.jpg';
      case AngelinaPose.cocktailCasual:
        return 'assets/images/angelina/angelina_cocktail_casual.png';
      case AngelinaPose.beachTowel1:
        return 'assets/images/angelina/angelina_beach_towel.jpg';
      case AngelinaPose.beachTowel2:
        return 'assets/images/angelina/angelina_beach_towel_2.jpg';
      case AngelinaPose.languageWelcome:
        return 'assets/images/angelina/angelina_language_welcome.png';
      case AngelinaPose.themeSelector:
        return 'assets/images/angelina/angelina_theme_selector.png';
      case AngelinaPose.currencyCoins:
        return 'assets/images/angelina/angelina_currency_coins.png';
      case AngelinaPose.microphoneFriendly:
        return 'assets/images/angelina/angelina_microphone_friendly.png';
      case AngelinaPose.bubbleAvatar:
        return 'assets/images/angelina/angelina_bubble_avatar.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    final size = height ?? 50.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: nvAccentOrange, width: 2),
          image: DecorationImage(
            image: AssetImage(_assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildFull(BuildContext context) {
    // Default image height if not specified
    final h = height ?? 300.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: h,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // The Image with "Breathing" Idle Animation
            Container(
              constraints: BoxConstraints(maxHeight: h),
               // Use a specialized alignment if needed, usually topCenter or center
              child: Image.asset(
                _assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideX(begin: 0.1, end: 0, curve: Curves.easeOut)
              // The "Living" Loop: Subtle breathing effect (scale 1.0 -> 1.02 -> 1.0)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.02,
                duration: 2000.ms,
                curve: Curves.easeInOutSine,
              ),
            ),

            // Glassmorphic Speech Bubble with "Bibbles"
            if (speech != null && speech!.isNotEmpty)
              Positioned(
                // Position ABOVE the image box (negative top allowed by Clip.none)
                top: -80, 
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       // MAIN BUBBLE
                       ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.75), // Translucent
                              borderRadius: BorderRadius.circular(24).copyWith(
                                bottomLeft: const Radius.circular(4),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              speech!,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A), // Almost black for contrast
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                fontFamily: 'Inter',
                                height: 1.3, 
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ).animate()
                       .scale(
                          duration: 800.ms, 
                          curve: Curves.elasticOut,
                          alignment: Alignment.bottomCenter
                        )
                       .fade(duration: 400.ms),

                      // BIBBLES (Speech Trail)
                      // Leading down towards the character
                      Padding(
                        padding: const EdgeInsets.only(right: 40, top: 4), // Offset to align with bubble tail
                        child: Align(
                          alignment: Alignment.centerLeft, // Align towards left side of bubble
                          child: Column(
                            children: [
                              _GlassBibble(size: 10, offset: const Offset(20, 0)),
                              const SizedBox(height: 4),
                              _GlassBibble(size: 6, offset: const Offset(12, 0)),
                            ],
                          ).animate(delay: 200.ms).fade().scale(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassBibble extends StatelessWidget {
  final double size;
  final Offset offset;

  const _GlassBibble({required this.size, required this.offset});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
