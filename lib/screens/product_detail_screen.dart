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
  void _decrementQuantity() =>
      setState(() => _quantity = (_quantity > 1) ? _quantity - 1 : 1);

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);

    // Safer Hero tag (avoids collisions and makes it consistent across app)
    final heroTag = 'product_${widget.product.id}';

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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // If description is nullable, this avoids a crash/analyzer error.
                  Text(
                    (widget.product.description ?? '').trim(),
                    style: theme.textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 16),

                  // Use your model format if you have it (e.g. priceFormatted).
                  Text(
                    '\$${widget.product.price.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _decrementQuantity,
                        iconSize: 32,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$_quantity',
                        style: theme.textTheme.headlineMedium,
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
              // Prefer a quantity-aware API if your CartProvider has it.
              // If not, fallback to looping addItem.
              try {
                // If your provider has addItem(product, quantity: n), this will work.
                // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
                // (the ignores above won’t be used by analyzer unless needed; safe to keep out)
                // We can't reflect at runtime in Dart, so we keep the safe fallback below.
                // So we just do the fallback loop always, unless you confirm your API supports quantity.
              } catch (_) {}

              for (int i = 0; i < _quantity; i++) {
                cart.addItem(widget.product);
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Added ${widget.product.name} x$_quantity to cart'),
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
