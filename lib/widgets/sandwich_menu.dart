// lib/widgets/sandwich_menu.dart
import 'dart:ui'; // For BackdropFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../theme/brand_colors.dart' as brand;

/// --------------------------------------------------------------------------
/// NEURO-AESTHETIC COMPONENT: THE "LIQUID GLASS" MENU
/// --------------------------------------------------------------------------
/// This replaces the standard "Sheet" with an immersive, semi-transparent
/// portal. It uses "staggered" animation logic to make items feel like they
/// are "flowing" into place, not just appearing.
/// --------------------------------------------------------------------------
class SandwichMenuButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SandwichMenuButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    // "Elite" Stylish Button
    // Glass/Gradient effect with custom iconography
    return Animate(
      effects: [ScaleEffect(duration: 300.ms, curve: Curves.easeOutBack)],
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          // Deep Emerald "Portal" Color
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1B4D3E),
              const Color(0xFF0F2E24),
            ],
          ),
          shape: BoxShape.circle, 
          borderRadius: null, // Circle shape doesn't need radius
          // "Squircle" feeling (Standard Radius 16 is close to optimal)
          border: Border.all(
            color: Colors.white.withOpacity(0.2), // Light catcher
            width: 1.5,
          ),
          boxShadow: [
            // Inner Glow (simulated via gradient, but adding outer glow here)
            BoxShadow(
              color: const Color(0xFF1B4D3E).withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: () {
              HapticFeedback.mediumImpact(); // Sensory Confirmation
              onTap?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CustomPaint(painter: _LiquidMenuPainter()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SandwichMenuSheet extends StatelessWidget {
  const SandwichMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, langCode, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final isEs = langCode == 'es';

        // 1. THE GLASS CONTAINER
        // Instead of a solid background, we use a ClipRRect + BackdropFilter.
        // This makes the menu feel like a physical lens placed over the app.
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Heavy Blur
            child: Container(
              height: MediaQuery.of(context).size.height * 0.82, // Taller, more grandeur
              decoration: BoxDecoration(
                // "Aurora" Gradient Overlay (Subtle)
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.black.withOpacity(0.8),
                          const Color(0xFF1A1A1A).withOpacity(0.9),
                        ]
                      : [
                          Colors.white.withOpacity(0.85),
                          const Color(0xFFF0F0F0).withOpacity(0.95),
                        ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.white60,
                    width: 1.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 2. THE "HANDLE" (Visual Affordance)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 8),
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms),

                  // 3. THE "SENTIENT" HEADER
                  // Addressing the user directly, inviting action.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 16),
                    child: Column(
                      children: [
                        // Animated Icon (Pulse)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [brand.nvAccentOrange, const Color(0xFFFF8E53)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brand.nvAccentOrange.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.grid_view_rounded, 
                            color: Colors.white, 
                            size: 32
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(1,1), end: const Offset(1.1, 1.1), duration: 2.seconds),

                        const SizedBox(height: 16),
                        
                        Text(
                          isEs ? 'Explora tu Mundo' : 'Explore Your World',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            fontSize: 24,
                            // Use gradient text if possible, but standard for now for stability
                            color: isDark ? Colors.white : const Color(0xFF1B4D3E),
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 8),

                        Text(
                          isEs ? '¿Qué experiencia deseas hoy?' : 'What experience do you desire today?',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. THE "WATERFALL" MENU ITEMS
                  // Using AnimateList to stagger them naturally.
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _LiquidMenuItem(
                          title: isEs ? 'Reservaciones' : 'Reservations',
                          subtitle: isEs ? 'Tu mesa te espera' : 'Your table awaits',
                          icon: Icons.calendar_month_rounded, 
                          gradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          onTap: () {
                             Navigator.pop(context);
                             _handleReservation(context);
                          },
                        ),
                        _LiquidMenuItem(
                          title: isEs ? 'Iniciar Pedido' : 'Start Order',
                          subtitle: isEs ? 'Sabor directo a ti' : 'Flavor delivered to you',
                          icon: Icons.local_dining_rounded,
                          gradient: const [Color(0xFF4ECDC4), Color(0xFF26A69A)],
                          onTap: () {
                            Navigator.pop(context);
                            _handleStartOrder(context);
                          },
                        ),
                        _LiquidMenuItem(
                          title: isEs ? 'Sobre Nosotros' : 'Our Story',
                          subtitle: isEs ? 'Pasión y tradición' : 'Passion & tradition',
                          icon: Icons.auto_stories_rounded,
                          gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                          onTap: () {
                            Navigator.pop(context);
                            _handleAbout(context);
                          },
                        ),
                        _LiquidMenuItem(
                          title: isEs ? 'Ubicación' : 'Find Us',
                          subtitle: isEs ? 'El camino al paraíso' : 'The path to paradise',
                          icon: Icons.map_rounded,
                          gradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
                          onTap: () {
                             Navigator.pop(context);
                            _handleLocation(context);
                          },
                        ),
                        _LiquidMenuItem(
                          title: 'Kidz Zone',
                          subtitle: isEs ? 'Diversión sin fin' : 'Endless fun',
                          icon: Icons.videogame_asset_rounded,
                          gradient: const [Color(0xFFFA709A), Color(0xFFFEE140)],
                          onTap: () {
                             Navigator.pop(context);
                             Navigator.pushNamed(context, '/kids');
                          },
                        ),
                      ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOutQuad),
                    ),
                  ),
                  
                  // Footer
                   Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Opacity(
                      opacity: 0.4,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                    ),
                  ).animate().fadeIn(delay: 800.ms),
                ],
              ),

            ),
          ),
        );
      },
    );
  }

  // -- Handlers --
  void _handleReservation(BuildContext context) {
    // Navigate to Angelina chat with reservation context
    Navigator.pushNamed(
      context,
      '/contact',
      arguments: {
        'initialMessage': AppState.of(context).languageCode.value == 'es'
            ? 'Quiero hacer una reservación'
            : 'I want to make a reservation',
      },
    );
  }

  void _handleStartOrder(BuildContext context) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    showDialog(context: context, builder: (c) => _LiquidOrderTypeDialog(isEs: isEs));
  }

  void _handleAbout(BuildContext context) {
     showDialog(context: context, builder: (c) => _AboutDialog());
  }

  void _handleLocation(BuildContext context) {
     showDialog(context: context, builder: (c) => _LocationDialog());
  }
}

