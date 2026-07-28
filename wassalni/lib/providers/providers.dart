import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../core/services.dart';

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

  Future<void> tryAutoLogin() async {
    await Future.delayed(Duration.zero);
    _isLoading = true;
    notifyListeners();
    await ApiService.init();

    // 1. استعادة بيانات الجلسة المحفوظة فوراً لسرعة فتح التطبيق
    final cachedUserData = await ApiService.getCachedUserData();
    if (cachedUserData != null) {
      try {
        _currentUser = User.fromJson(cachedUserData);
        _connectSocket();
      } catch (e) {
        debugPrint('Error restoring cached user: $e');
      }
    }

    // 2. تحديث البيانات من السيرفر إذا كان الرمز موجوداً
    if (ApiService.token != null) {
      try {
        final res = await ApiService.get('/api/auth/profile');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _currentUser = User.fromJson(data);
          await ApiService.saveCachedUserData(data);
          _connectSocket();
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          // الرمز منتهي أو غير صالح
          await logout();
        }
      } catch (e) {
        debugPrint('Auto-login background refresh failed: $e');
        // في حال انقطاع الشبكة، نبقي على المستخدم مسجلاً بالبيانات المحفوظة
        if (_currentUser != null) {
          _connectSocket();
        }
      }
    } else {
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/api/auth/login', {
        'email': email,
        'password': password,
      });
      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await ApiService.setToken(data['token']);
        _currentUser = User.fromJson(data['user']);
        await ApiService.saveCachedUserData(data['user']);
        _connectSocket();
        return null;
      } else {
        final err = jsonDecode(res.body);
        return err['message'] ?? 'Login failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role,
    String? cuisineType, // For restaurant registration
    Address? address,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'role': role,
      };

      if (role == 'restaurant' && cuisineType != null) {
        body['cuisineType'] = cuisineType;
      }
      if (address != null) {
        body['address'] = address.toJson();
      }

      final res = await ApiService.post('/api/auth/register', body);
      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await ApiService.setToken(data['token']);
        _currentUser = User.fromJson(data['user']);
        await ApiService.saveCachedUserData(data['user']);
        _connectSocket();
        return null;
      } else {
        final err = jsonDecode(res.body);
        return err['message'] ?? 'Registration failed';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    Address? address,
    RestaurantInfo? restaurantInfo,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address.toJson();
      if (restaurantInfo != null) {
        updates['description'] = restaurantInfo.description;
        updates['logo'] = restaurantInfo.logo;
        updates['status'] = restaurantInfo.status;
        updates['minOrderAmount'] = restaurantInfo.minOrderAmount;
        updates['deliveryFee'] = restaurantInfo.deliveryFee;
        updates['cuisineType'] = restaurantInfo.cuisineType;
        updates['firebaseNotifications'] = restaurantInfo.firebaseNotifications;
      }

      final res = await ApiService.put('/api/auth/profile', updates);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentUser = User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Update profile error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  // Enforce GPS for driver status change
  Future<String?> toggleDriverAvailability(bool active) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (active) {
        final err = await LocationHelper.checkAndRequestPermissions();
        if (err != null) {
          _isLoading = false;
          notifyListeners();
          return err;
        }
      }

      // If active, update availability status in driverInfo
      final res = await ApiService.put('/api/auth/profile', {
        'driverInfo': {'availability': active},
      });

      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentUser = User.fromJson(data);
        return null; // Success
      } else {
        return 'Failed to update status';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> addCustomerAddress(Address newAddress) async {
    if (_currentUser == null) return 'User not logged in';
    final updatedList = List<Address>.from(_currentUser!.addresses)
      ..add(newAddress);
    try {
      final res = await ApiService.put('/api/auth/profile', {
        'addresses': updatedList.map((x) => x.toJson()).toList(),
      });
      if (res.statusCode == 200) {
        _currentUser = User.fromJson(jsonDecode(res.body));
        notifyListeners();
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to add address';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteCustomerAddress(String label) async {
    if (_currentUser == null) return 'User not logged in';
    final updatedList = List<Address>.from(_currentUser!.addresses)
      ..removeWhere((x) => x.label == label);
    try {
      final res = await ApiService.put('/api/auth/profile', {
        'addresses': updatedList.map((x) => x.toJson()).toList(),
      });
      if (res.statusCode == 200) {
        _currentUser = User.fromJson(jsonDecode(res.body));
        notifyListeners();
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to delete address';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<String>> fetchRegions(String governorate) async {
    try {
      final res = await ApiService.get(
        '/api/auth/regions?governorate=${Uri.encodeComponent(governorate)}',
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((x) => x.toString()).toList();
      }
    } catch (e) {
      debugPrint('Fetch regions error: $e');
    }
    return [];
  }

  Future<void> logout() async {
    _currentUser = null;
    await ApiService.setToken(null);
    SocketService.disconnect();
    notifyListeners();
  }

  void _connectSocket() {
    SocketService.connect(ApiService.token, (newOrderData) {}, (statusData) {});
  }
}

class RestaurantProvider extends ChangeNotifier {
  List<User> _restaurants = [];
  List<Product> _currentMenu = [];
  bool _isLoading = false;

  List<User> get restaurants => _restaurants;
  List<Product> get currentMenu => _currentMenu;
  bool get isLoading => _isLoading;

  Future<void> loadRestaurants() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.get('/api/restaurants');
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

  // Update product availability status
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

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  Map<String, CartItem> get items => _items;

  int get itemCount => _items.length;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.product.price * cartItem.quantity;
    });
    return total;
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
      await prefs.setString('cart_items', jsonEncode(serialized));
    } catch (e) {
      debugPrint('Failed to save cart: $e');
    }
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataStr = prefs.getString('cart_items');
      if (dataStr != null) {
        final List<dynamic> decoded = jsonDecode(dataStr);
        _items.clear();
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

  bool addItem(Product product) {
    if (_items.isNotEmpty) {
      final firstItem = _items.values.first;
      if (firstItem.product.restaurantId != product.restaurantId) {
        return false;
      }
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
    _saveCart();
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _saveCart();
    notifyListeners();
  }
}

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  List<Order> _availableOrders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  List<Order> get availableOrders => _availableOrders;
  bool get isLoading => _isLoading;

  Future<void> loadOrders([String? status]) async {
    _isLoading = true;
    notifyListeners();
    try {
      String path = '/api/orders';
      if (status != null) {
        path += '?status=$status';
      }
      final res = await ApiService.get(path);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _orders = data.map((x) => Order.fromJson(x)).toList();
        for (var o in _orders) {
          if ([
            'pending',
            'restaurant_accepted',
            'preparing',
            'ready',
            'delivery_accepted',
            'onTheWay',
            'delivered_pending',
          ].contains(o.status)) {
            SocketService.joinOrderRoom(o.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Load orders error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadAvailableOrders() async {
    try {
      final res = await ApiService.get('/api/orders?status=available');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        _availableOrders = data.map((x) => Order.fromJson(x)).toList();
      } else {
        _availableOrders = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Load available orders error: $e');
      _availableOrders = [];
      notifyListeners();
    }
  }

  // Purchase order requires GPS validation
  Future<String?> createOrder({
    required String restaurantId,
    required List<OrderItem> items,
    required double totalAmount,
    required Address deliveryAddress,
    required String paymentMethod,
    double deliveryFee = 2500,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 1. Enforce GPS Check
      final err = await LocationHelper.checkAndRequestPermissions();
      if (err != null) {
        _isLoading = false;
        notifyListeners();
        return err;
      }

      // 2. Fetch current coordinate
      Position pos = await Geolocator.getCurrentPosition();
      final finalAddress = Address(
        street: deliveryAddress.street,
        city: deliveryAddress.city,
        zipCode: deliveryAddress.zipCode,
        houseDoorPicture: deliveryAddress.houseDoorPicture,
        location: Location(coordinates: [pos.longitude, pos.latitude]),
      );

      final res = await ApiService.post('/api/orders', {
        'restaurantId': restaurantId,
        'items': items.map((x) => x.toJson()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': finalAddress.toJson(),
        'paymentMethod': paymentMethod,
        'deliveryFee': deliveryFee,
      });

      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 201) {
        final newOrder = Order.fromJson(jsonDecode(res.body));
        _orders.insert(0, newOrder);
        SocketService.joinOrderRoom(newOrder.id);
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to create order';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> acceptOrder(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.put('/api/orders/$orderId/accept', {});
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final updatedOrder = Order.fromJson(jsonDecode(res.body));
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        } else {
          _orders.insert(0, updatedOrder);
        }
        _availableOrders.removeWhere((o) => o.id == orderId);
        SocketService.joinOrderRoom(updatedOrder.id);
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to accept order';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> rejectOrder(String orderId) async {
    _availableOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    try {
      final res = await ApiService.put('/api/orders/$orderId/reject', {});
      if (res.statusCode == 200) {
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to reject order';
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateStatus(
    String orderId,
    String newStatus, {
    String? packagedPicture,
    String? receivedPicture,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {'status': newStatus};
      if (packagedPicture != null) body['packagedPicture'] = packagedPicture;
      if (receivedPicture != null) body['receivedPicture'] = receivedPicture;

      final res = await ApiService.put('/api/orders/$orderId/status', body);
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final updatedOrder = Order.fromJson(jsonDecode(res.body));
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        }
        return null;
      } else {
        return jsonDecode(res.body)['message'] ??
            'Failed to update order status';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> confirmDelivery(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.put('/api/orders/$orderId/deliver', {});
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final updatedOrder = Order.fromJson(data['order']);
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        }
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to deliver order';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> customerConfirmDelivery(
    String orderId, {
    String? receivedPicture,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> body = {};
      if (receivedPicture != null) body['receivedPicture'] = receivedPicture;

      final res = await ApiService.put(
        '/api/orders/$orderId/customer-confirm',
        body,
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final updatedOrder = Order.fromJson(data['order']);
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _orders[idx] = updatedOrder;
        }
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to confirm delivery';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
  }

  void setupSocketListeners() {
    SocketService.socket?.off('newOrderAvailable');
    SocketService.socket?.off('orderStatus');
    SocketService.socket?.off('deliveryConfirmed');

    SocketService.socket?.on('newOrderAvailable', (data) {
      final newOrder = Order.fromJson(data);
      if (!_orders.any((o) => o.id == newOrder.id)) {
        _orders.insert(0, newOrder);
        SocketService.joinOrderRoom(newOrder.id);
      }
      if (!_availableOrders.any((o) => o.id == newOrder.id)) {
        _availableOrders.insert(0, newOrder);
      }
      notifyListeners();
    });

    SocketService.socket?.on('orderStatus', (data) {
      final orderId = data['orderId'] ?? data['_id'];
      final status = data['status'];
      if (orderId != null && status != null) {
        final idx = _orders.indexWhere((o) => o.id == orderId.toString());
        if (idx != -1) {
          final o = _orders[idx];
          _orders[idx] = Order(
            id: o.id,
            customerId: o.customerId,
            restaurantId: o.restaurantId,
            driverId: o.driverId,
            items: o.items,
            totalAmount: o.totalAmount,
            currency: o.currency,
            deliveryFee: o.deliveryFee,
            status: status,
            deliveryAddress: o.deliveryAddress,
            paymentMethod: o.paymentMethod,
            paymentStatus: o.paymentStatus,
            expectedDeliveryTime: o.expectedDeliveryTime,
            packagedPicture: o.packagedPicture,
            receivedPicture: o.receivedPicture,
          );
        }
      }
      loadOrders();
      notifyListeners();
    });

    SocketService.socket?.on('deliveryConfirmed', (data) {
      loadOrders();
      notifyListeners();
    });
  }
}
