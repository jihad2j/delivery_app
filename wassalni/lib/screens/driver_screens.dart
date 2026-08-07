// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../providers/providers.dart';
import '../models/models.dart' as model;
import '../core/theme.dart';
import '../core/services.dart';

// ════════════════════════════════════════════════════════
// DRIVER HOME SCREEN — Rebuilt with Live Diagnostics & Safety Auto-Unlock
// ════════════════════════════════════════════════════════
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  LatLng? _currentPos;
  final double _heading = 0;
  bool _followMap = true;
  Timer? _posTimer;

  // Route state
  List<LatLng> _polyPoints = [];
  double _routeDistKm = 0;
  double _routeDurationMin = 0;
  bool _isRouteFetching = false;
  String? _activeOrderId;

  // Notification Banner
  String? _bannerMsg;
  Color _bannerBg = AppTheme.primary;
  IconData _bannerIcon = Icons.info_outline;
  Timer? _bannerTimer;

  // Diagnostic Logs & Immunity Lock System
  bool _isToggling = false;
  final List<String> _diagLogs = [];
  bool _showDiagPanel = false;
  Timer? _safetyUnlockTimer;

  late AnimationController _pulseAnim;

  static const _activeStatusList = [
    'delivery_accepted',
    'preparing',
    'ready',
    'onTheWay',
    'delivered_pending'
  ];

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    Future.microtask(() {
      if (!mounted) return;
      final op = context.read<OrderProvider>();
      op.loadOrders();
      op.loadAvailableOrders();
      op.setupSocketListeners();
      op.addListener(_handleOrderUpdates);
      context.read<RestaurantProvider>().loadRestaurants();

      _initLocation();
    });

    SocketService.socket?.on('deliveryConfirmed', _handleDeliverySuccess);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _posTimer?.cancel();
    _safetyUnlockTimer?.cancel();
    _pulseAnim.dispose();
    try {
      context.read<OrderProvider>().removeListener(_handleOrderUpdates);
    } catch (_) {}
    SocketService.socket?.off('deliveryConfirmed', _handleDeliverySuccess);
    super.dispose();
  }

  void _addDiag(String step) {
    final timeStr = DateTime.now().toString().split(' ').last.substring(0, 8);
    final logLine = '[$timeStr] $step';
    debugPrint('[DriverDiag] $logLine');
    if (!mounted) return;
    setState(() {
      _diagLogs.add(logLine);
      if (_diagLogs.length > 15) _diagLogs.removeAt(0);
    });
  }

  void _notify(String msg,
      {Color color = AppTheme.primary,
      IconData icon = Icons.info_outline,
      int sec = 4}) {
    _bannerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _bannerMsg = msg;
      _bannerBg = color;
      _bannerIcon = icon;
    });
    _bannerTimer = Timer(Duration(seconds: sec), () {
      if (mounted) setState(() => _bannerMsg = null);
    });
  }

  Future<void> _initLocation() async {
    _addDiag('بدء فحص الموقع الأولي...');
    try {
      final permErr = await LocationHelper.checkAndRequestPermissions();
      if (permErr != null || !mounted) {
        _addDiag('فحص الإذن: $permErr');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 4));

      if (!mounted) return;
      setState(() => _currentPos = LatLng(pos.latitude, pos.longitude));
      _addDiag('تم تحديد الموقع بنجاح');

      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.driverInfo?.availability == true) {
        _startPosSync();
      }
      _handleOrderUpdates();
    } catch (e) {
      _addDiag('خطأ تحديد الموقع: $e');
    }
  }

  void _startPosSync() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.driverInfo?.availability != true) {
        timer.cancel();
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 4));

        if (!mounted) return;
        final newPt = LatLng(pos.latitude, pos.longitude);
        setState(() => _currentPos = newPt);

        if (_followMap) {
          try {
            _map.move(newPt, _map.camera.zoom);
          } catch (_) {}
        }

        final uid = auth.currentUser?.id ?? '';
        await ApiService.put('/api/users/$uid/location', {
          'lat': pos.latitude,
          'lng': pos.longitude,
        }).timeout(const Duration(seconds: 3));

        context.read<OrderProvider>().loadAvailableOrders();
        _handleOrderUpdates();
      } catch (_) {}
    });
  }

  void _handleOrderUpdates() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final op = context.read<OrderProvider>();
    final uid = auth.currentUser?.id;

    final activeList = op.orders
        .where(
            (o) => o.driverIdStr == uid && _activeStatusList.contains(o.status))
        .toList();

    if (activeList.isEmpty) {
      if (_activeOrderId != null) {
        _notify('تم توصيل الطلب بنجاح!',
            color: Colors.green, icon: Icons.check_circle, sec: 4);
      }
      setState(() {
        _activeOrderId = null;
        _polyPoints = [];
        _routeDistKm = 0;
        _routeDurationMin = 0;
      });
      return;
    }

    final currentOrder = activeList.first;
    if (_activeOrderId != currentOrder.id || _polyPoints.isEmpty) {
      _activeOrderId = currentOrder.id;
      _calculateRoute(currentOrder);
    }
  }

  void _handleDeliverySuccess(dynamic _) {
    if (mounted) {
      _notify('تم تأكيد استلام الطلب من العميل!',
          color: Colors.green, icon: Icons.check_circle);
      context.read<OrderProvider>().loadOrders();
    }
  }

  Future<void> _calculateRoute(model.Order order) async {
    if (_currentPos == null || _isRouteFetching) return;

    LatLng? destination;
    final headingToRest =
        ['delivery_accepted', 'preparing', 'ready'].contains(order.status);

    if (headingToRest) {
      if (order.restaurantId is Map) {
        final c =
            (order.restaurantId as Map)['address']?['location']?['coordinates'];
        if (c is List && c.length >= 2) {
          destination = LatLng(c[1].toDouble(), c[0].toDouble());
        }
      }
      if (destination == null) {
        final rests = context.read<RestaurantProvider>().restaurants;
        final r = rests.where((x) => x.id == order.restaurantIdStr).toList();
        if (rests.isNotEmpty && r.isNotEmpty) {
          final coords = r.first.address?.location?.coordinates;
          if (coords != null && coords.length >= 2) {
            destination = LatLng(coords[1], coords[0]);
          }
        }
      }
    } else {
      final loc = order.deliveryAddress.location;
      if (loc != null && loc.coordinates.length >= 2) {
        destination = LatLng(loc.coordinates[1], loc.coordinates[0]);
      }
    }

    if (destination == null) return;
    setState(() => _isRouteFetching = true);

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${_currentPos!.longitude},${_currentPos!.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final r = body['routes']?[0];
        if (r != null) {
          final pts = (r['geometry']['coordinates'] as List)
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
          setState(() {
            _polyPoints = pts;
            _routeDistKm = (r['distance'] as num) / 1000;
            _routeDurationMin = (r['duration'] as num) / 60;
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRouteFetching = false);
    }
  }

  // ════════════════════════════════════════════════════════
  // INNOVATIVE TOGGLE AVAILABILITY WITH DIAGNOSTICS & HARD UNLOCK
  // ════════════════════════════════════════════════════════
  Future<void> _toggleAvailability(bool wantAvailable) async {
    _addDiag('1️⃣ تم النقر على زر (${wantAvailable ? "جاهز" : "متوقف"})');

    if (_isToggling) {
      _addDiag('⚠️ طلب مكرر: الشاشة قيد المعالجة بالفعل!');
      return;
    }

    final auth = context.read<AuthProvider>();
    final op = context.read<OrderProvider>();
    final uid = auth.currentUser?.id;

    final hasActive = op.orders.any(
        (o) => o.driverIdStr == uid && _activeStatusList.contains(o.status));

    if (hasActive && !wantAvailable) {
      _addDiag('❌ تم الرفض: يوجد طلب نشط');
      _notify('لا يمكنك الخروج من الخدمة أثناء وجود طلب نشط!',
          color: Colors.red, icon: Icons.warning_amber);
      return;
    }

    // Lock UI and show diagnostics automatically
    setState(() {
      _showDiagPanel = true;
    });

    // Fast unlock timer: Releases button touch state in 400ms!
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && _isToggling) {
        setState(() => _isToggling = false);
      }
    });

    try {
      _addDiag('2️⃣ جاري فحص أذونات الموقع والـ GPS...');
      final permErr = await LocationHelper.checkAndRequestPermissions()
          .timeout(const Duration(seconds: 3), onTimeout: () => 'GPS_TIMEOUT');

      if (permErr != null && wantAvailable) {
        _addDiag('❌ مشكلة بالـ GPS: $permErr');
        _notify('الرجاء تفعيل الـ GPS لمنح صلاحية الموقع',
            color: Colors.orange);
        return;
      }

      _addDiag('3️⃣ جاري تحديث الحالة والتواصل مع السيرفر...');
      if (wantAvailable) {
        _startPosSync();
        _notify('أنت الآن جاهز واستقبال الطلبات مفعّل',
            color: Colors.green, icon: Icons.wifi_tethering);
      } else {
        _posTimer?.cancel();
        _notify('تم التوقف عن استقبال الطلبات',
            color: Colors.orange, icon: Icons.power_settings_new);
      }

      final res = await auth.toggleDriverAvailability(wantAvailable);
      if (res != null && mounted) {
        _addDiag('ملاحظة من السيرفر: $res');
      } else {
        _addDiag('4️⃣ ✅ اكتمل التحديث بنجاح!');
      }
    } catch (e) {
      _addDiag('تحديث محلي أوفلاين (تعذر السيرفر: $e)');
    } finally {
      _safetyUnlockTimer?.cancel();
      if (mounted) {
        _addDiag('5️⃣ 🔓 التفاعل مفعل 100%.');
        setState(() => _isToggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();
    final restProv = context.watch<RestaurantProvider>();

    final uid = auth.currentUser?.id;
    final isOnline = auth.currentUser?.driverInfo?.availability ?? false;

    final activeOrders = op.orders
        .where(
            (o) => o.driverIdStr == uid && _activeStatusList.contains(o.status))
        .toList();

    final center = _currentPos ?? const LatLng(33.5138, 36.2765);

    return Scaffold(
      drawer: _buildAppDrawer(context, auth),
      body: Stack(
        children: [
          // MAP CANVAS
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14.0,
                onPositionChanged: (_, userGesture) {
                  if (userGesture) setState(() => _followMap = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.wassalni.app',
                ),
                if (activeOrders.isNotEmpty && _polyPoints.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _polyPoints,
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      strokeWidth: 8.0,
                    ),
                    Polyline(
                      points: _polyPoints,
                      color: AppTheme.primary,
                      strokeWidth: 4.0,
                    ),
                  ]),
                MarkerLayer(
                    markers:
                        _buildMapMarkers(activeOrders, isOnline, restProv)),
              ],
            ),
          ),

          // TOP STATUS BAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => _IconButtonGlass(
                        icon: Icons.menu_rounded,
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GlassPanel(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          child: _buildHeaderStatusText(activeOrders),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _OnlineToggleChip(
                      isOnline: isOnline,
                      isBusy: _isToggling,
                      hasActiveOrder: activeOrders.isNotEmpty,
                      onToggle: () => _toggleAvailability(!isOnline),
                      onForceUnlock: () {
                        setState(() => _isToggling = false);
                        _addDiag('🔓 تم إلغاء القفل يدويًا!');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // LIVE DIAGNOSTIC PANEL OVERLAY
          if (_showDiagPanel && _diagLogs.isNotEmpty)
            Positioned(
              top: 85,
              left: 14,
              right: 14,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(16),
                color: Colors.black.withValues(alpha: 0.88),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bug_report_rounded,
                                  color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text('فحص التشخيص المباشر',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              if (_isToggling)
                                InkWell(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('فك القفل الآن',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white70, size: 16),
                                onPressed: () =>
                                    setState(() => _showDiagPanel = false),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _diagLogs
                            .take(5)
                            .map((log) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    log,
                                    style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 10.5,
                                        fontFamily: 'monospace'),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // FLOATING NOTIFICATION BANNER
          if (_bannerMsg != null && !_showDiagPanel)
            Positioned(
              top: 90,
              left: 16,
              right: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                color: _bannerBg.withValues(alpha: 0.95),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_bannerIcon, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _bannerMsg!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // FLOATING MAP CONTROLS
          Positioned(
            bottom: activeOrders.isNotEmpty ? 250 : 180,
            left: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconButtonGlass(
                    icon: _followMap
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    color: _followMap ? Colors.green : AppTheme.primary,
                    onTap: () {
                      setState(() => _followMap = true);
                      if (_currentPos != null) {
                        _map.move(_currentPos!, 15.5);
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  _IconButtonGlass(
                    icon: Icons.add_rounded,
                    onTap: () =>
                        _map.move(_map.camera.center, _map.camera.zoom + 1),
                  ),
                  const SizedBox(height: 6),
                  _IconButtonGlass(
                    icon: Icons.remove_rounded,
                    onTap: () =>
                        _map.move(_map.camera.center, _map.camera.zoom - 1),
                  ),
                  const SizedBox(height: 6),
                  _IconButtonGlass(
                    icon: Icons.bug_report_outlined,
                    color: Colors.amber.shade800,
                    onTap: () =>
                        setState(() => _showDiagPanel = !_showDiagPanel),
                  ),
                ],
              ),
            ),
          ),

          // PENDING SETTLEMENT NOTIFICATION
          if (auth.currentUser?.pendingSettlement != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _PendingSettlementCard(
                auth: auth,
                user: auth.currentUser!,
                onResult: (msg, ok) => _notify(msg,
                    color: ok ? Colors.green : Colors.red,
                    icon: ok ? Icons.check_circle : Icons.error),
              ),
            ),

          // BOTTOM ACTIVE ORDER / AVAILABLE ORDERS / WAITING CARD
          if (activeOrders.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _ActiveOrderCardSheet(
                order: activeOrders.first,
                distKm: _routeDistKm,
                onNotify: _notify,
              ),
            )
          else if (isOnline && op.availableOrders.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _AvailableOrdersSheet(
                availableOrders: op.availableOrders,
                onNotify: _notify,
              ),
            )
          else
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _WaitingForOrdersCard(
                isOnline: isOnline,
                pulseAnim: _pulseAnim,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusText(List<model.Order> active) {
    if (active.isEmpty) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.radar_rounded, color: AppTheme.primary, size: 18),
          SizedBox(width: 6),
          Text(
            'بانتظار طلب جديد...',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      );
    }
    final o = active.first;
    final isHeadingToRest =
        ['delivery_accepted', 'preparing', 'ready'].contains(o.status);

    return Row(
      children: [
        Icon(
          isHeadingToRest
              ? Icons.restaurant_rounded
              : Icons.person_pin_circle_rounded,
          color: isHeadingToRest ? Colors.orange : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHeadingToRest ? 'المسار الى المطعم' : 'المسار الى العميل',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
              ),
              Text(
                '${_routeDistKm.toStringAsFixed(1)} كم - ${_routeDurationMin.toStringAsFixed(0)} دقيقة',
                style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMapMarkers(
      List<model.Order> active, bool isOnline, RestaurantProvider restProv) {
    final list = <Marker>[];

    // Driver Current Location Marker
    if (_currentPos != null) {
      list.add(Marker(
        point: _currentPos!,
        width: 64,
        height: 64,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              final scale = 1.0 + _pulseAnim.value * 0.35;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48 * scale,
                    height: 48 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isOnline ? Colors.green : Colors.blue)
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  Transform.rotate(
                    angle: _heading * pi / 180,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.navigation_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ));
    }

    // Destination Marker
    if (active.isNotEmpty) {
      final o = active.first;
      final isRest =
          ['delivery_accepted', 'preparing', 'ready'].contains(o.status);

      if (isRest) {
        LatLng? rLatLng;
        if (o.restaurantId is Map) {
          final c =
              (o.restaurantId as Map)['address']?['location']?['coordinates'];
          if (c is List && c.length >= 2) {
            rLatLng = LatLng(c[1].toDouble(), c[0].toDouble());
          }
        }
        if (rLatLng != null) {
          list.add(Marker(
            point: rLatLng,
            width: 48,
            height: 48,
            child: const _MapMarkerPin(
                name: 'المطعم', icon: Icons.restaurant, color: Colors.orange),
          ));
        }
      } else {
        final loc = o.deliveryAddress.location;
        if (loc != null && loc.coordinates.length >= 2) {
          list.add(Marker(
            point: LatLng(loc.coordinates[1], loc.coordinates[0]),
            width: 48,
            height: 48,
            child: const _MapMarkerPin(
                name: 'العميل',
                icon: Icons.person_pin_circle_rounded,
                color: Colors.red),
          ));
        }
      }
    }

    return list;
  }

  Widget _buildAppDrawer(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark]),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.name.substring(0, 1).toUpperCase() ?? 'D',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary),
              ),
            ),
            accountName: Text(user?.name ?? 'الكابتن',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            accountEmail: Text(user?.phone ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_rounded, color: Colors.blue),
            title: const Text('سجل الطلبات والتصدير'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DriverOrdersHistoryScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.green),
            title: const Text('المحفظة والرصيد'),
            trailing: Chip(
              label: Text('${user?.balance.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              backgroundColor: Colors.green,
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DriverWalletScreen()));
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('تسجيل الخروج',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// AVAILABLE ORDERS SHEET — Accept / Reject Pending Requests
// ════════════════════════════════════════════════════════
class _AvailableOrdersSheet extends StatefulWidget {
  final List<model.Order> availableOrders;
  final void Function(String, {Color color, IconData icon, int sec}) onNotify;

  const _AvailableOrdersSheet({
    required this.availableOrders,
    required this.onNotify,
  });

  @override
  State<_AvailableOrdersSheet> createState() => _AvailableOrdersSheetState();
}

class _AvailableOrdersSheetState extends State<_AvailableOrdersSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.availableOrders.isEmpty) return const SizedBox.shrink();
    final order = widget.availableOrders.first;
    final restProv = context.watch<RestaurantProvider>();

    String restName = 'مطعم ماك';
    if (order.restaurantId is Map) {
      restName = (order.restaurantId as Map)['name'] ?? restName;
    } else {
      final match = restProv.restaurants
          .where((r) => r.id == order.restaurantIdStr)
          .toList();
      if (match.isNotEmpty) restName = match.first.name;
    }

    final feeText = '${order.deliveryFee.toStringAsFixed(0)} ل.س';
    final totalText = '${order.totalAmount.toStringAsFixed(0)} ل.س';
    final street = order.deliveryAddress.street;
    final streetText = (street != null && street.isNotEmpty)
        ? street
        : 'عنوان العميل (انظر الخريطة)';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.new_releases_rounded,
                          color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'طلب جديد متاح!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'أجرة التوصيل: $feeText',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.restaurant_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    restName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العنوان: $streetText',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'المجموع: $totalText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'الدفع: ${order.paymentMethod == 'cash' ? 'نقداً عند التسليم' : 'إلكتروني'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final op = context.read<OrderProvider>();
                            await op.rejectOrder(order.id);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('تجاهل',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            try {
                              final op = context.read<OrderProvider>();
                              final err = await op.acceptOrder(order.id);
                              if (!mounted) return;
                              if (err == null) {
                                widget.onNotify(
                                    'تم قبول الطلب بنجاح! جاري التوجيه إلى المطعم...',
                                    color: Colors.green,
                                    icon: Icons.check_circle);
                                await op.loadOrders();
                              } else {
                                widget.onNotify(err,
                                    color: Colors.red, icon: Icons.error);
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessing = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('قبول الطلب 🚴‍♂️',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// WAITING FOR ORDERS CARD — Live Status Banner
// ════════════════════════════════════════════════════════
class _WaitingForOrdersCard extends StatelessWidget {
  final bool isOnline;
  final AnimationController pulseAnim;

  const _WaitingForOrdersCard({
    required this.isOnline,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).cardColor.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isOnline)
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green
                          .withValues(alpha: 0.15 + pulseAnim.value * 0.15),
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: Colors.green, size: 24),
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Colors.orange, size: 24),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'بانتظار طلب جديد...' : 'أنت غير متصل حالياً',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOnline
                        ? 'أنت جاهز ومستعد لاستقبال أحدث طلبات التوصيل'
                        : 'انقر على مفتاح التشغيل أعلى الشاشة لبدء استقبال الطلبات',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// ACTIVE ORDER SHEET — Modern, Clean, No Render Errors
// ════════════════════════════════════════════════════════
class _ActiveOrderCardSheet extends StatefulWidget {
  final model.Order order;
  final double distKm;
  final void Function(String, {Color color, IconData icon, int sec}) onNotify;

  const _ActiveOrderCardSheet({
    required this.order,
    required this.distKm,
    required this.onNotify,
  });

  @override
  State<_ActiveOrderCardSheet> createState() => _ActiveOrderCardSheetState();
}

class _ActiveOrderCardSheetState extends State<_ActiveOrderCardSheet> {
  bool _isUpdating = false;

  Future<void> _updateStatus(String nextStatus, String successMsg) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final op = context.read<OrderProvider>();
      final err = await op
          .updateStatus(widget.order.id, nextStatus)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (err == null) {
        widget.onNotify(successMsg,
            color: Colors.green, icon: Icons.check_circle);
        await op.loadOrders();
      } else {
        widget.onNotify(err, color: Colors.red, icon: Icons.error);
      }
    } catch (e) {
      if (mounted) widget.onNotify('فشل تحديث الحالة: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _confirmDelivery() async {
    if (_isUpdating) return;

    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (pickedFile == null) {
      if (mounted) {
        widget.onNotify('يجب التقاط صورة لإثبات التسليم', color: Colors.red);
      }
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final op = context.read<OrderProvider>();
      final err = await op
          .updateStatus(widget.order.id, 'delivered_pending',
              receivedPicture: base64Image)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (err == null) {
        widget.onNotify('تم تأكيد التسليم مع إرفاق الصورة',
            color: Colors.green, icon: Icons.check_circle);
        await op.loadOrders();
      } else {
        widget.onNotify(err, color: Colors.red);
      }
    } catch (e) {
      if (mounted) widget.onNotify('خطأ: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CARD HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark]),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'أجر التوصيل: ${order.deliveryFee.toStringAsFixed(0)} ل.س | الإجمالي: ${order.totalAmount.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ADDRESS DETAILS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'العنوان: ${order.deliveryAddress.city ?? ''} - ${order.deliveryAddress.street ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ACTION BUTTON AREA
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildActionButton(order),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(model.Order order) {
    if ([
      'pending',
      'restaurant_accepted',
      'preparing',
      'ready',
      'delivery_accepted'
    ].contains(order.status)) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUpdating
              ? null
              : () =>
                  _updateStatus('onTheWay', 'تم استلام الطلب وبدء التوصيل!'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdating)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.directions_bike_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                _isUpdating ? 'جاري التحديث...' : 'استلمت الطلب - بدء التوصيل',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (order.status == 'onTheWay') {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUpdating ? null : _confirmDelivery,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdating)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.check_circle_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                _isUpdating ? 'جاري الإرسال...' : 'وصلت وسلمت الطلب للعميل',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (order.status == 'delivered_pending') {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.orange.shade800,
            side: BorderSide(color: Colors.orange.shade400),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUpdating
              ? null
              : () async {
                  setState(() => _isUpdating = true);
                  await context.read<OrderProvider>().loadOrders();
                  if (mounted) setState(() => _isUpdating = false);
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdating)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange))
              else
                const Icon(Icons.refresh_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                _isUpdating ? 'جاري الفحص...' : 'بانتظار تأكيد العميل (تحديث)',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Text('حالة الطلب: ${order.status}',
        style: const TextStyle(fontSize: 12, color: Colors.grey));
  }
}

// ════════════════════════════════════════════════════════
// PENDING SETTLEMENT CARD
// ════════════════════════════════════════════════════════
class _PendingSettlementCard extends StatelessWidget {
  final AuthProvider auth;
  final model.User user;
  final void Function(String, bool) onResult;

  const _PendingSettlementCard({
    required this.auth,
    required this.user,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final p = user.pendingSettlement;
    if (p == null) return const SizedBox.shrink();

    final amt = (p['amount'] is num) ? (p['amount'] as num).toDouble() : 0.0;
    final admin = p['requestedByName'] ?? 'الإدارة';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('طلب ترصيد حساب من $admin',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('المبلغ المطلوب: ${amt.toStringAsFixed(0)} ل.س',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60)),
                onPressed: () => auth.respondDriverSettlement(false),
                child: const Text('رفض', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900),
                onPressed: () async {
                  final err = await auth.respondDriverSettlement(true);
                  onResult(err ?? 'تم تأكيد الترصيد بنجاح', err == null);
                },
                child: const Text('تأكيد',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// DRIVER ORDERS HISTORY SCREEN
// ════════════════════════════════════════════════════════
class DriverOrdersHistoryScreen extends StatefulWidget {
  const DriverOrdersHistoryScreen({super.key});

  @override
  State<DriverOrdersHistoryScreen> createState() =>
      _DriverOrdersHistoryScreenState();
}

class _DriverOrdersHistoryScreenState extends State<DriverOrdersHistoryScreen> {
  bool _filterLast20 = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();

    final allOrders = op.orders
        .where((o) => o.driverIdStr == auth.currentUser?.id)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));

    final displayed = _filterLast20 ? allOrders.take(20).toList() : allOrders;
    final totalEarn =
        displayed.fold(0.0, (sum, item) => sum + item.deliveryFee);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات والتصدير')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(
                  selected: _filterLast20,
                  label: const Text('آخر 20 طلب'),
                  onSelected: (_) => setState(() => _filterLast20 = true),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: !_filterLast20,
                  label: Text('الكل (${allOrders.length})'),
                  onSelected: (_) => setState(() => _filterLast20 = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: displayed.isEmpty
                ? const Center(child: Text('لا توجد طلبات في السجل'))
                : ListView.builder(
                    itemCount: displayed.length,
                    itemBuilder: (ctx, idx) {
                      final o = displayed[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                              'طلب #${o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id}'),
                          subtitle: Text(
                              'أجر التوصيل: ${o.deliveryFee.toStringAsFixed(0)} ل.س'),
                          trailing: Chip(
                            label: Text(
                                o.status == 'delivered' ? 'مكتمل' : o.status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            backgroundColor: o.status == 'delivered'
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إجمالي الأرباح (${displayed.length} طلب):',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${totalEarn.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// DRIVER WALLET SCREEN
// ════════════════════════════════════════════════════════
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  bool _isProcessing = false;

  Future<void> _requestSettlement(String type, String title) async {
    final auth = context.read<AuthProvider>();
    setState(() => _isProcessing = true);
    try {
      final err =
          await auth.requestDriverSettlement(auth.currentUser?.id ?? '', type);
      if (!mounted) return;
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب الترصيد بنجاح')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final earnings = user?.driverEarningsWallet ?? 0.0;
    final cash = user?.customerPaymentsWallet ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة والرصيد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Balances
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('أرباح التوصيل',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('${earnings.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade900,
                              minimumSize: const Size(double.infinity, 32),
                            ),
                            onPressed: _isProcessing || earnings <= 0
                                ? null
                                : () => _requestSettlement(
                                    'earnings', 'قبض الأرباح'),
                            child: const Text('قبض',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.orange.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('كاش الزبائن',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('${cash.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange.shade900,
                              minimumSize: const Size(double.infinity, 32),
                            ),
                            onPressed: _isProcessing || cash <= 0
                                ? null
                                : () =>
                                    _requestSettlement('cash', 'تسديد الكاش'),
                            child: const Text('تسديد',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'تفاصيل الأرباح',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, orderProv, _) {
                  final driverOrders = orderProv.orders
                      .where((o) =>
                          o.driverIdStr == user?.id && o.status == 'delivered')
                      .toList();

                  final now = DateTime.now();
                  double todayEarnings = 0;
                  double weekEarnings = 0;

                  for (var o in driverOrders) {
                    final date = o.createdAt ?? DateTime.now();
                    if (date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day) {
                      todayEarnings += o.deliveryFee;
                    }
                    if (now.difference(date).inDays <= 7) {
                      weekEarnings += o.deliveryFee;
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                                title: 'أرباح اليوم', value: todayEarnings),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                                title: 'أرباح الأسبوع', value: weekEarnings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'آخر عمليات التوصيل',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: driverOrders.isEmpty
                            ? const Center(child: Text('لا يوجد طلبات مكتملة'))
                            : ListView.builder(
                                itemCount: driverOrders.length,
                                itemBuilder: (ctx, i) {
                                  final o = driverOrders[i];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      title: Text(
                                          'طلب #${o.id.substring(o.id.length > 6 ? o.id.length - 6 : 0)}'),
                                      subtitle: Text(o.createdAt != null
                                          ? o.createdAt
                                              .toString()
                                              .substring(0, 16)
                                          : ''),
                                      trailing: Text(
                                          '+${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// HELPER UI COMPONENTS
// ════════════════════════════════════════════════════════
class _IconButtonGlass extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _IconButtonGlass({required this.icon, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 20,
              color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String title;
  final double value;

  const _StatBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} ل.س',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: child,
    );
  }
}

class _OnlineToggleChip extends StatelessWidget {
  final bool isOnline;
  final bool isBusy;
  final bool hasActiveOrder;
  final VoidCallback onToggle;
  final VoidCallback onForceUnlock;

  const _OnlineToggleChip({
    required this.isOnline,
    required this.isBusy,
    required this.hasActiveOrder,
    required this.onToggle,
    required this.onForceUnlock,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasActiveOrder
        ? (isOnline ? Colors.green.shade800 : Colors.grey.shade700)
        : (isOnline ? Colors.green.shade600 : Colors.red.shade700);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasActiveOrder ? null : (isBusy ? onForceUnlock : onToggle),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                Icon(
                    isOnline
                        ? Icons.wifi_tethering_rounded
                        : Icons.power_settings_new_rounded,
                    color: Colors.white,
                    size: 18),
              const SizedBox(width: 4),
              Text(
                isBusy ? 'جاري..' : (isOnline ? 'جاهز' : 'متوقف'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapMarkerPin extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;

  const _MapMarkerPin(
      {required this.name, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 48,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(6)),
              child: Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
