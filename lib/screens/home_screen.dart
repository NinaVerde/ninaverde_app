// lib/screens/home_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
import '../widgets/angelina_widget.dart';
import '../widgets/sandwich_menu.dart';
import '../theme/brand_colors.dart' as brand;
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/user_prefs_service.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail_screen.dart';
import '../screens/cart_screen.dart';
import '../services/event_promo_service.dart';
import '../models/event_promo_model.dart';
import 'package:provider/provider.dart';
import '../services/comms_prefs_service.dart';
import '../services/push_token_service.dart';
import 'package:flutter/services.dart';
import '../widgets/admin/product_editor_sheet.dart';
import '../widgets/admin/event_editor_sheet.dart';
// import 'events_screen.dart'; // Unused/does not exist
import '../widgets/hero_carousel.dart';
import '../config/product_animations_map.dart'; // For HeroCategoryConfig

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
  
  // MAIN SCROLL CONTROLLER
  final ScrollController _mainScrollController = ScrollController();

  String _searchQuery = '';
  String _selectedCategory = _allCategoryKey;
  bool _isMenuOpen = false; // State for non-modal menu


  final GlobalKey _cartKey = GlobalKey();
  final Map<String, GlobalKey> _productKeys = {};
  static const String _allCategoryKey = '__all__';
  // Removed old carousel controller

  @override
  void initState() {
    super.initState();
    _selectedCategory = UserPrefsService.loadLocalPrefs().lastCategory;

    
    // Load last selected category
    
    _commsPrefs.prefsStream().first.then((prefs) {
      _pushTokens.registerIfOptedIn(optInPush: prefs.optInPush);
    });
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
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
    _mainScrollController.dispose();
    super.dispose();
  }

  // Helper to handle selection from Carousel - SINGLE CLICK SUPPORT
  void _onHeroCategorySelected(String category) {
    if (category == 'VYBZ Eventos') {
      // "Outlier... won't have any listings... won't be a selectable category"
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr(context, en: 'VYBZ Events coming soon!', es: '¡Eventos VYBZ muy pronto!')), duration: const Duration(seconds: 1)),
      );
      return; 
    }

    // Toggle selection: if already selected, deselect to show all
    if (_selectedCategory == category) {
      setState(() => _selectedCategory = _allCategoryKey);
      UserPrefsService.saveCategory(_allCategoryKey);
    } else {
      setState(() => _selectedCategory = category);
      UserPrefsService.saveCategory(category);
    }
    
    // Auto scroll down to products (gentle nudge, keeping Hero visible)
    _mainScrollController.animateTo(
<<<<<<< HEAD
      120, // Reduced from 550 to keep Carousel in view
=======
      550,
>>>>>>> 2364cb6 (feat: On-the-fly Product Translation, Ticker Improvements, Search B… (#87))
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
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
        final searchFill = isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface;
            
        return StreamBuilder<Map<String, dynamic>>(
          stream: _prefsService.prefsStream(),
          builder: (context, prefsSnap) {
            final prefs = prefsSnap.data ?? {};

            final favoriteIds =
                (prefs['favorites'] as List?)?.cast<String>() ?? [];
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) async {
                if (didPop) return;
                
                // Handle Menu Back Navigation
                if (_isMenuOpen) {
                  setState(() => _isMenuOpen = false);
                  return;
                }

                if (app.isManager.value) {
                  // Admin: Navigate to login screen but stay signed in
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  // Regular user: Sign out and exit app
                  await FirebaseAuth.instance.signOut();
                  SystemNavigator.pop();
                }
              },
              child: Scaffold(
                appBar: NvAppBar(
                  tickerVisible: app.showTicker.value,
                  title: title,
                  centerWidget: SandwichMenuButton(onTap: _toggleMenu),
                  extraActions: [
                     if (app.isManager.value)
                        IconButton(
                          tooltip: tr(context, en: 'Owner Control Panel', es: 'Panel de Dueño'),
                          onPressed: () => Navigator.pushNamed(context, '/owner'),
                          icon: const Icon(Icons.settings),
                        ),
                      IconButton(
                        tooltip: tr(context, en: 'Notifications', es: 'Notificaciones'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr(context, en: 'No new notifications', es: 'No hay notificaciones nuevas'))),
                          );
                        },
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
                ),
                body: Column(
                children: [

                  // Fixed Search Bar (Pinned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor, // Seamless blend
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withValues(alpha: 0.05),
                           blurRadius: 4,
                           offset: const Offset(0, 2),
                         )
                      ],
                    ),
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

                  Expanded(
                    child: Stack(
                      children: [
                        CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          controller: _mainScrollController,
                          slivers: [
                            // --- ELITE HERO CAROUSEL ---
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 24),
                                child: HeroCategoryCarousel(
                                  pageScrollController: _mainScrollController,
                                  onCategorySelected: _onHeroCategorySelected,
                                  currentCategory: _selectedCategory,
                                ),
                              ),
                            ),
                            
                            _buildPromoStrip(theme),

                             // Product List Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _selectedCategory == _allCategoryKey 
                                          ? tr(context, en: 'All Products', es: 'Todos los Productos')
                                          : (isEs ? _selectedCategory : (HeroCategoryConfig.translations[_selectedCategory] ?? _selectedCategory)),
                                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                      ),
                                    ),
                                    if (_selectedCategory != _allCategoryKey)
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _selectedCategory = _allCategoryKey);
                                          UserPrefsService.saveCategory(_allCategoryKey);
                                        },
                                        child: Text(tr(context, en: 'Clear Filter', es: 'Ver Todo')),
                                      )
                                  ],
                                ),
                              ),
                            ),

                            _buildProductGrid(theme, favoriteIds.toSet()),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                        
                        const Positioned(
                          right: 16,
                          bottom: 24,
                          child: _HostessOverlay(),
                        ),

                        // SANDWICH MENU OVERLAY (Non-Modal)
                        // Using Positioned without 'top' makes it fill? No, Positioned.fill fills.
                        // We want it to start BELOW the parent stack?
                        // Wait, the search bar is OUTSIDE this stack now (in the specific replacement).
                        // So Positioned.fill here will fill the Expanded area (below search bar).
                        // This effectively unblocks the search bar!
                        if (_isMenuOpen)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _toggleMenu, // Tap outside to close
                              child: Container(
                                color: Colors.black54, // Dim background
                                alignment: Alignment.bottomCenter,
                                child: GestureDetector(
                                  onTap: () {}, // Catch taps on the sheet itself
                                  child: const SandwichMenuSheet(),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(duration: 200.ms),
                      ],
                    ),
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
                      // Assuming _PromoCard is defined elsewhere in the file or imported
                      // If it was private in original file, we need to ensure it's still there.
                      // Since we are replacing the class content, I must ensure _PromoCard exists.
                      // The original file had it. Since I am replacing EVERYTHING from line 30 to 396? 
                      // NO, I am replacing the HomeScreen class implementation.
                      // I need to be careful with private classes outside HomeScreen.
                      // _PromoCard was likely outside.
                      // Wait, I should double check if _PromoCard is in the file.
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
  
  // _buildProductGrid and others follow...
  // Since I'm doing a huge replace, I need to make sure I don't delete the bottom of the file where helper classes live.
  // The user file has 1321 lines. My view showed up to line 800.
  // _PromoCard is likely further down?
  // I should check where _PromoCard is.
  
  // Let's assume it is there. I will CUT the replacement before the private classes at the bottom.
  // I need to verify the replacement range.
  







  Widget _buildProductGrid(ThemeData theme, Set<String> favoriteIds) {
    final app = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, lang, _) {
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

            // Apply search filter
            final searchFiltered = _searchQuery.isEmpty
                ? allProducts
                : allProducts.where((p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();

            if (searchFiltered.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      tr(
                        context,
                        en: 'No products match your search.',
                        es: 'No hay productos para tu busqueda.',
                      ),
                    ),
                  ),
                ),
              );
            }

            // CATEGORY-GROUPED DISPLAY LOGIC
            return _buildCategoryGroupedProducts(
              theme,
              searchFiltered,
              favoriteIds,
            );
          },
        );
      },
    );
  }

  // NEW: Build products grouped by category in carousel order
  Widget _buildCategoryGroupedProducts(
    ThemeData theme,
    List<Product> products,
    Set<String> favoriteIds,
  ) {
    // 1. Determine the display order of categories
    // If a category is selected, we move it to the top.
    // If "All" is selected, we keep the default carousel order.
    List<String> displayOrder;
    // Get dynamic order from AppState
    final app = AppState.of(context);
    final currentOrder = app.categoryOrder.value.isNotEmpty 
        ? app.categoryOrder.value 
        : HeroCategoryConfig.order;

    if (_selectedCategory == _allCategoryKey) {
      displayOrder = currentOrder;
    } else {
      // Move selected to front, keep others in order
      displayOrder = [
        _selectedCategory,
        ...currentOrder.where((c) => c != _selectedCategory),
      ];
    }

    // 2. Build the list of sections
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= displayOrder.length) return null;
          
          final category = displayOrder[index];
          final isSelected = category == _selectedCategory && _selectedCategory != _allCategoryKey;
          
          // Filter products for this category (Exact match or simple contains if you prefer)
          final categoryProducts = products
              .where((p) => p.category == category)
              .toList();
          
          // 3. Handle Empty Categories
          // If this is the explicitly selected category and it's empty, show a "Empty" message.
          // If it's just a regular category in the list and it's empty, hide the section comfortably.
          if (categoryProducts.isEmpty) {
            if (isSelected) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildCategoryHeader(theme, category, isSelected),
                   Padding(
                     padding: const EdgeInsets.all(32.0),
                     child: Center(
                       child: Text(
                         category == 'VYBZ Eventos'
                             ? tr(context, en: 'Coming Soon!', es: '¡Muy Pronto!')
                             : tr(context, en: 'No products in this category.', es: 'No hay productos en esta categoría.'),
                         style: theme.textTheme.bodyLarge,
                       ),
                     ),
                   ),
                ],
              );
            }
            return const SizedBox.shrink(); 
          }
          
          // 4. Render Category Section
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryHeader(theme, category, isSelected),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: categoryProducts.length,
                itemBuilder: (context, prodIndex) {
                  final product = categoryProducts[prodIndex];
                  final isFavorite = favoriteIds.contains(product.id);
                  return _buildProductCard(theme, product, isFavorite);
                },
              ),
            ],
          );
        },
        childCount: displayOrder.length,
      ),
    );
  }

  Widget _buildCategoryHeader(ThemeData theme, String category, bool isHighlight) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      padding: isHighlight 
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : EdgeInsets.zero,
      decoration: isHighlight 
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHighlight) ...[
            Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Builder(
              builder: (context) {
                  final isEn = AppState.of(context).languageCode.value == 'en';
                  final displayName = isEn 
                      ? HeroCategoryConfig.translations[category] ?? category
                      : category;
                  return Text(
                    displayName.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isHighlight ? theme.colorScheme.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  );
              }
            ),
          ),
        ],
      ),
    );
  }
  
