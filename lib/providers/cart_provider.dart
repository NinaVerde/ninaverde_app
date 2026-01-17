import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/user_prefs_service.dart';
import '../services/firestore_service.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get subtotal => product.price * quantity;
}

class CartProvider with ChangeNotifier {
  final Map<String, CartItem> _items = {};

  CartProvider() {
    _loadCart();
  }

  Future<void> _loadCart() async {
    // We need products to reconstruct the cart objects
    // Quick load from Firestore to get product data.
    // In a larger app, we might cache product data locally too.
    try {
        final products = await FirestoreService().getProducts().first;
        final savedItems = UserPrefsService.loadCart(products);
        for (final item in savedItems) {
            _items[item.product.id] = item;
        }
        notifyListeners();
    } catch (e) {
        debugPrint('Error loading cart: $e');
    }
  }
  
  void _saveCart() {
    UserPrefsService.saveCart(_items);
  }

  Map<String, CartItem> get items => {..._items};

  int get itemCount => _items.length;

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.subtotal;
    });
    return total;
  }

  void addItem(Product product) {
    if (_items.containsKey(product.id)) {
      _items.update(
        product.id,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity + 1,
        ),
      );
    } else {
      _items.putIfAbsent(
        product.id,
        () => CartItem(product: product),
      );
    }
    notifyListeners();
    _saveCart();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
    _saveCart();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;

    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
        (existing) => CartItem(
          product: existing.product,
          quantity: existing.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
    _saveCart();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _saveCart();
  }
}
