// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/providers.dart';
import '../models/models.dart' as model;
import '../core/theme.dart';
import '../core/services.dart';

// ════════════════════════════════════════════════════════
// DRIVER HOME SCREEN
// ════════════════════════════════════════════════════════
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _driverLatLng;
  LatLng? _prevLatLng;
  double _heading = 0;
  bool _followDriver = true;
  Timer? _locationTimer;
  Timer? _animTimer;

  List<LatLng> _routePoints = [];
  double _distKm = 0;
  double _distMin = 0;
  bool _routeLoading = false;
  String? _lastRouteOrderId;
  String? _lastRouteStatus;
  String? _trackedOrderId;

  String? _bannerMsg;
  Color _bannerColor = AppTheme.primary;
  IconData _bannerIcon = Icons.info_outline_rounded;
  Timer? _bannerTimer;

  bool _toggling = false;
  final Set<String> _dismissed = {};
  late AnimationController _pulse;

  static const _activeStatuses = [
    'delivery_accepted',
    'preparing',
    'ready',
    'onTheWay',
    'delivered_pending'
  ];
  static const String _mapTile =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    Future.microtask(() {
      if (!mounted) return;
      final op = context.read<OrderProvider>();
      op.loadOrders();
      op.loadAvailableOrders();
      op.setupSocketListeners();
      op.addListener(_onOrdersChanged);
      context.read<RestaurantProvider>().loadRestaurants();
      final auth = context.read<AuthProvider>();
      _fetchLocation().then((_) {
        if (auth.currentUser?.driverInfo?.availability == true) {
          _startLocationUpdates();
        }
      });
    });
    SocketService.socket?.on('deliveryConfirmed', _onDeliveryConfirmed);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _locationTimer?.cancel();
    _animTimer?.cancel();
    _pulse.dispose();
    try {
      context.read<OrderProvider>().removeListener(_onOrdersChanged);
    } catch (_) {}
    SocketService.socket?.off('deliveryConfirmed', _onDeliveryConfirmed);
    super.dispose();
  }

  void _showBanner(String msg,
      {Color color = AppTheme.primary,
      IconData icon = Icons.info_outline_rounded,
      int sec = 4}) {
    _bannerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _bannerMsg = msg;
      _bannerColor = color;
      _bannerIcon = icon;
    });
    _bannerTimer = Timer(Duration(seconds: sec), () {
      if (mounted) setState(() => _bannerMsg = null);
    });
  }

  void _onOrdersChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final op = context.read<OrderProvider>();
    final uid = auth.currentUser?.id;
    final active = op.orders
        .where(
            (o) => o.driverIdStr == uid && _activeStatuses.contains(o.status))
        .toList();
    if (active.isEmpty && _trackedOrderId != null) {
      final last = _trackedOrderId;
      _trackedOrderId = null;
      final done = op.orders
          .where((o) => o.id == last && o.status == 'delivered')
          .toList();
      if (done.isNotEmpty) {
        _onDeliverySuccess();
        return;
      }
    }
    if (active.isNotEmpty) {
      final o = active.first;
      _trackedOrderId = o.id;
      if ((_lastRouteOrderId != o.id || _lastRouteStatus != o.status) &&
          _driverLatLng != null) {
        _fetchRoute(o);
      }
    } else {
      setState(() {
        _routePoints = [];
        _distKm = 0;
        _distMin = 0;
        _lastRouteOrderId = null;
        _lastRouteStatus = null;
      });
    }
  }

  void _onDeliveryConfirmed(dynamic _) {
    if (mounted) _onDeliverySuccess();
  }

  void _onDeliverySuccess() {
    setState(() {
      _routePoints = [];
      _distKm = 0;
      _distMin = 0;
      _trackedOrderId = null;
      _lastRouteOrderId = null;
      _lastRouteStatus = null;
    });
    _showBanner('تم التوصيل بنجاح! ممتاز يا كابتن.',
        color: Colors.green, icon: Icons.check_circle_rounded, sec: 5);
  }

  Future<void> _fetchLocation() async {
    try {
      final err = await LocationHelper.checkAndRequestPermissions();
      if (err != null || !mounted) return;
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() => _driverLatLng = LatLng(pos.latitude, pos.longitude));
      _onOrdersChanged();
    } catch (_) {}
  }

  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.driverInfo?.availability != true) {
        t.cancel();
        return;
      }
      try {
        final err = await LocationHelper.checkAndRequestPermissions();
        if (err != null || !mounted) return;
        final pos = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(accuracy: LocationAccuracy.high))
            .timeout(const Duration(seconds: 5));
        if (!mounted) return;
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        _animateTo(newLatLng);
        if (_followDriver) {
          try {
            _mapController.move(newLatLng, _mapController.camera.zoom);
          } catch (_) {}
        }
        final uid = auth.currentUser?.id ?? '';
        await ApiService.put('/api/users/$uid/location', {
          'lat': pos.latitude,
          'lng': pos.longitude
        }).timeout(const Duration(seconds: 5));
        final op = context.read<OrderProvider>();
        final active = op.orders
            .where((o) =>
                o.driverIdStr == uid && _activeStatuses.contains(o.status))
            .toList();
        if (active.isNotEmpty && _driverLatLng != null) {
          _fetchRoute(active.first);
        }
      } catch (_) {}
    });
  }

  void _animateTo(LatLng target) {
    final start = _driverLatLng ?? target;
    if (_calcDist(start, target) < 0.005) {
      if (mounted) setState(() => _driverLatLng = target);
      return;
    }
    _animTimer?.cancel();
    final startTime = DateTime.now();
    const dur = Duration(milliseconds: 500);
    _animTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final t = (DateTime.now().difference(startTime).inMilliseconds /
              dur.inMilliseconds)
          .clamp(0.0, 1.0);
      final e = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
      if (!mounted) {
        timer.cancel();
        return;
      }
      final pos = LatLng(
        start.latitude + (target.latitude - start.latitude) * e,
        start.longitude + (target.longitude - start.longitude) * e,
      );
      _heading = _calcBearing(_prevLatLng ?? start, pos);
      _prevLatLng = _driverLatLng;
      setState(() => _driverLatLng = pos);
      if (t >= 1.0) timer.cancel();
    });
  }

  double _calcDist(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final s = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(s), sqrt(1 - s));
  }

  double _calcBearing(LatLng from, LatLng to) {
    final dLng = (to.longitude - from.longitude) * pi / 180;
    final y = sin(dLng) * cos(to.latitude * pi / 180);
    final x = cos(from.latitude * pi / 180) * sin(to.latitude * pi / 180) -
        sin(from.latitude * pi / 180) * cos(to.latitude * pi / 180) * cos(dLng);
    return atan2(y, x) * 180 / pi;
  }

  Future<void> _fetchRoute(model.Order order) async {
    if (_driverLatLng == null) return;
    LatLng? dest;
    final toRest =
        ['delivery_accepted', 'preparing', 'ready'].contains(order.status);
    if (toRest) {
      if (order.restaurantId is Map) {
        final c =
            (order.restaurantId as Map)['address']?['location']?['coordinates'];
        if (c is List && c.length >= 2) {
          dest = LatLng(c[1].toDouble(), c[0].toDouble());
        }
      }
      if (dest == null) {
        final rests = context
            .read<RestaurantProvider>()
            .restaurants
            .where((r) => r.id == order.restaurantIdStr)
            .toList();
        if (rests.isNotEmpty) {
          final coords = rests.first.address?.location?.coordinates;
          if (coords != null && coords.length >= 2) {
            dest = LatLng(coords[1], coords[0]);
          }
        }
      }
    } else {
      final loc = order.deliveryAddress.location;
      if (loc != null && loc.coordinates.length >= 2) {
        dest = LatLng(loc.coordinates[1], loc.coordinates[0]);
      }
    }
    if (dest == null) return;
    if (_lastRouteOrderId == order.id &&
        _lastRouteStatus == order.status &&
        _routePoints.isNotEmpty) {
      if (mounted) setState(() => _distKm = _calcDist(_driverLatLng!, dest!));
      return;
    }
    _lastRouteOrderId = order.id;
    _lastRouteStatus = order.status;
    if (mounted) setState(() => _routeLoading = true);
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${_driverLatLng!.longitude},${_driverLatLng!.latitude};${dest.longitude},${dest.latitude}?overview=full&geometries=geojson';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes']?[0];
        if (route != null) {
          final coords = (route['geometry']['coordinates'] as List)
              .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
          setState(() {
            _routePoints = coords;
            _distKm = (route['distance'] as num) / 1000;
            _distMin = (route['duration'] as num) / 60;
            _routeLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _routeLoading = false);
  }

  Future<void> _toggleAvailability(bool active) async {
    if (_toggling) return;
    final auth = context.read<AuthProvider>();
    final op = context.read<OrderProvider>();
    final uid = auth.currentUser?.id;
    final hasActive = op.orders
        .any((o) => o.driverIdStr == uid && _activeStatuses.contains(o.status));
    if (hasActive && !active) {
      _showBanner('لا يمكنك ايقاف العمل اثناء وجود طلب نشط!',
          color: Colors.red, icon: Icons.warning_amber_rounded);
      return;
    }
    setState(() => _toggling = true);
    try {
      final err = await auth
          .toggleDriverAvailability(active)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (err == null) {
        if (active) {
          _startLocationUpdates();
          unawaited(op.loadAvailableOrders());
          _showBanner('تم تفعيل الاتصال واستقبال الطلبات',
              color: Colors.green, icon: Icons.radar_rounded);
        } else {
          _locationTimer?.cancel();
          _showBanner('تم ايقاف استقبال الطلبات',
              color: Colors.orange, icon: Icons.power_settings_new_rounded);
        }
      } else {
        if (err == 'GPS_DISABLED') {
          _showGpsDialog('خدمات الـ GPS معطلة.');
        } else if (err.startsWith('GPS_DENIED')) {
          _showGpsDialog('صلاحية الموقع معطلة.');
        } else {
          _showBanner(err,
              color: Colors.red, icon: Icons.error_outline_rounded);
        }
      }
    } on TimeoutException {
      if (mounted) {
        _showBanner('انتهت مهلة الاتصال.',
            color: Colors.red, icon: Icons.timer_off_rounded);
      }
    } catch (e) {
      if (mounted) {
        _showBanner('خطا: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _showGpsDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.gps_off_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('مشكلة في الموقع'),
        ]),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('اغلاق')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('فتح الاعدادات'),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(
      List<model.Order> active, bool isAvailable, RestaurantProvider restProv) {
    final markers = <Marker>[];
    if (_driverLatLng != null) {
      markers.add(Marker(
        point: _driverLatLng!,
        width: 68,
        height: 68,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            final scale = 1.0 + _pulse.value * 0.4;
            final opacity = 1.0 - _pulse.value;
            return Stack(alignment: Alignment.center, children: [
              Container(
                width: 52 * scale,
                height: 52 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isAvailable ? Colors.green : Colors.blue)
                      .withValues(alpha: 0.25 * opacity),
                ),
              ),
              Transform.rotate(
                angle: _heading * pi / 180,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8)
                    ],
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ]);
          },
        ),
      ));
    }
    if (active.isEmpty) {
      for (final r in restProv.restaurants) {
        final coords = r.address?.location?.coordinates;
        if (coords == null ||
            coords.length < 2 ||
            (coords[0] == 0.0 && coords[1] == 0.0)) {
          continue;
        }
        markers.add(Marker(
          point: LatLng(coords[1], coords[0]),
          width: 48,
          height: 48,
          child: _RestMarker(name: r.name, color: Colors.red),
        ));
      }
    } else {
      final o = active.first;
      if (['delivery_accepted', 'preparing', 'ready'].contains(o.status)) {
        LatLng? rLatLng;
        if (o.restaurantId is Map) {
          final c =
              (o.restaurantId as Map)['address']?['location']?['coordinates'];
          if (c is List && c.length >= 2) {
            rLatLng = LatLng(c[1].toDouble(), c[0].toDouble());
          }
        }
        if (rLatLng == null) {
          final rests = restProv.restaurants
              .where((r) => r.id == o.restaurantIdStr)
              .toList();
          if (rests.isNotEmpty) {
            final coords = rests.first.address?.location?.coordinates;
            if (coords != null && coords.length >= 2) {
              rLatLng = LatLng(coords[1], coords[0]);
            }
          }
        }
        final restName = o.restaurantId is Map
            ? ((o.restaurantId as Map)['name'] ?? 'المطعم')
            : 'المطعم';
        if (rLatLng != null) {
          markers.add(Marker(
            point: rLatLng,
            width: 48,
            height: 48,
            child: _RestMarker(name: restName, color: Colors.orange.shade800),
          ));
        }
      } else {
        final loc = o.deliveryAddress.location;
        if (loc != null && loc.coordinates.length >= 2) {
          final coords = loc.coordinates;
          markers.add(Marker(
            point: LatLng(coords[1], coords[0]),
            width: 48,
            height: 48,
            child: _RestMarker(
              name: o.deliveryAddress.street ??
                  o.deliveryAddress.city ??
                  'العميل',
              color: Colors.red.shade800,
              icon: Icons.person_pin_circle_rounded,
            ),
          ));
        }
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();
    final restProv = context.watch<RestaurantProvider>();
    final uid = auth.currentUser?.id;
    final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;
    final activeOrders = op.orders
        .where(
            (o) => o.driverIdStr == uid && _activeStatuses.contains(o.status))
        .toList();
    final availableOrders = isAvailable
        ? op.availableOrders.where((o) => !_dismissed.contains(o.id)).toList()
        : <model.Order>[];
    final mapCenter = _driverLatLng ?? const LatLng(33.5138, 36.2765);
    final markers = _buildMarkers(activeOrders, isAvailable, restProv);

    return Scaffold(
      drawer: _buildDrawer(context, auth, op),
      body: Stack(children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 13.0,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _followDriver = false;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _mapTile,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.wassalni.app',
              ),
              if (activeOrders.isNotEmpty && _routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                      points: _routePoints,
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      strokeWidth: 10),
                  Polyline(
                      points: _routePoints,
                      color: AppTheme.primary,
                      strokeWidth: 5),
                ]),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
        if (_routeLoading)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('جاري حساب المسار...', style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Builder(
                  builder: (ctx) => _GlassBtn(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Icon(Icons.menu_rounded,
                        size: 20,
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GlassCard(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      alignment: Alignment.center,
                      child: _buildStatusBar(activeOrders),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _AvailabilityButton(
                  isAvailable: isAvailable,
                  isLoading: _toggling,
                  isDisabled: activeOrders.isNotEmpty,
                  onTap: (activeOrders.isNotEmpty || _toggling)
                      ? null
                      : () => _toggleAvailability(!isAvailable),
                ),
              ]),
            ),
          ),
        ),
        if (_bannerMsg != null)
          Positioned(
            top: 90,
            left: 16,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(14),
              color: _bannerColor.withValues(alpha: 0.95),
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Icon(_bannerIcon, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _bannerMsg!,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                      maxLines: 2,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        Positioned(
          bottom: activeOrders.isNotEmpty ? 260 : 200,
          left: 16,
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _MapBtn(
                heroTag: 'recenter',
                icon: _followDriver
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                color: _followDriver ? Colors.green : AppTheme.primary,
                onPressed: () {
                  setState(() => _followDriver = true);
                  if (_driverLatLng != null) {
                    _mapController.move(_driverLatLng!, 15.5);
                  }
                },
              ),
              if (_routePoints.length >= 2) ...[
                const SizedBox(height: 6),
                _MapBtn(
                  heroTag: 'fitbounds',
                  icon: Icons.fit_screen_rounded,
                  color: AppTheme.secondary,
                  onPressed: () {
                    try {
                      setState(() => _followDriver = false);
                      final bounds = LatLngBounds.fromPoints(_routePoints);
                      _mapController.fitCamera(CameraFit.bounds(
                          bounds: bounds, padding: const EdgeInsets.all(60)));
                    } catch (_) {}
                  },
                ),
              ],
              const SizedBox(height: 6),
              _MapBtn(
                  heroTag: 'zin',
                  icon: Icons.add_rounded,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1)),
              const SizedBox(height: 6),
              _MapBtn(
                  heroTag: 'zout',
                  icon: Icons.remove_rounded,
                  onPressed: () => _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1)),
            ]),
          ),
        ),
        if (auth.currentUser?.pendingSettlement != null)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: _PendingSettlementBanner(
              auth: auth,
              user: auth.currentUser!,
              onResult: (msg, ok) => _showBanner(msg,
                  color: ok ? Colors.green : Colors.red,
                  icon: ok
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded),
            ),
          ),
        if (activeOrders.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _ActiveOrderCard(
              order: activeOrders.first,
              distKm: _distKm,
              onBanner: _showBanner,
              onSuccess: _onDeliverySuccess,
            ),
          )
        else if (isAvailable && availableOrders.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _AvailableOrderCard(
              order: availableOrders.first,
              onDismiss: () =>
                  setState(() => _dismissed.add(availableOrders.first.id)),
              onBanner: _showBanner,
            ),
          ),
      ]),
    );
  }

  Widget _buildStatusBar(List<model.Order> active) {
    if (_bannerMsg != null) {
      return Text(
        _bannerMsg!,
        style: TextStyle(
          color: _bannerColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (active.isEmpty) {
      return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.near_me_rounded, color: AppTheme.primary, size: 16),
        SizedBox(width: 6),
        Text('بانتظار طلب',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ]);
    }
    final o = active.first;
    final toRest =
        ['delivery_accepted', 'preparing', 'ready'].contains(o.status);
    return Row(children: [
      Icon(
        toRest ? Icons.restaurant_rounded : Icons.person_pin_circle_rounded,
        color: toRest ? Colors.orange : Colors.red,
        size: 18,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(toRest ? 'التوجه للمطعم' : 'التوجه للعميل',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            _routeLoading
                ? const Text('جاري المسار...',
                    style: TextStyle(color: Colors.grey, fontSize: 9))
                : Text(
                    '${_distKm.toStringAsFixed(1)} كم - ${_distMin.toStringAsFixed(0)} د',
                    style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
          ],
        ),
      ),
      GestureDetector(
        onTap: () {
          _lastRouteOrderId = null;
          _fetchRoute(o);
        },
        child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.refresh_rounded, color: Colors.green, size: 16)),
      ),
    ]);
  }

  Widget _buildDrawer(
      BuildContext context, AuthProvider auth, OrderProvider op) {
    return Drawer(
      child: Column(children: [
        UserAccountsDrawerHeader(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark])),
          currentAccountPicture: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              auth.currentUser?.name.substring(0, 1).toUpperCase() ?? 'K',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary),
            ),
          ),
          accountName: Text(auth.currentUser?.name ?? 'الكابتن',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          accountEmail: Text(auth.currentUser?.phone ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.table_chart_rounded, color: Colors.blue),
          title: const Text('سجل الطلبات'),
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
          title: const Text('الرصيد والمحفظة'),
          trailing: Chip(
            label: Text('${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DriverWalletScreen()));
          },
        ),
        ListTile(
          leading: const Icon(Icons.person_rounded),
          title: const Text('الملف الشخصي'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('الملف الشخصي'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('الاسم: ${auth.currentUser?.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('البريد: ${auth.currentUser?.email}'),
                  const SizedBox(height: 8),
                  Text('الهاتف: ${auth.currentUser?.phone}'),
                  const SizedBox(height: 8),
                  const Text('نوع الحساب: كابتن توصيل'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('اغلاق'))
                ],
              ),
            );
          },
        ),
        const Spacer(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: Colors.red),
          title: const Text('تسجيل الخروج',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          onTap: () async {
            await auth.logout();
            if (!context.mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
          },
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
// ACTIVE ORDER CARD — owns its own button state
// ════════════════════════════════════════════════════════
class _ActiveOrderCard extends StatefulWidget {
  final model.Order order;
  final double distKm;
  final void Function(String, {Color color, IconData icon, int sec}) onBanner;
  final VoidCallback onSuccess;

  const _ActiveOrderCard(
      {required this.order,
      required this.distKm,
      required this.onBanner,
      required this.onSuccess});

  @override
  State<_ActiveOrderCard> createState() => _ActiveOrderCardState();
}

class _ActiveOrderCardState extends State<_ActiveOrderCard> {
  bool _startingDelivery = false;
  bool _confirmingDelivery = false;
  bool _checkingStatus = false;

  static const _steps = [
    'restaurant_accepted',
    'preparing',
    'ready',
    'delivery_accepted',
    'onTheWay',
    'delivered_pending'
  ];
  static const _stepLabels = ['مطعم', 'تحضير', 'جاهز', 'قبول', 'طريق', 'تاكيد'];

  String _statusLabel(String s) {
    const m = {
      'restaurant_accepted': 'في المطعم',
      'preparing': 'قيد التحضير',
      'ready': 'جاهز للاستلام',
      'delivery_accepted': 'في الطريق',
      'onTheWay': 'توصيل',
      'delivered_pending': 'بانتظار التاكيد'
    };
    return m[s] ?? s;
  }

  Future<void> _startDelivery() async {
    if (_startingDelivery) return;
    setState(() => _startingDelivery = true);
    try {
      final op = context.read<OrderProvider>();
      final err = await op
          .updateStatus(widget.order.id, 'onTheWay')
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (err == null) {
        widget.onBanner('تم استلام الطلب وبدات التوصيل بنجاح',
            color: Colors.green, icon: Icons.directions_bike_rounded);
        await op.loadOrders();
        if (mounted) context.read<AuthProvider>().tryAutoLogin();
      } else {
        widget.onBanner(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } on TimeoutException {
      if (mounted) {
        widget.onBanner('انتهت مهلة الاتصال.',
            color: Colors.red, icon: Icons.timer_off_rounded);
      }
    } catch (e) {
      if (mounted) {
        widget.onBanner('خطا: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _startingDelivery = false);
    }
  }

  Future<void> _confirmDelivery() async {
    if (_confirmingDelivery) return;
    setState(() => _confirmingDelivery = true);
    try {
      final op = context.read<OrderProvider>();
      final err = await op
          .confirmDelivery(widget.order.id)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (err == null) {
        widget.onBanner('تم ارسال طلب التاكيد للعميل. انتظر تاكيده...',
            color: Colors.orange, icon: Icons.send_rounded);
        await op.loadOrders();
      } else {
        widget.onBanner(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } on TimeoutException {
      if (mounted) {
        widget.onBanner('انتهت مهلة الاتصال.',
            color: Colors.red, icon: Icons.timer_off_rounded);
      }
    } catch (e) {
      if (mounted) {
        widget.onBanner('خطا: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _confirmingDelivery = false);
    }
  }

  Future<void> _checkStatus() async {
    if (_checkingStatus) return;
    setState(() => _checkingStatus = true);
    try {
      final op = context.read<OrderProvider>();
      await op.loadOrders().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final updated = op.orders.where((o) => o.id == widget.order.id).toList();
      if (updated.isEmpty || updated.first.status == 'delivered') {
        widget.onSuccess();
      } else {
        widget.onBanner('العميل لم يؤكد بعد. ذكره بالنقر على تاكيد الاستلام.',
            color: Colors.orange, icon: Icons.timer_outlined);
      }
    } on TimeoutException {
      if (mounted) {
        widget.onBanner('انتهت مهلة الاتصال.',
            color: Colors.red, icon: Icons.timer_off_rounded);
      }
    } catch (e) {
      if (mounted) {
        widget.onBanner('خطا: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final stepIdx = _steps.indexOf(order.status);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark]),
          ),
          child: Row(children: [
            const Icon(Icons.delivery_dining_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('طلب #${order.id.substring(order.id.length - 6)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14)),
                    Text(
                        '${_statusLabel(order.status)} - ${order.deliveryFee.toStringAsFixed(0)} ل.س',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11)),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isEven) {
                final idx = i ~/ 2;
                return _StepDot(
                    filled: idx <= stepIdx, label: _stepLabels[idx]);
              }
              final idx = i ~/ 2;
              return _StepLine(filled: idx < stepIdx);
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Icon(Icons.location_on_rounded, size: 14, color: Colors.grey[500]),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${order.deliveryAddress.city ?? ""} - ${order.deliveryAddress.street ?? ""}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _buildActions(order),
        ),
      ]),
    );
  }

  Widget _buildActions(model.Order order) {
    if (['pending', 'restaurant_accepted', 'preparing', 'ready', 'delivery_accepted']
        .contains(order.status)) {
      final isWaiting = order.status != 'delivery_accepted';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (isWaiting ? Colors.blue : Colors.orange)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            isWaiting
                ? 'انتظر حتى يجهز المطعم الطلب'
                : 'استلمت الطلب من المطعم؟ اضغط عند التاكد',
            style: TextStyle(
                color:
                    isWaiting ? Colors.blue.shade800 : Colors.orange.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _startingDelivery ? null : _startDelivery,
            icon: _startingDelivery
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.directions_bike_rounded, size: 22),
            label: Text(
              _startingDelivery
                  ? 'جاري التحديث...'
                  : 'استلمت الطلب - بدات التوصيل',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]);
    }
    if (order.status == 'onTheWay') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (widget.distKm > 0.3) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.social_distance_rounded,
                  color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text('المسافة المتبقية: ${widget.distKm.toStringAsFixed(1)} كم',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: _confirmingDelivery ? null : _confirmDelivery,
            icon: _confirmingDelivery
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded, size: 22),
            label: Text(
              _confirmingDelivery
                  ? 'جاري الارسال...'
                  : 'وصلت وسلمت الطلب للعميل',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]);
    }
    if (order.status == 'delivered_pending') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.orange)),
            SizedBox(width: 10),
            Expanded(
              child: Text('بانتظار تاكيد العميل لاستلام الطلب...',
                  style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade400),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _checkingStatus ? null : _checkStatus,
            icon: _checkingStatus
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange))
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _checkingStatus ? 'جاري التحديث...' : 'تحديث حالة التاكيد',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ]);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        'حالة الطلب: ${order.status}',
        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
// AVAILABLE ORDER CARD — owns its own button state
// ════════════════════════════════════════════════════════
class _AvailableOrderCard extends StatefulWidget {
  final model.Order order;
  final VoidCallback onDismiss;
  final void Function(String, {Color color, IconData icon, int sec}) onBanner;

  const _AvailableOrderCard(
      {required this.order, required this.onDismiss, required this.onBanner});

  @override
  State<_AvailableOrderCard> createState() => _AvailableOrderCardState();
}

class _AvailableOrderCardState extends State<_AvailableOrderCard> {
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      final op = context.read<OrderProvider>();
      final err = await op
          .acceptOrder(widget.order.id)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (err == null) {
        widget.onBanner('تم قبول الطلب! اتبع مسار الخريطة للوصول للمطعم',
            color: Colors.green, icon: Icons.check_circle_rounded);
        await op.loadOrders();
        await op.loadAvailableOrders();
      } else {
        widget.onBanner(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } on TimeoutException {
      if (mounted) {
        widget.onBanner('انتهت مهلة الاتصال.',
            color: Colors.red, icon: Icons.timer_off_rounded);
      }
    } catch (e) {
      if (mounted) {
        widget.onBanner('خطا: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    String restaurantName = 'المطعم';
    if (order.restaurantId is Map) {
      restaurantName = (order.restaurantId as Map)['name'] ?? 'المطعم';
    } else {
      final rests = context
          .read<RestaurantProvider>()
          .restaurants
          .where((r) => r.id == order.restaurantIdStr)
          .toList();
      if (rests.isNotEmpty) restaurantName = rests.first.name;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 18,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.delivery_dining_rounded,
                color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('طلب جديد متاح للتوصيل',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                      'اجر: ${order.deliveryFee.toStringAsFixed(0)} ل.س',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(restaurantName,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        if (order.items.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  order.items
                      .map((it) => '${it.quantity}x ${it.name}')
                      .join(' - '),
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey[400]!),
                  foregroundColor: Colors.grey[700],
                ),
                onPressed: widget.onDismiss,
                child: const Text('تجاهل',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _accepting ? null : _accept,
                icon: _accepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _accepting ? 'جاري القبول...' : 'قبول الطلب',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════
// PENDING SETTLEMENT BANNER
// ════════════════════════════════════════════════════════
class _PendingSettlementBanner extends StatelessWidget {
  final AuthProvider auth;
  final model.User user;
  final void Function(String, bool) onResult;

  const _PendingSettlementBanner(
      {required this.auth, required this.user, required this.onResult});

  @override
  Widget build(BuildContext context) {
    final pending = user.pendingSettlement;
    if (pending == null) return const SizedBox.shrink();
    final typeLabel = pending['settlementType'] == 'cash'
        ? 'تسديد كاش الزبائن'
        : (pending['settlementType'] == 'earnings'
            ? 'صرف ارباح التوصيل'
            : 'تصفير شامل');
    final amount = (pending['amount'] is num)
        ? (pending['amount'] as num).toDouble()
        : (double.tryParse(pending['amount']?.toString() ?? '') ?? 0.0);
    final adminName = pending['requestedByName'] ?? 'الادمن';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade900,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.mark_email_unread_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text('طلب ترصيد من $adminName',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('$typeLabel بمبلغ: ${amount.toStringAsFixed(0)} ل.س',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    visualDensity: VisualDensity.compact),
                onPressed: () async =>
                    await auth.respondDriverSettlement(false),
                child: const Text('رفض', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                    visualDensity: VisualDensity.compact),
                onPressed: () async {
                  final err = await auth.respondDriverSettlement(true);
                  onResult(err ?? 'تم تاكيد الترصيد بنجاح', err == null);
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('تاكيد',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ]),
    );
  }
}

// ════════════════════════════════════════════════════════
// UI PRIMITIVES
// ════════════════════════════════════════════════════════
class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassBtn({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.88),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: child)));
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.88),
      child: child);
}

class _MapBtn extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final Color? color;
  final VoidCallback onPressed;
  const _MapBtn(
      {required this.heroTag,
      required this.icon,
      required this.onPressed,
      this.color});
  @override
  Widget build(BuildContext context) => Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).cardColor,
      child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(icon,
                  size: 20,
                  color:
                      color ?? Theme.of(context).textTheme.bodyLarge?.color))));
}

class _RestMarker extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  const _RestMarker(
      {required this.name, required this.color, this.icon = Icons.restaurant});
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        Icon(icon, color: color, size: 22),
      ]);
}