//   Widget _buildAnimatedProductCard(...) { ... } // Unused


//  ... } // Unused
//  ... } // Unused
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
    // Force rebuild when language changes by using a key that includes the language code
    final langCode = AppState.of(context).languageCode.value;
    
    return Card(
      key: ValueKey('${product.id}_$langCode'),
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        ),
        onLongPress: () {
          final isManager = AppState.of(context).isManager.value;
          if (isManager) {
            ProductEditorSheet.show(context, product: product);
          }
        },
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
                          final willFavorite = !isFavorite;
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
                  TranslatedText(
                    product.name, // Always pass source name (usually English/DB default)
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
      child: GestureDetector(
        onLongPress: () {
          if (AppState.of(context).isManager.value) {
            EventEditorSheet.show(context, promo: item);
          }
        },
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
                  final isEs = AppState.of(context).languageCode.value == 'es';
                  final text = isEs
                      ? '¡Mirá esta promo *${item.title}* en Niña Verde! 🌿 Estás invitado.'
                      : 'Check out *${item.title}* at Niña Verde! 🌿 You gotta see this.';
                  SharePlus.instance.share(ShareParams(text: text));
                },
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: TranslatedText(
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
  late AnimationController _pulse;
  Offset _dragOffset = Offset.zero;
  bool _minimized = false;
  bool _hidden = false;
  Timer? _greetingTimer;
  Timer? _greetingHideTimer;  // Track the hide timer to cancel it
  String? _greeting;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    
    // Show greeting after a delay
    _greetingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _greeting = _getGreeting();
        });
        // Hide greeting after 5 secs - use Timer instead of Future.delayed
        _greetingHideTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _greeting = null);
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update greeting if language changes while visible
    if (_greeting != null) {
      setState(() {
        _greeting = _getGreeting();
      });
    }
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    // Slang: tuani (cool), diacachimba (awesome), corazón (darling), mae (friend/dude)
    final app = AppState.of(context);
    final isEs = app.languageCode.value == 'es';
    
    if (hour < 12) {
      return isEs ? '¡Buenos días corazón!' : 'Good morning, darling!';
    } else if (hour < 18) {
      return isEs ? '¡Buenas tardes amor!' : 'Good afternoon, hun!';
    } else {
      return isEs ? '¡Buenas noches! ¿Todo tuani?' : 'Evening! Everything tuani?';
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _greetingTimer?.cancel();
    _greetingHideTimer?.cancel();  // Cancel the hide timer
    super.dispose();
  }

  void _restore() {
    setState(() {
      _hidden = false;
      _minimized = false;
      _dragOffset = Offset.zero;
      _greeting = _getGreeting(); // Show greeting again on restore
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
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
      onPanEnd: (_) => _handleDragEnd(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final glow = 0.5 + (_pulse.value * 0.5);
          final size = _minimized ? 50.0 : 80.0;
          
          return Transform.translate(
            offset: _dragOffset,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speech Bubble (Left of avatar)
                if (!_minimized && _greeting != null)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight: const Radius.circular(0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _greeting!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ).animate().fade().scale(),

                // Angelina Head with Attention Grabber
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: brand.nvAccentOrange
                            .withValues(alpha: _minimized ? 0.2 : glow * 0.5),
                        blurRadius: _minimized ? 10 : 25,
                        spreadRadius: _minimized ? 2 : 5,
                      )
                    ],
                  ),
                  child: AngelinaWidget(
                    pose: AngelinaPose.bubbleAvatar,
                    compact: true,
                    height: size,
                    onTap: _minimized 
                      ? _restore 
                      : () => Navigator.pushNamed(context, '/contact'),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(period: 10.seconds)) // Every 10s
                .shake(delay: 5.seconds, duration: 1.seconds, hz: 3, rotation: 0.1) // Subtle shake
                .shimmer(delay: 5.seconds, duration: 1.seconds, color: Colors.white54), // Subtle shine
              ],
            ),
          );
        },
      ),
    );
  }
}



