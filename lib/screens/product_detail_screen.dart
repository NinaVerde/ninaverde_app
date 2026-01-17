// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../main.dart';
import '../state/app_state.dart';
import '../services/user_prefs_service.dart';
import '../services/review_service.dart';
import '../models/review_model.dart';
import '../widgets/nv_widgets.dart';
import '../services/analytics_service.dart';
import '../widgets/angelina_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  final UserPrefsService _prefsService = UserPrefsService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _reviewCtl = TextEditingController();
  int _reviewRating = 5;
  bool _submittingReview = false;
  VideoPlayerController? _videoController;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.product.videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.product.videoUrl),
      )..initialize().then((_) {
          if (mounted) {
            setState(() => _videoReady = true);
          }
        });
    }
    
    // Log View
    AnalyticsService.logProductView(widget.product.id, widget.product.name);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _reviewCtl.dispose();
    super.dispose();
  }

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);
    final app = AppState.of(context);

    final heroTag = 'product_${widget.product.id}';
    // Localization logic
    final isEs = app.languageCode.value == 'es';
    final localizedName = isEs && widget.product.nameEs.isNotEmpty 
        ? widget.product.nameEs 
        : widget.product.nameEn.isNotEmpty ? widget.product.nameEn : widget.product.name;
    
    final rawDesc = isEs && widget.product.descriptionEs.isNotEmpty
        ? widget.product.descriptionEs
        : widget.product.descriptionEn.isNotEmpty ? widget.product.descriptionEn : widget.product.description;
    
    final description = rawDesc.trim();

    final nameStyle = (theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        )) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

    final priceStyle = (theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        )) ??
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        );

    final qtyStyle =
        theme.textTheme.headlineMedium ?? const TextStyle(fontSize: 24);

    return AnimatedBuilder(
      animation:
          Listenable.merge([app.languageCode, app.currencyCode, app.currencyConfigs]),
      builder: (_, __) {
        final addLabel = tr(context, en: 'Add to Cart', es: 'Agregar');
        
        // Re-evaluate localization if language changed inside builder
        final currentIsEs = app.languageCode.value == 'es';
        final currentName = currentIsEs && widget.product.nameEs.isNotEmpty 
            ? widget.product.nameEs 
            : widget.product.nameEn.isNotEmpty ? widget.product.nameEn : widget.product.name;
            
        final currentRawDesc = currentIsEs && widget.product.descriptionEs.isNotEmpty
            ? widget.product.descriptionEs
            : widget.product.descriptionEn.isNotEmpty ? widget.product.descriptionEn : widget.product.description;
        final currentDesc = currentRawDesc.trim();

        return StreamBuilder<Map<String, dynamic>>(
          stream: _prefsService.prefsStream(),
          builder: (context, prefsSnap) {
            final favorites =
                (prefsSnap.data?['favorites'] as List?)?.cast<String>() ?? [];
            final isFavorite = favorites.contains(widget.product.id);
            return Scaffold(
              appBar: NvAppBar(
                title: currentName, 
                showBack: true,
                extraActions: [
                  IconButton(
                    onPressed: () {
                      final text = currentIsEs
                         ? '¡Tenés que probar *$currentName* en Niña Verde! 🌮🔥'
                         : 'You have to try *$currentName* at Niña Verde! 🌮🔥';
                      SharePlus.instance.share(
                        ShareParams(text: text),
                      );
                      AnalyticsService.logShare('product', widget.product.id);
                    },
                    icon: const Icon(Icons.share),
                  ),
                  IconButton(
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
                        productId: widget.product.id,
                        isFavorite: willFavorite,
                      );
                    },
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.redAccent : null,
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: CachedNetworkImage(
                        imageUrl: widget.product.imageUrl,
                        fit: BoxFit.cover,
                        height: 300,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300,
                          color: Colors.grey[300],
                          child:
                              const Icon(Icons.error, color: Colors.red, size: 48),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            currentName,
                            style: nameStyle,
                          ),
                          if (widget.product.ratingCount > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.star,
                                      size: 18, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.product.ratingAvg
                                        .toStringAsFixed(1),
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${widget.product.ratingCount})',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (currentDesc.isNotEmpty) ...[
                            TranslatedText(
                              currentDesc,
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            const SizedBox(height: 16),
                          ],
                          Text(
                            formatCurrency(context, widget.product.price),
                            style: priceStyle,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed:
                                    _quantity > 1 ? _decrementQuantity : null,
                                iconSize: 32,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '$_quantity',
                                style: qtyStyle,
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _incrementQuantity,
                                iconSize: 32,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildHostessTip(context),
                          const SizedBox(height: 24),
                          if (widget.product.videoUrl.isNotEmpty)
                            _buildVideoSection(context),
                          if (widget.product.videoUrl.isNotEmpty)
                            const SizedBox(height: 24),
                          _buildReviewComposer(context),
                          const SizedBox(height: 16),
                          _buildApprovedReviews(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: Text(addLabel),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: theme.textTheme.titleLarge,
                    ),
                    onPressed: () {
                      for (int i = 0; i < _quantity; i++) {
                        cart.addItem(widget.product);
                      }
                      
                      AnalyticsService.logAddToCart(
                        widget.product.id, 
                        widget.product.name, 
                        widget.product.price
                      );

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            tr(
                              context,
                              en:
                                  'Added ${widget.product.name} x$_quantity to cart',
                              es:
                                  'Agregado ${widget.product.name} x$_quantity al carrito',
                            ),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewComposer(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final label =
        tr(context, en: 'Write a review', es: 'Escribe una resena');
    final hint = tr(
      context,
      en: 'Share your experience...',
      es: 'Comparte tu experiencia...',
    );
    final submit = tr(context, en: 'Submit review', es: 'Enviar resena');
    final signIn = tr(context, en: 'Sign in to review', es: 'Inicia sesion');
    final ratingLabel = tr(context, en: 'Rating', es: 'Calificacion');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (user == null)
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            icon: const Icon(Icons.lock_outline),
            label: Text(signIn),
          )
        else ...[
          Text(ratingLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                onPressed: () => setState(() => _reviewRating = star),
                icon: Icon(
                  star <= _reviewRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reviewCtl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submittingReview
                  ? null
                  : () async {
                      final text = _reviewCtl.text.trim();
                      if (text.isEmpty) return;
                      setState(() => _submittingReview = true);
                      
                      try {
                        await _reviewService.submitReview(
                          productId: widget.product.id,
                          rating: _reviewRating,
                          comment: text,
                        );
                        
                        if (!context.mounted) return;
                        
                        final snackText = tr(
                          context,
                          en: 'Review submitted for approval.',
                          es: 'Resena enviada para aprobacion.',
                        );
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(snackText)),
                        );

                        final canShare = _reviewRating >= 3;
                        if (canShare) {
                          _showSharePrompt(context, text);
                        }

                        // Clear form on success
                        setState(() {
                          _reviewCtl.clear();
                          _reviewRating = 5;
                        });

                      } catch (e) {
                         if (!context.mounted) return;
                         ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr(context, en: 'Error saving review.', es: 'Error al guardar.')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _submittingReview = false);
                        }
                      }
                    },
              child: _submittingReview
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(submit),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildApprovedReviews(BuildContext context) {
    final theme = Theme.of(context);
    final title = tr(context, en: 'Reviews', es: 'Resenas');
    return StreamBuilder<List<Review>>(
      stream: _reviewService.approvedReviews(widget.product.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Text(
            tr(
              context,
              en: 'No reviews yet.',
              es: 'Aun no hay resenas.',
            ),
            style: theme.textTheme.bodyMedium,
          );
        }
        final reviews = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...reviews.map((review) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return Icon(
                            star <= review.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      TranslatedText(review.comment),
                      const SizedBox(height: 6),
                      Text(
                        review.userName.isEmpty ? 'Guest' : review.userName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  void _showSharePrompt(BuildContext context, String comment) {
    final shareTitle = tr(
      context,
      en: 'Share your review?',
      es: 'Compartir tu resena?',
    );
    final shareHint = tr(
      context,
      en: 'Let others know what you loved about ${widget.product.name}.',
      es: 'Cuenta lo que te gusto de ${widget.product.name}.',
    );
    final shareNow = tr(context, en: 'Share', es: 'Compartir');
    final later = tr(context, en: 'Later', es: 'Luego');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shareTitle),
        content: Text(shareHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(later),
          ),
          FilledButton(
            onPressed: () {
              final message =
                  '"$comment"\n- ${widget.product.name} at Niña Verde';
              SharePlus.instance.share(ShareParams(text: message));
              Navigator.pop(ctx);
            },
            child: Text(shareNow),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSection(BuildContext context) {
    final theme = Theme.of(context);
    final label = tr(context, en: 'Product video', es: 'Video del producto');
    if (!_videoReady || _videoController == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_videoController!),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.9),
                    onPressed: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                    child: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

  }

  Widget _buildHostessTip(BuildContext context) {
    // Random tip logic - simple implementation
    final tipsEn = [
      "This is one of my favorites!",
      "Perfect choice, darling.",
      "You're going to love this.",
      "Great for sharing!"
    ];
    final tipsEs = [
      "¡Este está tuani!",
      "¡Perfecto para compartir, amor!",
      "¡Deacachimba elección!",
      "¡Te va a encantar, corazón!"
    ];
    
    // Use product ID hash to keep tip consistent per product, but different across products
    final index = widget.product.id.hashCode.abs() % 4;
    final tip = tr(context, en: tipsEn[index], es: tipsEs[index]);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Dynamic "Sunset" Gradient
        gradient: LinearGradient(
          colors: [
            Colors.orange.withValues(alpha: 0.15),
            Colors.pink.withValues(alpha: 0.08),
            Colors.purple.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Angelina Enters First
          SizedBox(
            height: 110,
            child: AngelinaWidget(
              pose: AngelinaPose.waitressMenu, 
              compact: false, 
              height: 110,
            ),
          ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.2, end: 0, curve: Curves.easeOutBack),
          
          const SizedBox(width: 16),
          
          // Tip Card Slides in Second (Staggered)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr(context, en: "Angelina's Tip", es: "Consejo de Angelina"),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"$tip"',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ).animate(delay: 300.ms).fadeIn().slideX(begin: 0.2, end: 0, curve: Curves.easeOut),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms); // Whole container fades in
  }
}
