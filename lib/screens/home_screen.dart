// lib/screens/home_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/user_prefs_service.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail_screen.dart';
import '../screens/cart_screen.dart';
import '../services/event_promo_service.dart';
import '../models/event_promo_model.dart';
import '../services/comms_prefs_service.dart';
import '../services/push_token_service.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UserPrefsService _prefsService = UserPrefsService();
  final EventPromoService _promoService = EventPromoService();
  final CommsPrefsService _commsPrefs = CommsPrefsService();
  final PushTokenService _pushTokens = PushTokenService();
  String _searchQuery = '';
  String _selectedCategory = _allCategoryKey;

  late Future<List<String>> _categoriesFuture;
  final GlobalKey _cartKey = GlobalKey();
  final Map<String, GlobalKey> _productKeys = {};
  static const String _allCategoryKey = '__all__';
  late final PageController _categoryCarousel;
  double _carouselPage = 0;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _firestoreService.getCategories().first;
    _categoryCarousel = PageController(viewportFraction: 0.82);
    _categoryCarousel.addListener(() {
      setState(() => _carouselPage = _categoryCarousel.page ?? 0);
    });
    _commsPrefs.prefsStream().first.then((prefs) {
      _pushTokens.registerIfOptedIn(optInPush: prefs.optInPush);
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _categoriesFuture = _firestoreService.getCategories().first;
    });
  }

  void _runAddToCartAnimation(GlobalKey productKey) {
    if (productKey.currentContext == null) return;
    final RenderBox productBox =
        productKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox cartBox =
        _cartKey.currentContext!.findRenderObject() as RenderBox;

    final productPosition = productBox.localToGlobal(Offset.zero);
    final cartPosition = cartBox.localToGlobal(Offset.zero);

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return _buildAddToCartAnimation(
            productPosition, cartPosition, productBox.size);
      },
    );

    overlay.insert(entry);
    Timer(const Duration(milliseconds: 800), () => entry.remove());
  }

  Widget _buildAddToCartAnimation(
      Offset start, Offset end, Size productSize) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        final position = Offset.lerp(start, end, value)!;
        final size = Size.lerp(productSize, const Size(24, 24), value)!;

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Opacity(
            opacity: 1.0 - (value * 0.5),
            child: Container(
              width: size.width,
              height: size.height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(size.width / 2),
              ),
              child: const Icon(Icons.shopping_bag, color: Colors.white, size: 14),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _categoryCarousel.dispose();
    super.dispose();
  }

  List<String> _applyCategoryOrder(
    List<String> categories,
    List<String> preferredOrder,
  ) {
    final ordered = <String>[];
    for (final entry in preferredOrder) {
      if (categories.contains(entry) && !ordered.contains(entry)) {
        ordered.add(entry);
      }
    }
    for (final entry in categories) {
      if (!ordered.contains(entry)) ordered.add(entry);
    }
    return ordered;
  }

  Future<void> _prioritizeCategory({
    required String category,
    required List<String> categories,
  }) async {
    if (category == _allCategoryKey) {
      setState(() => _selectedCategory = _allCategoryKey);
      return;
    }

    final newOrder = [
      category,
      ...categories.where((c) => c != category),
    ];
    setState(() => _selectedCategory = category);
    await _prefsService.saveCategoryOrder(newOrder);
  }

  String? _categoryImage(List<Product> products, String category) {
    for (final product in products) {
      if (product.category == category && product.imageUrl.isNotEmpty) {
        return product.imageUrl;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = AppState.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge(
        [
          app.languageCode,
          app.currencyCode,
          app.currencyConfigs,
          app.isManager
        ],
      ),
      builder: (_, __) {
        final isEs = app.languageCode.value == 'es';
        final isDark = theme.brightness == Brightness.dark;
        final title = isEs ? 'Hola, Matthew' : 'Hello, Matthew';
        final searchHint =
            isEs ? 'Buscar productos...' : 'Search for products...';
        final kidsTitle = isEs ? 'Zona Kids' : 'Kids Zone';
        final kidsDesc = isEs
            ? 'Colorear, rompecabezas, laberintos y mas.'
            : 'Coloring, puzzles, mazes, and more.';
        final appSettingsLabel = isEs ? 'Configuracion' : 'App settings';
        final angelinaLabel =
            isEs ? 'Panel de Angelina' : 'Angelina control panel';
        final searchFill = isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface;
        return StreamBuilder<Map<String, dynamic>>(
          stream: _prefsService.prefsStream(),
          builder: (context, prefsSnap) {
            final prefs = prefsSnap.data ?? {};
            final savedOrder =
                (prefs['categoryOrder'] as List?)?.cast<String>() ?? [];
            final favoriteIds =
                (prefs['favorites'] as List?)?.cast<String>() ?? [];
            return PopScope(
              canPop: app.isManager.value,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                // If we're here, it means canPop was false (regular user).
                // They shouldn't return to login, so we exit the app.
                SystemNavigator.pop();
              },
              child: Scaffold(
                body: Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    child: CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          title: Text(title),
                          floating: true,
                          pinned: true,
                          snap: false,
                          actions: [
                            IconButton(
                              tooltip: appSettingsLabel,
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/app-settings'),
                              icon: const Icon(Icons.settings),
                            ),
                            const NvLanguageToggle(),
                            const NvCurrencyToggle(),
                            const NvThemeToggle(),
                        IconButton(
                          tooltip: angelinaLabel,
                          onPressed: () =>
                              Navigator.pushNamed(context, '/angelina-admin'),
                          icon: const Icon(Icons.tune),
                        ),
                        IconButton(
                          tooltip: tr(
                            context,
                            en: 'Messaging preferences',
                            es: 'Preferencias',
                          ),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/preferences/notifications',
                          ),
                          icon: const Icon(Icons.notifications_active),
                        ),
                            Consumer<CartProvider>(
                              builder: (_, cart, ch) => Badge(
                                key: _cartKey,
                                value: cart.itemCount.toString(),
                                child: ch!,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.shopping_cart),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const CartScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          bottom: PreferredSize(
                            preferredSize: const Size.fromHeight(kToolbarHeight),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                decoration: InputDecoration(
                                  hintText: searchHint,
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: searchFill,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.pushNamed(context, '/kids'),
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF4CAF50),
                                      Color(0xFFF3A70B)
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x22000000),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.icecream,
                                          color: Color(0xFF4CAF50),
                                          size: 30,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              kidsTitle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              kidsDesc,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buildPromoStrip(theme),
                        _buildHeroCategories(theme, savedOrder),
                        _buildCategories(theme, savedOrder),
                        _buildProductGrid(theme, favoriteIds.toSet()),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 16,
                    bottom: 24,
                    child: _HostessOverlay(),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildPromoStrip(ThemeData theme) {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<EventPromo>>(
        stream: _promoService.activePromos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final items = snapshot.data!;
          final label = tr(context, en: 'Events & Promos', es: 'Eventos y promos');
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _PromoCard(item: item);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCategories(ThemeData theme, List<String> savedOrder) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<String>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }
          final categories = _applyCategoryOrder(snapshot.data!, savedOrder);
          return StreamBuilder<List<Product>>(
            stream: _firestoreService.getProducts(),
            builder: (context, productsSnap) {
              final products = productsSnap.data ?? [];
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 190,
                child: PageView.builder(
                  controller: _categoryCarousel,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final imageUrl = _categoryImage(products, category);
                    final distance = (index - _carouselPage).abs();
                    final scale = (1 - (distance * 0.1)).clamp(0.86, 1.0);
                    final tilt = (index - _carouselPage) * 0.02;
                    return Transform.scale(
                      scale: scale,
                      child: Transform(
                        transform: Matrix4.identity()..rotateZ(tilt),
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () => _prioritizeCategory(
                            category: category,
                            categories: categories,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withValues(alpha: 0.9),
                                  theme.colorScheme.tertiary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow
                                      .withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (imageUrl != null)
                                    CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      color: Colors.black.withValues(alpha: 0.25),
                                      colorBlendMode: BlendMode.darken,
                                    )
                                  else
                                    Container(
                                      color: theme.colorScheme.primaryContainer,
                                    ),
                                  Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(18.0),
                                      child: Text(
                                        category,
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    top: 14,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16),
                                        border:
                                            Border.all(color: Colors.white24),
                                      ),
                                      child: Text(
                                        tr(
                                          context,
                                          en: 'Explore',
                                          es: 'Explorar',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategories(ThemeData theme, List<String> savedOrder) {
    return SliverToBoxAdapter(
      child: FutureBuilder<List<String>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCategoryShimmer(theme);
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                tr(
                  context,
                  en: 'Unable to load categories.',
                  es: 'No se pudieron cargar las categorias.',
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          final ordered = _applyCategoryOrder(snapshot.data!, savedOrder);
          final categories = [_allCategoryKey, ...ordered];
          final allLabel = tr(context, en: 'All', es: 'Todo');

          return SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final label =
                    category == _allCategoryKey ? allLabel : category;
                final scheme = Theme.of(context).colorScheme;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _selectedCategory == category,
                    selectedColor: scheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: _selectedCategory == category
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _prioritizeCategory(
                          category: category,
                          categories: ordered,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Chip(
                label: Container(
                  width: 80,
                  height: 20,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProductGrid(ThemeData theme, Set<String> favoriteIds) {
    return StreamBuilder<List<Product>>(
      stream: _firestoreService.getProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildProductGridShimmer(theme);
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                tr(
                  context,
                  en: 'Unable to load products.',
                  es: 'No se pudieron cargar los productos.',
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                tr(
                  context,
                  en: 'No products found.',
                  es: 'No se encontraron productos.',
                ),
              ),
            ),
          );
        }

        var allProducts = snapshot.data!;
        for (var p in allProducts) {
          _productKeys.putIfAbsent(p.id, () => GlobalKey());
        }

        final filteredProducts = allProducts.where((p) {
          final matchesCategory =
              _selectedCategory == _allCategoryKey ||
                  p.category == _selectedCategory;
          final matchesSearch = _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesCategory && matchesSearch;
        }).toList();

        if (filteredProducts.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Text(
                tr(
                  context,
                  en: 'No products match your search.',
                  es: 'No hay productos para tu busqueda.',
                ),
              ),
            ),
          );
        }

        return SliverAnimatedGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          initialItemCount: filteredProducts.length,
          itemBuilder: (context, index, animation) {
            final product = filteredProducts[index];
            final isFavorite = favoriteIds.contains(product.id);
            return _buildAnimatedProductCard(
              theme,
              product,
              isFavorite,
              animation,
            );
          },
        );
      },
    );
  }
  
  Widget _buildAnimatedProductCard(
    ThemeData theme,
    Product product,
    bool isFavorite,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: _buildProductCard(theme, product, isFavorite),
      ),
    );
  }

  Widget _buildProductGridShimmer(ThemeData theme) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Container(color: Colors.white),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: double.infinity,
                            height: 16,
                            color: Colors.white),
                        const SizedBox(height: 5),
                        Container(width: 100, height: 14, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: 6,
      ),
    );
  }

  Widget _buildProductCard(
    ThemeData theme,
    Product product,
    bool isFavorite,
  ) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final productKey = _productKeys[product.id]!;

    final scheme = Theme.of(context).colorScheme;
    final shareLabel = tr(context, en: 'Share', es: 'Compartir');
    return Card(
      key: productKey,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'product_${product.id}',
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: scheme.surface,
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(
                                    context,
                                    en: 'Sign in to save favorites.',
                                    es: 'Inicia sesion para guardar favoritos.',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          final prefs = await _prefsService.getPrefs();
                          final list =
                              (prefs['favorites'] as List?)?.cast<String>() ??
                                  [];
                          final updated = Set<String>.from(list);
                          final willFavorite = !isFavorite;
                          if (willFavorite) {
                            updated.add(product.id);
                          } else {
                            updated.remove(product.id);
                          }
                          await _prefsService.saveFavorites(updated);
                          await _prefsService.toggleFavorite(
                            productId: product.id,
                            isFavorite: willFavorite,
                          );
                        },
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color:
                              isFavorite ? Colors.redAccent : Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        tooltip: shareLabel,
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                                text: 'Check out ${product.name} at Niña Verde.',
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.ratingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            product.ratingAvg.toStringAsFixed(1),
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '(${product.ratingCount})',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    formatCurrency(context, product.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 36),
                ),
                onPressed: () {
                  cart.addItem(product);
                  _runAddToCartAnimation(productKey);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          context,
                          en: 'Added to cart',
                          es: 'Agregado al carrito',
                        ),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                child: Text(tr(context, en: 'Add', es: 'Agregar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final EventPromo item;
  const _PromoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = item.type == 'event'
        ? tr(context, en: 'Event', es: 'Evento')
        : tr(context, en: 'Promo', es: 'Promo');
    return Container(
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: item.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: theme.colorScheme.primaryContainer,
                      child: const Icon(Icons.event, size: 48),
                    ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () {
                  SharePlus.instance.share(ShareParams(text: 'Check out ${item.title} at Niña Verde.'));
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Badge extends StatelessWidget {
  final String value;
  final Widget child;
  final Color? color;

  const Badge({super.key, required this.value, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color ?? Theme.of(context).colorScheme.secondary,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
            ),
          ),
        )
      ],
    );
  }
}

class _HostessOverlay extends StatefulWidget {
  const _HostessOverlay();

  @override
  State<_HostessOverlay> createState() => _HostessOverlayState();
}

class _HostessOverlayState extends State<_HostessOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  final _docRef =
      FirebaseFirestore.instance.collection('ai_hostess').doc('angelina');
  Offset _dragOffset = Offset.zero;
  bool _minimized = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _restore() {
    setState(() {
      _hidden = false;
      _minimized = false;
      _dragOffset = Offset.zero;
    });
  }

  void _handleDragEnd() {
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;
    setState(() {
      if (dx < -80) {
        _hidden = true;
      } else if (dx > 80 || dy > 80) {
        _minimized = true;
      }
      _dragOffset = Offset.zero;
    });
  }

  String? _avatarUrl(Map<String, dynamic>? data) {
    if (data == null) return null;
    final media = data['media'];
    if (media is! List) return null;
    for (final item in media) {
      if (item is Map && item['type'] == 'image') {
        final url = item['url'];
        if (url is String && url.isNotEmpty) return url;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: _restore,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              'Angelina',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _docRef.snapshots(),
      builder: (context, snapshot) {
        final url = _avatarUrl(snapshot.data?.data());
        final avatar = url != null
            ? CachedNetworkImageProvider(url) as ImageProvider
            : const AssetImage('assets/images/avatar/nina_verde_512.png');

        return GestureDetector(
          onPanUpdate: (d) {
            setState(() => _dragOffset += d.delta);
          },
          onPanEnd: (_) => _handleDragEnd(),
          onTap: _minimized
              ? _restore
              : () => Navigator.pushNamed(context, '/contact'),
          onLongPress: () => Navigator.pushNamed(
            context,
            '/contact',
            arguments: {'autoListen': true},
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final glow = 0.5 + (_pulse.value * 0.5);
              final size = _minimized ? 40.0 : 64.0;
              return Transform.translate(
                offset: _dragOffset,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(
                            alpha: _minimized ? 0.2 : glow * 0.4),
                        blurRadius: _minimized ? 12 : 20,
                        spreadRadius: _minimized ? 2 : 4,
                      )
                    ],
                    image: DecorationImage(
                      image: avatar,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}