class _AvailabilityButton extends StatelessWidget {
  final bool isAvailable, isLoading, isDisabled;
  final VoidCallback? onTap;
  const _AvailabilityButton(
      {required this.isAvailable,
      required this.isLoading,
      this.isDisabled = false,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = isDisabled
        ? (isAvailable
            ? Colors.green.shade800.withValues(alpha: 0.55)
            : Colors.grey.shade700)
        : (isAvailable ? Colors.green.shade600 : Colors.red.shade700);
    return Material(
      elevation: isDisabled ? 1 : 3,
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color,
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                        color: (isAvailable ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (isLoading)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
            else
              Icon(
                isDisabled
                    ? Icons.lock_outline_rounded
                    : (isAvailable
                        ? Icons.wifi_tethering_rounded
                        : Icons.power_settings_new_rounded),
                color: Colors.white,
                size: 18,
              ),
            const SizedBox(width: 4),
            Text(isAvailable ? 'جاهز' : 'متوقف',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool filled;
  final String label;
  const _StepDot({required this.filled, required this.label});
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? AppTheme.primary : Colors.grey[300]),
          child: Icon(filled ? Icons.check_rounded : Icons.circle_outlined,
              size: 13, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 7.5,
                color: filled ? AppTheme.primary : Colors.grey[400],
                fontWeight: FontWeight.bold)),
      ]);
}

class _StepLine extends StatelessWidget {
  final bool filled;
  const _StepLine({required this.filled});
  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
          decoration: BoxDecoration(
              color: filled ? AppTheme.primary : Colors.grey[300],
              borderRadius: BorderRadius.circular(2))));
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
  bool _showLast20 = true;

  void _exportToExcel(List<model.Order> orders) {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد طلبات لتصديرها')));
      return;
    }
    final sb = StringBuffer()
      ..write('\uFEFF')
      ..writeln(
          'رقم الطلب,التاريخ,المطعم,اجر التوصيل,اجمالي الطلب,طريقة الدفع,الحالة');
    for (var o in orders) {
      final idStr = o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;
      final dateStr = o.createdAt != null
          ? '${o.createdAt!.year}-${o.createdAt!.month.toString().padLeft(2, "0")}-${o.createdAt!.day.toString().padLeft(2, "0")} ${o.createdAt!.hour.toString().padLeft(2, "0")}:${o.createdAt!.minute.toString().padLeft(2, "0")}'
          : '--';
      final restName = o.restaurantId is Map
          ? ((o.restaurantId as Map)['name'] ?? 'مطعم')
          : 'مطعم';
      final payMethod = o.paymentMethod == 'wallet' ? 'محفظة' : 'كاش';
      final statusStr = o.status == 'delivered'
          ? 'مكتمل'
          : (o.status == 'cancelled' ? 'ملغى' : o.status);
      sb.writeln(
          '"$idStr","$dateStr","$restName",${o.deliveryFee.toStringAsFixed(0)},${o.totalAmount.toStringAsFixed(0)},"$payMethod","$statusStr"');
    }
    final csvText = sb.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.table_chart_rounded, color: Colors.green, size: 26),
          SizedBox(width: 10),
          Text('تصدير Excel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.green.withValues(alpha: 0.3))),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('تم اعداد ملف Excel لعدد ${orders.length} طلب.',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.grey.withValues(alpha: 0.2))),
                child: SingleChildScrollView(
                    child: SelectableText(csvText,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 10))),
              ),
            ]),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ البيانات للحافظة')));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('نسخ'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير البيانات!')));
            },
            icon: const Icon(Icons.download_done_rounded, size: 16),
            label: const Text('حفظ وخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();
    final all =
        op.orders.where((o) => o.driverIdStr == auth.currentUser?.id).toList()
          ..sort((a, b) {
            if (a.createdAt != null && b.createdAt != null) {
              return b.createdAt!.compareTo(a.createdAt!);
            }
            return 0;
          });
    final displayed = _showLast20 ? all.take(20).toList() : all;
    final totalFees = displayed.fold(0.0, (s, o) => s + o.deliveryFee);
    final totalAmount = displayed.fold(0.0, (s, o) => s + o.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات كجدول'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => op.loadOrders())
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration:
              BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
          child: Row(children: [
            FilterChip(
              selected: _showLast20,
              label: const Text('اخر 20 طلب'),
              onSelected: (_) => setState(() => _showLast20 = true),
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: !_showLast20,
              label: Text('الكل (${all.length})'),
              onSelected: (_) => setState(() => _showLast20 = false),
              selectedColor: AppTheme.primary.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.primary,
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => _exportToExcel(displayed),
              icon: const Icon(Icons.table_chart_rounded, size: 16),
              label: const Text('تصدير Excel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Expanded(
          child: displayed.isEmpty
              ? const Center(child: Text('لا توجد طلبات سابقة'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          AppTheme.primary.withValues(alpha: 0.1)),
                      columns: const [
                        DataColumn(
                            label: Text('رقم الطلب',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('التاريخ',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('المطعم',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('اجر التوصيل',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('اجمالي الطلب',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('الدفع',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('الحالة',
                                style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: List.generate(displayed.length, (idx) {
                        final o = displayed[idx];
                        final idStr = o.id.length > 6
                            ? o.id.substring(o.id.length - 6)
                            : o.id;
                        final dateStr = o.createdAt != null
                            ? '${o.createdAt!.day}/${o.createdAt!.month} ${o.createdAt!.hour}:${o.createdAt!.minute.toString().padLeft(2, "0")}'
                            : '--';
                        final restName = o.restaurantId is Map
                            ? ((o.restaurantId as Map)['name'] ?? 'مطعم')
                            : 'مطعم';
                        final isDelivered = o.status == 'delivered';
                        return DataRow(
                          color: WidgetStateProperty.all(idx % 2 == 0
                              ? Theme.of(context).cardColor
                              : Theme.of(context)
                                  .cardColor
                                  .withValues(alpha: 0.5)),
                          cells: [
                            DataCell(Text('#$idStr',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                            DataCell(Text(dateStr,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(restName,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                                '${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green))),
                            DataCell(Text(
                                '${o.totalAmount.toStringAsFixed(0)} ل.س')),
                            DataCell(Chip(
                              label: Text(
                                  o.paymentMethod == 'wallet' ? 'محفظة' : 'كاش',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)),
                              backgroundColor: o.paymentMethod == 'wallet'
                                  ? Colors.purple
                                  : Colors.orange,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color:
                                      (isDelivered ? Colors.green : Colors.red)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(isDelivered ? 'مكتمل' : 'ملغى',
                                  style: TextStyle(
                                      color: isDelivered
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            )),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              border: Border(
                  top: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2)))),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('المجموع (${displayed.length} طلب):',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Row(children: [
              const Text('ارباح: ', style: TextStyle(fontSize: 12)),
              Text('${totalFees.toStringAsFixed(0)} ل.س',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green.shade700)),
              const SizedBox(width: 14),
              const Text('مبيعات: ', style: TextStyle(fontSize: 12)),
              Text('${totalAmount.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primary)),
            ]),
          ]),
        ),
      ]),
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
  bool _settling = false;

  Future<void> _settle(
      AuthProvider auth, String type, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('الغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: type == 'cash'
                    ? Colors.orange.shade800
                    : Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('تاكيد'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _settling = true);
    try {
      final err =
          await auth.requestDriverSettlement(auth.currentUser?.id ?? '', type);
      if (!mounted) return;
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم ارسال طلب الترصيد بنجاح'),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _settling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();
    final driver = auth.currentUser;
    final custPay = driver?.customerPaymentsWallet ?? 0.0;
    final driverEarn = driver?.driverEarningsWallet ?? 0.0;
    final driverOrders = op.orders
        .where((o) => o.driverIdStr == driver?.id && o.status == 'delivered')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرصيد والمحفظة'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => op.loadOrders())
        ],
      ),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.stars_rounded,
                                color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                                child: Text('ارباح التوصيل',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold))),
                          ]),
                          const SizedBox(height: 6),
                          Text('${driverEarn.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.green.shade800,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: driverEarn <= 0
                                  ? null
                                  : () => _settle(
                                      auth,
                                      'earnings',
                                      'قبض الارباح',
                                      'هل تم قبض ارباح التوصيل (${driverEarn.toStringAsFixed(0)} ل.س) من المحاسب؟'),
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 14),
                              label: const Text('قبض وتصفير',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFFE65100), Color(0xFFBF360C)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ]),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.payments_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                                child: Text('كاش الزبائن',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold))),
                          ]),
                          const SizedBox(height: 6),
                          Text('${custPay.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.deepOrange.shade900,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              onPressed: custPay <= 0
                                  ? null
                                  : () => _settle(auth, 'cash', 'تسديد الكاش',
                                      'هل تم تسليم كاش الزبائن (${custPay.toStringAsFixed(0)} ل.س) للمحاسب؟'),
                              icon: const Icon(Icons.outbox_rounded, size: 14),
                              label: const Text('تسديد وتصفير',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]),
                  ),
                ),
              ]),
              if (custPay > 0 && driverEarn > 0) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(
                          color: AppTheme.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () => _settle(auth, 'both', 'ترصيد الخزينتين',
                      'هل تم التسوية الشاملة (كاش: ${custPay.toStringAsFixed(0)} + ارباح: ${driverEarn.toStringAsFixed(0)} ل.س)؟'),
                  icon: const Icon(Icons.published_with_changes_rounded,
                      size: 16),
                  label: const Text('تصفير الخزينتين معا',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('سجل الطلبات المكتملة:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: driverOrders.isEmpty
                ? const Center(child: Text('لا توجد طلبات مكتملة'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppTheme.primary.withValues(alpha: 0.1)),
                        columns: const [
                          DataColumn(
                              label: Text('رقم الطلب',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('التاريخ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('ارباحك (+)',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('كاش الزبون',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('طريقة الدفع',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('الحالة',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: List.generate(driverOrders.length, (idx) {
                          final o = driverOrders[idx];
                          final idStr = o.id.length > 6
                              ? o.id.substring(o.id.length - 6)
                              : o.id;
                          final dateStr = o.createdAt != null
                              ? '${o.createdAt!.day}/${o.createdAt!.month} ${o.createdAt!.hour}:${o.createdAt!.minute.toString().padLeft(2, "0")}'
                              : '--';
                          final isCash = o.paymentMethod == 'cash';
                          final cashReceived =
                              isCash ? (o.totalAmount + o.deliveryFee) : 0.0;
                          return DataRow(cells: [
                            DataCell(Text('#$idStr',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                            DataCell(Text(dateStr,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(
                                '+${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green))),
                            DataCell(Text(
                                '${cashReceived.toStringAsFixed(0)} ل.س',
                                style: TextStyle(
                                    color: isCash
                                        ? Colors.orange.shade900
                                        : Colors.grey,
                                    fontWeight: isCash
                                        ? FontWeight.bold
                                        : FontWeight.normal))),
                            DataCell(Chip(
                              label: Text(isCash ? 'كاش' : 'محفظة',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white)),
                              backgroundColor:
                                  isCash ? Colors.orange : Colors.purple,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            )),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text('مكتمل',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                            )),
                          ]);
                        }),
                      ),
                    ),
                  ),
          ),
        ]),
        if (_settling)
          Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