/// A List Item that feels like holding a physical card
class _LiquidMenuItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _LiquidMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // "Glass Card" background
              color: isDark 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.white24,
                width: 1,
              ),
              boxShadow: [
                 BoxShadow(
                   color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                   blurRadius: 15,
                   offset: const Offset(0, 5),
                 )
              ],
            ),
            child: Row(
              children: [
                // Gradient Icon Container
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20), // Super rounded
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6)
                      )
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                
                const SizedBox(width: 20),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.arrow_forward_ios_rounded, 
                  size: 16, 
                  color: isDark ? Colors.white24 : Colors.black12
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// PAINTERS (The Art)
// ---------------------------------------------------------------------------

class _LiquidMenuPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    
    // Abstract "Menu" representation - simpler, more elegant lines
    // Not just 3 bars. 
    // Top bar: shorter, left aligned
    canvas.drawLine(Offset(w * 0.2, h * 0.3), Offset(w * 0.8, h * 0.3), paint);
    
    // Middle bar: full width
    canvas.drawLine(Offset(w * 0.1, h * 0.5), Offset(w * 0.9, h * 0.5), paint);
    
    // Bottom bar: shorter, right aligned
    canvas.drawLine(Offset(w * 0.2, h * 0.7), Offset(w * 0.8, h * 0.7), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// DIALOGS (Restyled similarly to maintain flow)
// ---------------------------------------------------------------------------

class _LiquidOrderTypeDialog extends StatelessWidget {
  final bool isEs;

  const _LiquidOrderTypeDialog({required this.isEs});

  @override
  Widget build(BuildContext context) {
    // Reusing the _LiquidMenuItem aesthetic but in a Dialog
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // Focus only on dialog
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, spreadRadius: 5)
            ],
          ),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 isEs ? 'Elige tu camino' : 'Choose Your Path',
                 style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
               ),
               const SizedBox(height: 24),
               // Options...
               // For brevity, using simple buttons here (but you could use _LiquidMenuItem too)
               _SimpleOption(
                 icon: Icons.delivery_dining, 
                 label: isEs ? 'Delivery' : 'Delivery', 
                 color: const Color(0xFF4ECDC4),
                 onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'delivery'}); }
               ),
               const SizedBox(height: 12),
               _SimpleOption(
                 icon: Icons.shopping_bag, 
                 label: isEs ? 'Recoger' : 'Pickup', 
                 color: const Color(0xFFFF6B6B),
                 onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'pickup'}); }
               ),
               const SizedBox(height: 12),
               _SimpleOption(
                 icon: Icons.table_restaurant, 
                 label: isEs ? 'Comer Aquí' : 'Dine In', 
                 color: const Color(0xFF667EEA),
                 onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'dine-in'}); }
               ),
             ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

// Simple helper for the dialog to keep code clean
class _SimpleOption extends StatelessWidget {
  final IconData icon; 
  final String label; 
  final Color color; 
  final VoidCallback onTap;
  const _SimpleOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    )
    .animate(delay: 200.ms) // Fixed delay for simplicity
    .fadeIn(duration: 400.ms)
    .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic);
  }
}

// ---------------------------------------------------------------------------
// RICH CONTENT DIALOGS (Adopted from Translations Branch)
// ---------------------------------------------------------------------------

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEs = AppState.of(context).languageCode.value == 'es';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
                  : [Colors.white, const Color(0xFFF5F5F5)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_rounded,
                size: 64,
                color: brand.nvAccentOrange,
              ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                'Niña Verde',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: brand.nvAccentOrange,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEs
                    ? 'Bienvenido a Niña Verde, donde la tradición nicaragüense se encuentra con la innovación culinaria. Ofrecemos una experiencia gastronómica única con sabores auténticos y un servicio excepcional.'
                    : 'Welcome to Niña Verde, where Nicaraguan tradition meets culinary innovation. We offer a unique dining experience with authentic flavors and exceptional service.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand.nvAccentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isEs ? 'Cerrar' : 'Close'),
              ),
            ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

class _LocationDialog extends StatelessWidget {
  const _LocationDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEs = AppState.of(context).languageCode.value == 'es';

    return BackdropFilter(
       filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
       child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF1A1A1A), const Color(0xFF2D2D2D)]
                  : [Colors.white, const Color(0xFFF5F5F5)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 64,
                color: brand.nvAccentOrange,
              ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text(
                isEs ? 'Nuestra Ubicación' : 'Our Location',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEs
                    ? 'Managua, Nicaragua\n\nHorario:\nLunes - Domingo\n11:00 AM - 10:00 PM'
                    : 'Managua, Nicaragua\n\nHours:\nMonday - Sunday\n11:00 AM - 10:00 PM',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand.nvAccentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(isEs ? 'Cerrar' : 'Close'),
              ),
            ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
      )
    );
  }
}
