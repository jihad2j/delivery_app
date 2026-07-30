import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};
  double _deliveryFee = 0;

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.length;

  double get deliveryFee => _deliveryFee;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.price * cartItem.quantity;
    });
    return total;
  }

  double get grandTotal => totalAmount + _deliveryFee;

  void setDeliveryFee(double fee) {
    _deliveryFee = fee;
    notifyListeners();
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> serialized = [];
      _items.forEach((key, cartItem) {
        serialized.add({
          'product': cartItem.product.toJson(),
          'quantity': cartItem.quantity,
        });
      });
      await prefs.setString('cart_items', jsonEncode({
        'deliveryFee': _deliveryFee,
        'items': serialized,
      }));
    } catch (e) {
      debugPrint('Failed to save cart: $e');
    }
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('cart_items');
      if (dataStr != null) {
        final Map<String, dynamic> data = jsonDecode(dataStr);
        _deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
        _items.clear();
        final List<dynamic> decoded = data['items'] ?? [];
        for (var item in decoded) {
          final product = Product.fromJson(item['product']);
          final quantity = item['quantity'] as int;
          _items[product.id] = CartItem(product: product, quantity: quantity);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load cart: $e');
    }
  }

  bool addItem(Product product, {double restaurantDeliveryFee = 0}) {
    if (_items.isNotEmpty) {
      final firstItem = _items.values.first;
      if (firstItem.product.restaurantId != product.restaurantId) {
        return false;
      }
    }
    if (_items.isEmpty) {
      _deliveryFee = restaurantDeliveryFee;
    }
    if (_items.containsKey(product.id)) {
      _items[product.id]!.quantity += 1;
    } else {
      _items[product.id] = CartItem(product: product);
    }
    _saveCart();
    notifyListeners();
    return true;
  }

  void removeItem(String productId) {
    if (!_items.containsKey(productId)) return;
    if (_items[productId]!.quantity > 1) {
      _items[productId]!.quantity -= 1;
    } else {
      _items.remove(productId);
    }
    if (_items.isEmpty) {
      _deliveryFee = 0;
    }
    _saveCart();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _deliveryFee = 0;
    _saveCart();
    notifyListeners();
  }
}
