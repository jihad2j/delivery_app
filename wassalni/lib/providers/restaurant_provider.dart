import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/services.dart';

class RestaurantProvider extends ChangeNotifier {
  List<User> _restaurants = [];
  List<Product> _currentMenu = [];
  bool _isLoading = false;

  List<User> get restaurants => _restaurants;
  List<Product> get currentMenu => _currentMenu;
  bool get isLoading => _isLoading;

  Future<void> loadRestaurants({String? governorate, String? region}) async {
    _isLoading = true;
    notifyListeners();
    try {
      String path = '/api/restaurants';
      final queryParams = <String>[];
      if (governorate != null && governorate.isNotEmpty) {
        queryParams.add('governorate=${Uri.encodeComponent(governorate)}');
      }
      if (region != null && region.isNotEmpty) {
        queryParams.add('region=${Uri.encodeComponent(region)}');
      }
      if (queryParams.isNotEmpty) {
        path += '?${queryParams.join('&')}';
      }

      final res = await ApiService.get(path);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _restaurants = data.map((x) => User.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('Load restaurants error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMenu(String restaurantId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.get(
        '/api/products?restaurantId=$restaurantId',
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _currentMenu = data.map((x) => Product.fromJson(x)).toList();
      }
    } catch (e) {
      debugPrint('Load menu error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<String?> addProduct({
    required String name,
    required String image,
    required double price,
    required String category,
    String? description,
    bool isAvailable = true,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/api/products', {
        'name': name,
        'image': image,
        'price': price,
        'category': category,
        'description': description,
        'isAvailable': isAvailable,
      });
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 201) {
        final newProduct = Product.fromJson(jsonDecode(res.body));
        _currentMenu.add(newProduct);
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to add product';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> updateProductAvailability(
    String productId,
    bool isAvailable,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.put('/api/products/$productId', {
        'isAvailable': isAvailable,
      });
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final updatedProduct = Product.fromJson(jsonDecode(res.body));
        final idx = _currentMenu.indexWhere((p) => p.id == productId);
        if (idx != -1) {
          _currentMenu[idx] = updatedProduct;
        }
        return null;
      } else {
        return jsonDecode(res.body)['message'] ??
            'Failed to update product availability';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> deleteProduct(String productId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.delete('/api/products/$productId');
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        _currentMenu.removeWhere((p) => p.id == productId);
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to delete product';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }
}
