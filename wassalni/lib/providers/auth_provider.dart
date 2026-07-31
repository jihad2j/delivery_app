import 'dart:convert';
import 'package:flutter/material.dart';
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

    final cachedUserData = await ApiService.getCachedUserData();
    if (cachedUserData != null) {
      try {
        _currentUser = User.fromJson(cachedUserData);
        _connectSocket();
      } catch (e) {
        debugPrint('Error restoring cached user: $e');
      }
    }

    if (ApiService.token != null) {
      try {
        final res = await ApiService.get('/api/auth/profile');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _currentUser = User.fromJson(data);
          await ApiService.saveCachedUserData(data);
          _connectSocket();
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          await logout();
        }
      } catch (e) {
        debugPrint('Auto-login background refresh failed: $e');
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
    String? cuisineType,
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
    List<Address>? addresses,
    RestaurantInfo? restaurantInfo,
    DriverInfo? driverInfo,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (address != null) updates['address'] = address.toJson();
      if (addresses != null) {
        updates['addresses'] = addresses.map((a) => a.toJson()).toList();
      }
      if (restaurantInfo != null) {
        updates['restaurantInfo'] = restaurantInfo.toJson();
        updates['description'] = restaurantInfo.description;
        updates['logo'] = restaurantInfo.logo;
        updates['status'] = restaurantInfo.status;
        updates['minOrderAmount'] = restaurantInfo.minOrderAmount;
        updates['deliveryFee'] = restaurantInfo.deliveryFee;
        updates['cuisineType'] = restaurantInfo.cuisineType;
        updates['firebaseNotifications'] = restaurantInfo.firebaseNotifications;
        if (restaurantInfo.openingTime != null) {
          updates['openingTime'] = restaurantInfo.openingTime;
        }
        if (restaurantInfo.closingTime != null) {
          updates['closingTime'] = restaurantInfo.closingTime;
        }
      }
      if (driverInfo != null) {
        updates['driverInfo'] = driverInfo.toJson();
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

      final res = await ApiService.put('/api/auth/profile', {
        'driverInfo': {'availability': active},
      });

      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentUser = User.fromJson(data);
        return null;
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

  Future<String?> settleDriverWallet(String settlementType) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.post('/api/auth/settle-driver', {
        'settlementType': settlementType,
      });
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['user'] != null) {
          _currentUser = User.fromJson(data['user']);
          await ApiService.saveCachedUserData(data['user']);
        }
        notifyListeners();
        return null;
      } else {
        final err = jsonDecode(res.body);
        return err['message'] ?? 'فشل ترصيد ومحاسبة السائق';
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString();
    }
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
