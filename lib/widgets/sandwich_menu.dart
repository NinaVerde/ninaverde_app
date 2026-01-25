// lib/widgets/sandwich_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../theme/brand_colors.dart' as brand;
import 'nv_widgets.dart';

/// Premium sandwich menu for customer-facing navigation
class SandwichMenuButton extends StatelessWidget {
  final VoidCallback? onTap;

  const SandwichMenuButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    // "Elite" Stylish Button
    // Glass/Gradient effect with custom iconography
    return Container(
      margin: const EdgeInsets.all(8),
        color: const Color(0xFF1B4D3E), // Dark Forest Green (Hardcoded to ensure match if brand var missing) 
        shape: BoxShape.circle, // Xbox 360 button was circular. Assuming user wants circle? Or staying rect? 
        // User said: "border around it that makes it look like a button on a flat surface that is indented, something like the main button on an xbox 360"
        // The xbox 360 button was circular. But this menu button is likely square/rounded-rect in strict layout?
        // Let's stick to rounded rect (14) but add the bevels.
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.15), // Subtle rim
          width: 2,
        ),
        boxShadow: [
          // "Indented" feel:
          // Neumorphism usually uses Light top-left, Dark bottom-right for popped OUT.
          // For Indented: Dark top-left, Light bottom-right (inner shadow). 
          // Flutter BoxShadows are outset. To fake inset, we need a stack or a specific library.
          // BUT "button on a flat surface that is indented" might mean the button ITSELF is in a divot?
          // Let's try a strong dark shadow Top-Left and Light Bottom-Right to make it look "Pressed In" or "Recessed".
          
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(2, 2),
            blurRadius: 4,
            inset: true, // Flutter doesn't support inset: true in basic BoxShadow!
          ),
          // We can't do inset easily.
          // Let's do the "Xbox Ring" style which is a Silver Border with a Glow.
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.6), // The "Lit up green" glow from the ring?
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10.0), // increased padding slightly for icon breathing room
            child: SizedBox(
                width: 24, 
                height: 24,
                child: CustomPaint(painter: _EliteMenuPainter()),
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
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

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1A1A),
                      const Color(0xFF2D2D2D),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF5F5F5),
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ).animate().fadeIn().slideY(begin: -0.5, end: 0),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            brand.nvAccentOrange,
                            brand.nvAccentOrange.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brand.nvAccentOrange.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEs ? '¿Qué deseas hacer?' : 'What would you like?',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isEs ? 'Elige una opción' : 'Choose an option',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.2, end: 0),
                    ),
                  ],
                ),
              ),

              const Divider(height: 32),

              // Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _MenuItem(
                      icon: Icons.event_available_rounded,
                      iconGradient: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                      titleEn: 'Make Reservations',
                      titleEs: 'Hacer Reservación',
                      subtitleEn: 'Book a table or plan an event',
                      subtitleEs: 'Reserva una mesa o planea un evento',
                      onTap: () {
                        Navigator.pop(context);
                        _handleReservation(context);
                      },
                      delay: 0,
                    ),
                    _MenuItem(
                      icon: Icons.shopping_bag_rounded,
                      iconGradient: const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
                      titleEn: 'Start an Order',
                      titleEs: 'Iniciar Pedido',
                      subtitleEn: 'Pickup, delivery, dine-in, or preorder',
                      subtitleEs: 'Recoger, entrega, comer aquí o preordenar',
                      onTap: () {
                        Navigator.pop(context);
                        _handleStartOrder(context);
                      },
                      delay: 100,
                    ),
                    _MenuItem(
                      icon: Icons.info_rounded,
                      iconGradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                      titleEn: 'About Nina Verde',
                      titleEs: 'Sobre Nina Verde',
                      subtitleEn: 'Our story and values',
                      subtitleEs: 'Nuestra historia y valores',
                      onTap: () {
                        Navigator.pop(context);
                        _handleAbout(context);
                      },
                      delay: 200,
                    ),
                    _MenuItem(
                      icon: Icons.location_on_rounded,
                      iconGradient: const [Color(0xFFF093FB), Color(0xFFF5576C)],
                      titleEn: 'Location',
                      titleEs: 'Ubicación',
                      subtitleEn: 'Find us and get directions',
                      subtitleEs: 'Encuéntranos y obtén direcciones',
                      onTap: () {
                        Navigator.pop(context);
                        _handleLocation(context);
                      },
                      delay: 300,
                    ),
                    _MenuItem(
                      icon: Icons.games_rounded,
                      iconGradient: const [Color(0xFFFA709A), Color(0xFFFEE140)],
                      titleEn: 'Kidz Gamez Zone',
                      titleEs: 'Zona de Juegoz',
                      subtitleEn: 'Fun games for kids',
                      subtitleEs: 'Juegoz divertidos para niños',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/kids');
                      },
                      delay: 400,
                    ),
                  ],
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isEs ? 'Desliza hacia abajo para cerrar' : 'Swipe down to close',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  textAlign: TextAlign.center,
                ),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        );
      },
    );
  }

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
    showDialog(
      context: context,
      builder: (context) => _OrderTypeDialog(isEs: isEs),
    );
  }

  void _handleAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AboutDialog(),
    );
  }

  void _handleLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _LocationDialog(),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String titleEn;
  final String titleEs;
  final String subtitleEn;
  final String subtitleEs;
  final VoidCallback onTap;
  final int delay;

  const _MenuItem({
    required this.icon,
    required this.iconGradient,
    required this.titleEn,
    required this.titleEs,
    required this.subtitleEn,
    required this.subtitleEs,
    required this.onTap,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEs = AppState.of(context).languageCode.value == 'es';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iconGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient.first.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? titleEs : titleEn,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEs ? subtitleEs : subtitleEn,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.2, end: 0, curve: Curves.easeOutCubic);
  }
}

