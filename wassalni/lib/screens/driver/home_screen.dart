import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../providers/providers.dart';
import '../../models/models.dart' as model;
import '../../core/theme.dart';
import '../../core/services.dart';

import 'driver_widgets.dart';
import 'driver_drawer.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// 🚴‍♂️ الشاشة الرئيسية لعامل التوصيل (Driver Home Screen)
/// ════════════════════════════════════════════════════════════════════════════
/// تحتوي هذه الشاشة على الخريطة التفاعلية الحية، تتبع موقع الـ GPS المباشر،
/// شريط الحالة العلوية، إشارات التحديث الحية، وبطاقات التوصيل والقبول السريع.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  /// متحكم الخريطة لتنفيذ عمليات التكبير والتصغير وتغيير المركز
  final MapController _map = MapController();
  
  /// موقع الكابتن الحالي على الخريطة (خط العرض وخط الطول)
  LatLng? _currentPos;
  
  /// اتجاه حركة الكابتن بالدرجات
  final double _heading = 0;
  
  /// هل الخريطة تتبع موقع الكابتن تلقائياً عند الحركة
  bool _followMap = true;
  
  /// مؤقت دوري لإرسال تحديثات الموقع المباشر إلى الخادم
  Timer? _posTimer;

  /// مسار التوصيل المباشر (نقاط Polyline، المسافة والزمن)
  List<LatLng> _polyPoints = [];
  double _routeDistKm = 0;
  double _routeDurationMin = 0;
  bool _isRouteFetching = false;
  String? _activeOrderId;

  /// شريط التنبيهات المنبثق العلوي (Notification Banner)
  String? _bannerMsg;
  Color _bannerBg = AppTheme.primary;
  IconData _bannerIcon = Icons.info_outline;
  Timer? _bannerTimer;

  /// سجلات التشخيص ونظام القفل وحماية الأزرار
  bool _isToggling = false;
  final List<String> _diagLogs = [];
  bool _showDiagPanel = false;
  Timer? _safetyUnlockTimer;

  /// أنيميشن النبض الحية لأيقونة الرادار عند التواجد أونلاين
  late AnimationController _pulseAnim;

  /// قائمة الحالات الجارية التي تُعتبر طلباً نشطاً للكابتن
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
    // تهيئة أنيميشن النبض وتكرارها
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // تحميل الطلبات والمطاعم وإعداد مستمعي السوكت فور بدء الشاشة
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

    // المستمع الخاص بتأكيد التسليم الناجح للطلب
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

  /// إضافة خطوة تشخيصية جديدة إلى شاشة الفحص الحي
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

  /// إظهار شريط تنبيه ملون أعلى الشاشة لفترة محددة
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

  /// 📍 تهيئة وفحص الموقع الأولي عبر الـ GPS
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

  /// 🔄 بدء تتبع ومزامنة الموقع المباشر دورياً كل 10 ثوانٍ
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

  /// 📦 معالجة تحديثات الطلبات وتحديد مسار التوصيل المباشر
  void _handleOrderUpdates() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final op = context.read<OrderProvider>();
    final uid = auth.currentUser?.id;

    final active = op.orders
        .where(
            (o) => o.driverIdStr == uid && _activeStatusList.contains(o.status))
        .toList();

    if (active.isEmpty) {
      if (_polyPoints.isNotEmpty) {
        setState(() {
          _polyPoints = [];
          _routeDistKm = 0;
          _routeDurationMin = 0;
          _activeOrderId = null;
        });
      }
      return;
    }

    final o = active.first;
    if (o.id == _activeOrderId && _polyPoints.isNotEmpty) return;
    _activeOrderId = o.id;

    LatLng? dest;
    final isHeadingToRest =
        ['delivery_accepted', 'preparing', 'ready'].contains(o.status);

    if (isHeadingToRest) {
      if (o.restaurantId is Map) {
        final c =
            (o.restaurantId as Map)['address']?['location']?['coordinates'];
        if (c is List && c.length >= 2) {
          dest = LatLng(c[1].toDouble(), c[0].toDouble());
        }
      }
    } else {
      final loc = o.deliveryAddress.location;
      if (loc != null && loc.coordinates.length >= 2) {
        dest = LatLng(loc.coordinates[1], loc.coordinates[0]);
      }
    }

    if (dest != null && _currentPos != null) {
      _fetchRouteOSRM(dest);
    }
  }

  /// 🗺️ حساب ورسم المسار الحي عبر خدمة OSRM المفتوحة
  Future<void> _fetchRouteOSRM(LatLng destination) async {
    if (_currentPos == null || _isRouteFetching) return;
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

  /// 🔘 تفعيل أو إيقاف استقبال الطلبات (حالة جاهز / متوقف)
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

    // إظهار لوحة التشخيص وتأمين الزر
    setState(() {
      _showDiagPanel = true;
    });

    // تحرير قفل الضغط السريع
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
    }
  }

  /// 🎉 معالجة وصول إشعار تأكيد التسليم بنجاح من العميل
  void _handleDeliverySuccess(dynamic data) {
    if (!mounted) return;
    _notify(
      '🎉 تم تأكيد استلام الطلب من قِبل العميل وتفريغ الأرباح لمفهوم محفظتك!',
      color: Colors.green,
      icon: Icons.check_circle_rounded,
      sec: 6,
    );
    context.read<AuthProvider>().tryAutoLogin();
    context.read<OrderProvider>().loadOrders();
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
      drawer: const DriverAppDrawer(),
      body: Stack(
        children: [
          // 🗺️ الخريطة التفاعلية الحية
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
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _polyPoints,
                        strokeWidth: 5.0,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: _buildMapMarkers(activeOrders, isOnline, restProv),
                ),
              ],
            ),
          ),

          // 🔔 شريط التنبيه المنبثق العلوي
          if (_bannerMsg != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 14,
              right: 14,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: _bannerBg,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_bannerIcon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _bannerMsg!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 🔝 الشريط العلوي للتحكم بالجاهزية والقائمة الجانبية
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 14,
            right: 14,
            child: Builder(
              builder: (drawerCtx) => GlassPanel(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      IconButtonGlass(
                        icon: Icons.menu_rounded,
                        onTap: () => Scaffold.of(drawerCtx).openDrawer(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            child: _buildHeaderStatusText(activeOrders),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OnlineToggleChip(
                        isOnline: isOnline,
                        isBusy: _isToggling,
                        hasActiveOrder: activeOrders.isNotEmpty,
                        onToggle: () => _toggleAvailability(!isOnline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🛠️ لوحة الفحص والتشخيص الحي المباشر
          if (_showDiagPanel && _diagLogs.isNotEmpty)
            Positioned(
              top: 85,
              left: 14,
              right: 14,
              child: DiagnosticPanel(
                logs: _diagLogs,
                isBusy: _isToggling,
                onClose: () => setState(() => _showDiagPanel = false),
                onForceUnlock: () {
                  setState(() => _isToggling = false);
                  _addDiag('🔓 تم إلغاء القفل يدويًا!');
                },
              ),
            ),

          // ⚙️ أزرار التحكم الجانبية على الخريطة
          Positioned(
            right: 14,
            bottom: activeOrders.isNotEmpty ||
                    (isOnline && op.availableOrders.isNotEmpty)
                ? 210
                : 130,
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButtonGlass(
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
                    IconButtonGlass(
                      icon: Icons.add_rounded,
                      onTap: () =>
                          _map.move(_map.camera.center, _map.camera.zoom + 1),
                    ),
                    const SizedBox(height: 6),
                    IconButtonGlass(
                      icon: Icons.remove_rounded,
                      onTap: () =>
                          _map.move(_map.camera.center, _map.camera.zoom - 1),
                    ),
                    const SizedBox(height: 6),
                    IconButtonGlass(
                      icon: Icons.bug_report_outlined,
                      color: Colors.amber.shade800,
                      onTap: () =>
                          setState(() => _showDiagPanel = !_showDiagPanel),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ⚠️ بطاقة التسوية المعلقة
          if (auth.currentUser?.pendingSettlement != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: PendingSettlementCard(
                auth: auth,
                user: auth.currentUser!,
                onResult: (msg, ok) => _notify(msg,
                    color: ok ? Colors.green : Colors.red,
                    icon: ok ? Icons.check_circle : Icons.error),
              ),
            ),

          // ⬇️ البطاقات السفلية للطلبات (طلب نشط / طلبات متاحة / بطاقة انتظار)
          if (activeOrders.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: ActiveOrderCardSheet(
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
              child: AvailableOrdersSheet(
                availableOrders: op.availableOrders,
                onNotify: _notify,
              ),
            )
          else
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: WaitingForOrdersCard(
                isOnline: isOnline,
                pulseAnim: _pulseAnim,
              ),
            ),
        ],
      ),
    );
  }

  /// بناء نص ترويسة الحالة العلوية (المسار إلى المطعم / المسار إلى العميل)
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

  /// بناء دبابيس ومؤشرات الخريطة (موقع الكابتن الحي + دبوس المطعم / دبوس العميل)
  List<Marker> _buildMapMarkers(
      List<model.Order> active, bool isOnline, RestaurantProvider restProv) {
    final list = <Marker>[];

    // مؤشر موقع الكابتن الحالي
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

    // مؤشر الوجهة (المطعم أو العميل)
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
            child: const MapMarkerPin(
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
            child: const MapMarkerPin(
                name: 'العميل',
                icon: Icons.person_pin_circle_rounded,
                color: Colors.red),
          ));
        }
      }
    }

    return list;
  }
}
