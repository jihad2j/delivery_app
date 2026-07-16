import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static String _baseUrl =
      'http://192.168.1.201:3000'; // Default for Android emulator
  static String? _token;
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? 'http://192.168.1.201:3000';
    _token = await _secureStorage.read(key: 'auth_token');
  }

  static String get baseUrl => _baseUrl;
  static String? get token => _token;

  static Future<void> setBaseUrl(String url) async {
    // Automatically upgrade to HTTPS if it's an external server (not localhost or local IP)
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
    _baseUrl = secureUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', secureUrl);
  }

  static Future<void> setToken(String? token) async {
    _token = token;
    if (token == null) {
      await _secureStorage.delete(key: 'auth_token');
    } else {
      await _secureStorage.write(key: 'auth_token', value: token);
    }
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

  static Future<http.Response> get(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http
        .post(url, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http
        .put(url, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> delete(String path) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http
        .delete(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
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
      debugPrint('Connected to Socket Server');
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
