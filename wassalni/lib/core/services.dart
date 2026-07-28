import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static List<String> _serverUrls = [
    'http://192.168.31.201:3000', // السيرفر الأساسي
    'http://192.168.1.110:3000', // السيرفر الاحتياطي 1
  ];
  static int _currentServerIndex = 0;
  static String? _token;
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrls = prefs.getStringList('api_server_urls');
    if (savedUrls != null && savedUrls.isNotEmpty) {
      _serverUrls = savedUrls;
    } else {
      final legacyUrl = prefs.getString('api_base_url');
      if (legacyUrl != null && !_serverUrls.contains(legacyUrl)) {
        _serverUrls.insert(0, legacyUrl);
      }
    }
    _token = await _secureStorage.read(key: 'auth_token');
  }

  static String get baseUrl => _serverUrls[_currentServerIndex];
  static List<String> get serverUrls => List.unmodifiable(_serverUrls);
  static String? get token => _token;

  static Future<void> setServerUrls(List<String> urls) async {
    if (urls.isEmpty) return;
    final sanitizedUrls = urls.map((url) {
      String secureUrl = url;
      if (!url.startsWith('https://') &&
          !url.contains('localhost') &&
          !url.contains('127.0.0.1') &&
          !url.contains('192.168.')) {
        secureUrl = url.replaceFirst('http://', 'https://');
        if (!secureUrl.startsWith('https://')) {
          secureUrl = 'https://$secureUrl';
        }
      }
      return secureUrl;
    }).toList();

    _serverUrls = sanitizedUrls;
    _currentServerIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('api_server_urls', sanitizedUrls);
    await prefs.setString('api_base_url', _serverUrls[0]);
  }

  static Future<void> setBaseUrl(String url) async {
    await setServerUrls([url]);
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _secureStorage.delete(key: 'auth_token');
      await clearCachedUserData();
    } else {
      await _secureStorage.write(key: 'auth_token', value: token);
    }
  }

  static Future<void> saveCachedUserData(Map<String, dynamic> userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_data', jsonEncode(userJson));
  }

  static Future<Map<String, dynamic>?> getCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('cached_user_data');
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        return jsonDecode(dataStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error reading cached user data: $e');
      }
    }
    return null;
  }

  static Future<void> clearCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_data');
  }

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// التنقل للسيرفر التالي في حال انقطاع السيرفر الحالي
  static String rotateToNextServer() {
    if (_serverUrls.length <= 1) return baseUrl;
    _currentServerIndex = (_currentServerIndex + 1) % _serverUrls.length;
    debugPrint('[ApiService Failover] Switched to backup server: $baseUrl');
    return baseUrl;
  }

  /// تنفيذ الطلبات مع دعم الانتقال الآلي للسيرفر الاحتياطي عند الفشل
  static Future<http.Response> _executeWithFailover(
    Future<http.Response> Function(String currentBaseUrl) requestFn,
  ) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts && attempts < _serverUrls.length) {
      try {
        final response = await requestFn(baseUrl);
        return response;
      } catch (e) {
        attempts++;
        debugPrint('[ApiService Failover] Connection failed on $baseUrl: $e');
        if (attempts < _serverUrls.length) {
          rotateToNextServer();
        } else {
          rethrow;
        }
      }
    }
    throw Exception('جميع السيرفرات غير متاحة حالياً');
  }

  static Future<http.Response> get(String path) async {
    return _executeWithFailover((currentBase) {
      final url = Uri.parse('$currentBase$path');
      return http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
    });
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _executeWithFailover((currentBase) {
      final url = Uri.parse('$currentBase$path');
      return http
          .post(url, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
    });
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _executeWithFailover((currentBase) {
      final url = Uri.parse('$currentBase$path');
      return http
          .put(url, headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 10));
    });
  }

  static Future<http.Response> delete(String path) async {
    return _executeWithFailover((currentBase) {
      final url = Uri.parse('$currentBase$path');
      return http
          .delete(url, headers: _headers)
          .timeout(const Duration(seconds: 10));
    });
  }
}

class LocationHelper {
  /// Checks if GPS is enabled and requests permissions if needed.
  /// Returns null if granted, or one of 'GPS_DISABLED', 'GPS_DENIED', 'GPS_DENIED_FOREVER' on error.
  static Future<String?> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'GPS_DISABLED';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return 'GPS_DENIED';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return 'GPS_DENIED_FOREVER';
    }

    return null;
  }
}

class SocketService {
  static io.Socket? _socket;
  static bool _isConnected = false;

  static bool get isConnected => _isConnected;
  static io.Socket? get socket => _socket;

  static void connect(
    String? token,
    Function(dynamic) onNewOrder,
    Function(dynamic) onOrderStatus,
  ) {
    if (_socket != null) {
      _socket!.disconnect();
    }

    final opts = io.OptionBuilder().setTransports([
      'websocket',
    ]).disableAutoConnect();

    if (token != null) {
      opts.setAuth({'token': token});
    }

    _socket = io.io(ApiService.baseUrl, opts.build());

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('Connected to Socket Server: ${ApiService.baseUrl}');
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      debugPrint(
        '[Socket Failover] Connect error on ${ApiService.baseUrl}: $err. Rotating server...',
      );
      ApiService.rotateToNextServer();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('Disconnected from Socket Server');
    });

    // Listen to new order for drivers
    _socket!.on('newOrderAvailable', (data) {
      onNewOrder(data);
    });

    // Listen to status updates
    _socket!.on('orderStatus', (data) {
      onOrderStatus(data);
    });

    _socket!.connect();
  }

  static void joinOrderRoom(String orderId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('joinOrderRoom', orderId);
    }
  }

  static void leaveOrderRoom(String orderId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leaveOrderRoom', orderId);
    }
  }

  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
}
