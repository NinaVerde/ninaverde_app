// lib/screens/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/product_model.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  void _incrementQuantity() => setState(() => _quantity++);

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);

    // Keep this consistent with HomeScreen Hero tag if you changed it there too.
    final heroTag = 'product_${widget.product.id}';

    // ✅ Fix analyzer warning:
    // If Product.description is NON-nullable, don't use ?? '' (causes dead_null_aware_expression).
    // If your Product.description IS nullable, change your model or adjust this line to:
    // final description = (widget.product.description ?? '').trim();
    final description = widget.product.description.trim();

    // ✅ Fix analyzer errors: textTheme fields can be nullable, so safely copyWith + fallback.
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
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
                  child: const Icon(Icons.error, color: Colors.red, size: 48),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: nameStyle,
                  ),
                  const SizedBox(height: 8),

                  // Only show description block if it has content
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

                  Text(
                    '\$${widget.product.price.toStringAsFixed(2)}',
                    style: priceStyle,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _quantity > 1 ? _decrementQuantity : null,
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
            label: const Text('Add to Cart'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: theme.textTheme.titleLarge,
            ),
            onPressed: () {
              for (int i = 0; i < _quantity; i++) {
                cart.addItem(widget.product);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Added ${widget.product.name} x$_quantity to cart',
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
  }
}
