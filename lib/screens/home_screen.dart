import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppState {
  static bool isSpanish = false;
  static String currencyCode = 'USD';
  static ValueNotifier<double> subtotal = ValueNotifier<double>(0);
}

class NvThemeTokens {
  static const double spacing = 16;
  static const double cornerRadius = 12;
}

class NvAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NvAppBar({super.key, required this.title});
  final String title;
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(title: Text(title));
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NvAppBar(title: 'Nicaragua Niña Verde'),
      body: Stack(
        children: const [
          _ScrollBody(),
          _MiniCart(),
        ],
      ),
    );
  }
}

class _ScrollBody extends StatelessWidget {
  const _ScrollBody();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _HeroPane(),
          _CategoriesGrid(),
          _PromotionsCarousel(),
          _QuickActionsRow(),
          SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _HeroPane extends StatelessWidget {
  const _HeroPane();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientStart =
        isDark ? Colors.green.shade900 : Colors.green.shade200;
    final gradientEnd = isDark ? Colors.teal.shade700 : Colors.teal.shade100;
    return TweenAnimationBuilder<double>(
      duration: 5.seconds,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        return Container(
          height: 240,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(value * 3.14),
            ),
          ),
          child: child,
        );
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Placeholder(fallbackHeight: 100, fallbackWidth: 100)
                .animate()
                .scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/menu'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NvThemeTokens.spacing * 2,
                  vertical: NvThemeTokens.spacing / 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    NvThemeTokens.cornerRadius * 3,
                  ),
                ),
                child: Text(
                  AppState.isSpanish ? 'Especiales de hoy' : "Today's Specials",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ).animate().scale(duration: 300.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class _Category {
  const _Category({
    required this.id,
    required this.titleEn,
    required this.titleEs,
    required this.image,
    this.count = 0,
  });
  final String id;
  final String titleEn;
  final String titleEs;
  final String image;
  final int count;
}

const _fallbackCategories = <_Category>[
  _Category(
      id: 'breakfast', titleEn: 'Breakfast', titleEs: 'Desayuno', image: ''),
  _Category(id: 'bowls', titleEn: 'Bowls', titleEs: 'Bowls', image: ''),
  _Category(id: 'tacos', titleEn: 'Tacos', titleEs: 'Tacos', image: ''),
  _Category(id: 'drinks', titleEn: 'Drinks', titleEs: 'Bebidas', image: ''),
];

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid();
  @override
  Widget build(BuildContext context) {
    final futureCategories = Future<List<_Category>>.delayed(
      800.ms,
      () => _fallbackCategories,
    );
    return FutureBuilder<List<_Category>>(
      future: futureCategories,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _fallbackCategories;
        if (!snapshot.hasData) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(NvThemeTokens.spacing),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: NvThemeTokens.spacing,
              mainAxisSpacing: NvThemeTokens.spacing,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(NvThemeTokens.cornerRadius),
              ),
            ).animate().shimmer(duration: 1.seconds),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(NvThemeTokens.spacing),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: NvThemeTokens.spacing,
            mainAxisSpacing: NvThemeTokens.spacing,
            childAspectRatio: 1,
          ),
          itemCount: data.length,
          itemBuilder: (context, index) {
            final cat = data[index];
            final title = AppState.isSpanish ? cat.titleEs : cat.titleEn;
            return GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/category/${cat.id}'),
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(NvThemeTokens.spacing),
                    child: Text('Admin actions for ${cat.titleEn}'),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius:
                          BorderRadius.circular(NvThemeTokens.cornerRadius),
                      image: cat.image.isEmpty
                          ? null
                          : DecorationImage(
                              image: NetworkImage(cat.image),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(NvThemeTokens.cornerRadius),
                      gradient: const LinearGradient(
                        colors: [Colors.black26, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(NvThemeTokens.spacing / 2),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        '$title (${cat.count})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().scale(duration: 300.ms, curve: Curves.easeOut),
            );
          },
        );
      },
    );
  }
}

class _PromotionsCarousel extends StatefulWidget {
  const _PromotionsCarousel();
  @override
  State<_PromotionsCarousel> createState() => _PromotionsCarouselState();
}

class _PromotionsCarouselState extends State<_PromotionsCarousel> {
  final _controller = PageController(viewportFraction: 0.85);
  double _page = 0;
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _page = _controller.page ?? 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final promos = List<int>.generate(3, (i) => i);
    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _controller,
        itemCount: promos.length,
        itemBuilder: (context, index) {
          final delta = index - _page;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(delta * 0.2),
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.symmetric(
                horizontal: NvThemeTokens.spacing / 2,
                vertical: NvThemeTokens.spacing / 2,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade200,
                borderRadius: BorderRadius.circular(NvThemeTokens.cornerRadius),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.labelEn,
    required this.labelEs,
    required this.route,
  });
  final IconData icon;
  final String labelEn;
  final String labelEs;
  final String route;
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();
  @override
  Widget build(BuildContext context) {
    final actions = [
      const _QuickAction(
        icon: Icons.shopping_bag_outlined,
        labelEn: 'Pickup',
        labelEs: 'Recoger',
        route: '/menu',
      ),
      const _QuickAction(
        icon: Icons.delivery_dining,
        labelEn: 'Delivery',
        labelEs: 'Entrega',
        route: '/menu',
      ),
      const _QuickAction(
        icon: Icons.event_seat,
        labelEn: 'Book Table',
        labelEs: 'Reservar',
        route: '/book',
      ),
      const _QuickAction(
        icon: Icons.card_giftcard,
        labelEn: 'Rewards',
        labelEs: 'Recompensas',
        route: '/rewards',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(NvThemeTokens.spacing),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: actions.map((action) {
          final label = AppState.isSpanish ? action.labelEs : action.labelEn;
          return Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, action.route),
              child: Column(
                children: [
                  Icon(action.icon).animate().scale(duration: 300.ms),
                  const SizedBox(height: 4),
                  Text(label, textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MiniCart extends StatelessWidget {
  const _MiniCart();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: AppState.subtotal,
      builder: (context, subtotal, _) {
        if (subtotal <= 0) return const SizedBox.shrink();
        return Positioned(
          left: NvThemeTokens.spacing,
          right: NvThemeTokens.spacing,
          bottom: NvThemeTokens.spacing,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/cart'),
            child: Container(
              padding: const EdgeInsets.all(NvThemeTokens.spacing),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(NvThemeTokens.cornerRadius),
              ),
              child: Text(
                '${AppState.currencyCode} ${subtotal.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
