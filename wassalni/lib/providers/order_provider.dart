import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';
import '../core/services.dart';

class OrderProvider extends ChangeNotifier {
  List<Order> _orders = [];
  List<Order> _availableOrders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  List<Order> get availableOrders => _availableOrders;
  bool get isLoading => _isLoading;

  int completedCountFor(String? driverId) {
    if (driverId == null || driverId.isEmpty) return 0;
    return _orders.where((o) =>
      o.driverIdStr == driverId &&
      (o.status == 'delivered' || o.status == 'completed' || o.status == 'delivered_pending')
    ).length;
  }

  double todayEarningsFor(String? driverId) {
    if (driverId == null || driverId.isEmpty) return 0.0;
    final now = DateTime.now();
    double total = 0.0;
    for (var o in _orders) {
      if (o.driverIdStr == driverId &&
          (o.status == 'delivered' || o.status == 'completed' || o.status == 'delivered_pending')) {
        final t = o.expectedDeliveryTime ?? DateTime.now();
        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          total += (o.driverShare ?? o.deliveryFee);
        }
      }
    }
    return total;
  }

  double weeklyEarningsFor(String? driverId) {
    if (driverId == null || driverId.isEmpty) return 0.0;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    double total = 0.0;
    for (var o in _orders) {
      if (o.driverIdStr == driverId &&
          (o.status == 'delivered' || o.status == 'completed' || o.status == 'delivered_pending')) {
        final t = o.expectedDeliveryTime ?? DateTime.now();
        if (t.isAfter(cutoff)) {
          total += (o.driverShare ?? o.deliveryFee);
        }
      }
    }
    return total;
  }

  double ratingForDriver(String? driverId) {
    if (driverId == null || driverId.isEmpty) return 0;
    return 0;
  }

  double todaySalesForRestaurant(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return 0.0;
    final now = DateTime.now();
    double total = 0.0;
    for (var o in _orders) {
      if (o.restaurantIdStr == restaurantId &&
          (o.status == 'delivered' || o.status == 'completed' || o.status == 'delivered_pending')) {
        final t = o.expectedDeliveryTime ?? DateTime.now();
        if (t.year == now.year && t.month == now.month && t.day == now.day) {
          total += (o.restaurantShare ?? o.totalAmount);
        }
      }
    }
    return total;
  }

  int pendingOrdersCountForRestaurant(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return 0;
    return _orders.where((o) =>
      o.restaurantIdStr == restaurantId &&
      ['pending', 'restaurant_accepted', 'preparing', 'ready'].contains(o.status)
    ).length;
  }

  double weeklySalesForRestaurant(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return 0.0;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    double total = 0.0;
    for (var o in _orders) {
      if (o.restaurantIdStr == restaurantId &&
          (o.status == 'delivered' || o.status == 'completed' || o.status == 'delivered_pending')) {
        final t = o.expectedDeliveryTime ?? DateTime.now();
        if (t.isAfter(cutoff)) {
          total += (o.restaurantShare ?? o.totalAmount);
        }
      }
    }
    return total;
  }

  double ratingForRestaurant(String? restaurantId) {
    if (restaurantId == null || restaurantId.isEmpty) return 0;
    return 0;
  }

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

  Future<String?> createOrder({
    required String restaurantId,
    required List<OrderItem> items,
    required double totalAmount,
    required Address deliveryAddress,
    required String paymentMethod,
    double deliveryFee = 2500,
    String? promoCode,
    double? discountAmount,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final err = await LocationHelper.checkAndRequestPermissions();
      if (err != null) {
        _isLoading = false;
        notifyListeners();
        return err;
      }

      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        pos = Position(
          longitude: deliveryAddress.location?.coordinates[0] ?? 36.2765,
          latitude: deliveryAddress.location?.coordinates[1] ?? 33.5138,
          timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
        );
      }
      final finalAddress = Address(
        street: deliveryAddress.street,
        city: deliveryAddress.city,
        zipCode: deliveryAddress.zipCode,
        houseDoorPicture: deliveryAddress.houseDoorPicture,
        location: Location(coordinates: [pos.longitude, pos.latitude]),
      );

      final Map<String, dynamic> reqBody = {
        'restaurantId': restaurantId,
        'items': items.map((x) => x.toJson()).toList(),
        'totalAmount': totalAmount,
        'deliveryAddress': finalAddress.toJson(),
        'paymentMethod': paymentMethod,
        'deliveryFee': deliveryFee,
      };
      if (promoCode != null) reqBody['promoCode'] = promoCode;
      if (discountAmount != null) reqBody['discountAmount'] = discountAmount;

      final res = await ApiService.post('/api/orders', reqBody);

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

  Future<Map<String, dynamic>?> validatePromoCode(String code) async {
    try {
      final res = await ApiService.post('/api/promos/validate', {'code': code});
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['promo'];
      }
      return null;
    } catch (e) {
      debugPrint('Validate promo code error: $e');
      return null;
    }
  }

  Future<String?> rateOrder(String orderId, int rating, String? review) async {
    try {
      final Map<String, dynamic> body = {'rating': rating};
      if (review != null && review.isNotEmpty) body['review'] = review;
      final res = await ApiService.post('/api/orders/$orderId/rate', body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final updatedOrder = Order.fromJson(data['order']);
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) _orders[idx] = updatedOrder;
        notifyListeners();
        return null;
      } else {
        return jsonDecode(res.body)['message'] ?? 'Failed to rate order';
      }
    } catch (e) {
      return e.toString();
    }
  }

  void setupSocketListeners() {
    SocketService.socket?.off('refreshOrders');
    SocketService.socket?.off('refreshAvailableOrders');
    SocketService.socket?.off('refreshOrderStatus');
    SocketService.socket?.off('newOrderAvailable');
    SocketService.socket?.off('newOrderCreated');
    SocketService.socket?.off('newOrderForRestaurant');
    SocketService.socket?.off('orderStatus');
    SocketService.socket?.off('orderStatusChanged');
    SocketService.socket?.off('deliveryConfirmed');

    void handleRefreshSignal(dynamic data) {
      debugPrint('[Socket Refresh Signal Received] Reloading via REST API...');
      loadOrders();
      loadAvailableOrders();
    }

    SocketService.socket?.on('refreshOrders', handleRefreshSignal);
    SocketService.socket?.on('refreshAvailableOrders', handleRefreshSignal);
    SocketService.socket?.on('refreshOrderStatus', handleRefreshSignal);

    SocketService.socket?.on('newOrderAvailable', (data) {
      loadOrders();
      loadAvailableOrders();
    });
    SocketService.socket?.on('newOrderCreated', handleRefreshSignal);
    SocketService.socket?.on('newOrderForRestaurant', handleRefreshSignal);
    SocketService.socket?.on('orderStatus', handleRefreshSignal);
    SocketService.socket?.on('orderStatusChanged', handleRefreshSignal);
    SocketService.socket?.on('deliveryConfirmed', handleRefreshSignal);
  }
}
