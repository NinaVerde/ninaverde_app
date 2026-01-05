return Scaffold(
  appBar: AppBar(
    title: Text(widget.product.name),
  ),
  body: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Hero(
          tag: widget.product.id,
          child: CachedNetworkImage(
            imageUrl: widget.product.imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: 300,
              color: Colors.grey[300],
              child: const Center(
                child: CircularProgressIndicator(),
              ),
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
              Text(
                widget.product.description,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
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
  bottomNavigationBar: Padding(
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
            content: Text('Added ${widget.product.name} to cart'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      },
    ),
  ),
);