class _OrderTypeDialog extends StatelessWidget {
  final bool isEs;

  const _OrderTypeDialog({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEs ? '¿Cómo prefieres ordenar?' : 'How would you like to order?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _OrderTypeButton(
              icon: Icons.delivery_dining_rounded,
              label: isEs ? 'Entrega a Domicilio' : 'Delivery',
              color: const Color(0xFF4ECDC4),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'delivery'});
              },
            ),
            const SizedBox(height: 12),
            _OrderTypeButton(
              icon: Icons.shopping_bag_rounded,
              label: isEs ? 'Recoger' : 'Pickup',
              color: const Color(0xFFFF6B6B),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'pickup'});
              },
            ),
            const SizedBox(height: 12),
            _OrderTypeButton(
              icon: Icons.restaurant_rounded,
              label: isEs ? 'Comer Aquí' : 'Dine In',
              color: const Color(0xFF667EEA),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'dine-in'});
              },
            ),
            const SizedBox(height: 12),
            _OrderTypeButton(
              icon: Icons.schedule_rounded,
              label: isEs ? 'Preordenar' : 'Preorder',
              color: const Color(0xFFF093FB),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/checkout', arguments: {'orderType': 'preorder'});
              },
            ),
          ],
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}

class _OrderTypeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEs = AppState.of(context).languageCode.value == 'es';

    return Dialog(
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
    );
  }
}

class _LocationDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEs = AppState.of(context).languageCode.value == 'es';

    return Dialog(
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
    );
  }
}

class _EliteMenuPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    // Top line (Longest)
    canvas.drawLine(
      Offset(0, size.height * 0.2),
      Offset(size.width, size.height * 0.2),
      paint
    );

    // Middle line (Medium)
    final midW = size.width * 0.7;
    canvas.drawLine(
      Offset(cx - midW/2, size.height * 0.5),
      Offset(cx + midW/2, size.height * 0.5),
      paint
    );

    // Bottom line (Shortest)
    final botW = size.width * 0.4;
    canvas.drawLine(
      Offset(cx - botW/2, size.height * 0.8),
      Offset(cx + botW/2, size.height * 0.8),
      paint
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
