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

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  _DriverHomeScreenState createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with SingleTickerProviderStateMixin {
  LatLng? _driverLatLng;
  LatLng? _previousDriverLatLng;
  double _driverHeading = 0;
  bool _isDialogShowing = false;
  Timer? _driverLocationTimer;
  Timer? _orderSearchTimer;
  Timer? _driverAnimationTimer;
  bool _followDriver = true;
  bool _isTogglingAvailability = false;
  bool _isUpdatingStatus = false;
  late AnimationController _pulseController;

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  double _durationMin = 0.0;
  bool _isLoadingRoute = false;
  String? _lastRoutedOrderId;
  String? _lastRoutedOrderStatus;
  bool _hasAutoZoomedProximity = false;
  final MapController _mapController = MapController();

  String? _topNotificationMessage;
  Color? _topNotificationColor;
  IconData? _topNotificationIcon;
  Timer? _topNotificationTimer;

  void _showTopNotification(
    String message, {
    Color color = AppTheme.primary,
    IconData icon = Icons.info_outline_rounded,
    int durationSeconds = 4,
  }) {
    _topNotificationTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _topNotificationMessage = message;
      _topNotificationColor = color;
      _topNotificationIcon = icon;
    });

    _topNotificationTimer = Timer(Duration(seconds: durationSeconds), () {
      if (mounted) {
        setState(() {
          _topNotificationMessage = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    Future.microtask(() {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders();
      orderProv.loadAvailableOrders();
      orderProv.setupSocketListeners();
      orderProv.addListener(_onOrderProviderChange);
      Provider.of<RestaurantProvider>(context, listen: false).loadRestaurants();

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;
      _fetchCurrentLocation().then((_) {
        if (isAvailable) {
          _startDriverLocationUpdates();
          _startOrderSearchTimer();
        }
      });
    });

    SocketService.socket?.on(
      'deliveryConfirmed',
      _onDeliveryConfirmedByCustomer,
    );
  }

  String? _currentlyTrackedOrderId;

  void _onDeliveryConfirmedByCustomer(dynamic data) {
    if (!mounted) return;
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    orderProv.loadOrders().then((_) {
      if (!mounted) return;
      _triggerDeliveryConfirmedSuccess();
    });
  }

  void _triggerDeliveryConfirmedSuccess() {
    if (!mounted || _isDialogShowing) return;
    _isDialogShowing = true;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.tryAutoLogin(); // Update driver balances immediately

    setState(() {
      _routePoints.clear();
      _distanceKm = 0.0;
      _durationMin = 0.0;
      _lastRoutedOrderId = null;
      _lastRoutedOrderStatus = null;
      _currentlyTrackedOrderId = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isDialogShowing = false;
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('تم تأكيد التوصيل!'),
          content: const Text(
            'قام العميل بتأكيد استلام الطلب بنجاح وتم تسوية المبالغ المالية بأرباحك ومحفظتك.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _isDialogShowing = false;
                Navigator.pop(ctx);
              },
              child: const Text('حسناً'),
            ),
          ],
        ),
      ).then((_) {
        _isDialogShowing = false;
      });
    });
  }

  void _startDriverLocationUpdates() {
    _driverLocationTimer?.cancel();
    _driverLocationTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;
      if (!isAvailable) {
        timer.cancel();
        return;
      }
      await _fetchCurrentLocation();
    });
  }

  bool _isSearchingOrders = false;

  void _startOrderSearchTimer() {
    _orderSearchTimer?.cancel();
    _orderSearchTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isSearchingOrders) return;

      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;
      if (!isAvailable) {
        timer.cancel();
        return;
      }

      // Check if driver has active order already
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final driverId = auth.currentUser?.id;
      final hasActive = orderProv.orders.any((o) =>
          o.driverIdStr == driverId &&
          [
            'delivery_accepted',
            'preparing',
            'ready',
            'onTheWay',
            'delivered_pending'
          ].contains(o.status));
      if (hasActive) return; // Don't search when already delivering

      _isSearchingOrders = true;
      try {
        await orderProv.loadAvailableOrders();
      } catch (_) {
      } finally {
        _isSearchingOrders = false;
      }
    });
  }

  void _stopOrderSearchTimer() {
    _orderSearchTimer?.cancel();
    _orderSearchTimer = null;
  }

  Future<void> _fetchCurrentLocation({bool fetchRoute = true}) async {
    try {
      final err = await LocationHelper.checkAndRequestPermissions();
      if (err != null) return;

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return;

      if (mounted) {
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        _animateDriverTo(newLatLng);

        if (_followDriver) {
          try {
            _mapController.move(newLatLng, _mapController.camera.zoom);
          } catch (_) {}
        }

        if (fetchRoute) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final orderProv = Provider.of<OrderProvider>(context, listen: false);
          final activeOrders = orderProv.orders
              .where(
                (o) =>
                    o.driverIdStr == auth.currentUser?.id &&
                    [
                      'delivery_accepted',
                      'preparing',
                      'ready',
                      'onTheWay',
                      'delivered_pending',
                    ].contains(o.status),
              )
              .toList();

          if (activeOrders.isNotEmpty) {
            final activeOrder = activeOrders.first;
            SocketService.joinOrderRoom(activeOrder.id);
            SocketService.socket?.emit('driverLocationUpdate', {
              'orderId': activeOrder.id,
              'location': {
                'lat': pos.latitude,
                'lng': pos.longitude,
              },
            });
            _fetchRouteForOrder(activeOrder);
          }
        }
      }
    } catch (e) {
      debugPrint('Fetch driver location error: $e');
    }
  }

  @override
  void dispose() {
    _topNotificationTimer?.cancel();
    _driverLocationTimer?.cancel();
    _orderSearchTimer?.cancel();
    _driverAnimationTimer?.cancel();
    _pulseController.dispose();
    try {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.removeListener(_onOrderProviderChange);
    } catch (_) {}
    SocketService.socket?.off(
      'deliveryConfirmed',
      _onDeliveryConfirmedByCustomer,
    );
    super.dispose();
  }

  final Set<String> _dismissedOrderIds = {};
  DateTime _lastOfferShownAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onOrderProviderChange() {
    if (!mounted || _isDialogShowing) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final driverId = auth.currentUser?.id;

    final activeOrders = orderProv.orders
        .where(
          (o) =>
              o.driverIdStr == driverId &&
              [
                'delivery_accepted',
                'preparing',
                'ready',
                'onTheWay',
                'delivered_pending',
              ].contains(o.status),
        )
        .toList();

    if (activeOrders.isNotEmpty) {
      final activeOrder = activeOrders.first;
      _currentlyTrackedOrderId = activeOrder.id;
      SocketService.joinOrderRoom(activeOrder.id);

      // Ensure location updates are active when delivering
      if (_driverLocationTimer == null || !_driverLocationTimer!.isActive) {
        _startDriverLocationUpdates();
      }

      _fetchRouteForOrder(activeOrder);
    } else {
      // If we were previously tracking an active delivery and activeOrders is now empty:
      if (_currentlyTrackedOrderId != null) {
        final lastId = _currentlyTrackedOrderId;
        _currentlyTrackedOrderId = null;
        final completed = orderProv.orders
            .where((o) => o.id == lastId && o.status == 'delivered')
            .toList();
        if (completed.isNotEmpty) {
          _triggerDeliveryConfirmedSuccess();
          return;
        }
      }

      // Clear polyline route if no active order is left
      if (_routePoints.isNotEmpty) {
        setState(() {
          _routePoints.clear();
          _distanceKm = 0.0;
          _durationMin = 0.0;
          _lastRoutedOrderId = null;
          _lastRoutedOrderStatus = null;
        });
      }

      // Only offer new orders if driver is available and has NO active delivery
      if (auth.currentUser?.driverInfo?.availability == true) {
        final availableOrders = orderProv.availableOrders
            .where((o) => !_dismissedOrderIds.contains(o.id))
            .toList();

        if (availableOrders.isNotEmpty &&
            !_isDialogShowing &&
            DateTime.now().difference(_lastOfferShownAt).inSeconds >= 10) {
          _showOrderOfferDialog(availableOrders.first);
        }
      }
    }
  }

  void _showOrderOfferDialog(model.Order order) {
    if (!mounted || _isDialogShowing) return;

    _isDialogShowing = true;
    _lastOfferShownAt = DateTime.now();
    _dismissedOrderIds.add(order.id);

    // Defer the route push to the next frame. Pushing a modal route while a
    // touch event is still being dispatched (notifyListeners -> listener)
    // crashes hit testing with "Cannot hit test a render box with no size"
    // and freezes every touch on the driver screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isDialogShowing = false;
        return;
      }
      try {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: true,
          enableDrag: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 150,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delivery_dining_rounded,
                                color: AppTheme.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('طلب جديد قريب منك',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                    'أجر التوصيل: ${order.deliveryFee.toStringAsFixed(0)} ل.س',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('2.5 كم',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700])),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تفاصيل الطلب:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 6),
                            ...order.items.map((it) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                        child: Text('×${it.quantity}',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                                fontSize: 11)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(it.name,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.grey[300]
                                                      : Colors.grey[700]))),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                side: BorderSide(color: Colors.red[300]!),
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                final orderProv = Provider.of<OrderProvider>(
                                    context,
                                    listen: false);
                                orderProv.rejectOrder(order.id);
                              },
                              child: const Text('رفض',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _acceptOrder(order.id);
                              },
                              child: const Text('قبول',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ).then((_) {
          _isDialogShowing = false;
        }).catchError((_) {
          _isDialogShowing = false;
        });
      } catch (_) {
        _isDialogShowing = false;
      }
    });
  }

  Future<void> _acceptOrder(String orderId) async {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final err = await orderProv.acceptOrder(orderId);
    if (!mounted) return;
    if (err == null) {
      _showTopNotification(
        'تم قبول الطلب! اتبع مسار الخريطة للوصول للمطعم',
        color: Colors.green,
        icon: Icons.check_circle_rounded,
      );
      await orderProv.loadOrders();
      await orderProv.loadAvailableOrders();
    } else {
      _showTopNotification(err,
          color: Colors.red, icon: Icons.error_outline_rounded);
    }
  }

  void _showProfileDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.orange),
            SizedBox(width: 8),
            Text('الملف الشخصي للكابتن'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الاسم: ${auth.currentUser?.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('البريد الإلكتروني: ${auth.currentUser?.email}'),
            const SizedBox(height: 8),
            Text('الهاتف: ${auth.currentUser?.phone}'),
            const SizedBox(height: 8),
            Text('نوع الحساب: كابتن توصيل'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider auth,
    bool isAvailable,
    OrderProvider orderProv,
  ) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: AppTheme.primaryGradient(),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                auth.currentUser?.name.substring(0, 1).toUpperCase() ?? 'K',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            accountName: Text(
              auth.currentUser?.name ?? 'الكابتن',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              auth.currentUser?.phone ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_rounded, color: Colors.blue),
            title: const Text('الطلبات السابقة (جدول وتصدير)'),
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
            leading: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.green,
            ),
            title: const Text('الرصيد والمحفظة (جدول كشف)'),
            trailing: Chip(
              label: Text(
                '${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          ListTile(
            leading: const Icon(Icons.person, color: Colors.orange),
            title: const Text('الملف الشخصي'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(context);
              _showProfileDialog(context, auth);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await auth.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _toggleAvailability(AuthProvider auth, bool active) async {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final driverId = auth.currentUser?.id;
    final hasActiveOrder = orderProv.orders.any((o) =>
        o.driverIdStr == driverId &&
        [
          'delivery_accepted',
          'preparing',
          'ready',
          'onTheWay',
          'delivered_pending'
        ].contains(o.status));

    if (hasActiveOrder && !active) {
      _showTopNotification(
        'لا يمكنك إيقاف العمل أثناء وجود طلب نشط قيد التوصيل!',
        color: Colors.red,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    final err = await auth.toggleDriverAvailability(active);
    if (!mounted) return;
    if (err == null) {
      if (active) {
        _startDriverLocationUpdates();
        _startOrderSearchTimer();
        Provider.of<OrderProvider>(
          context,
          listen: false,
        ).loadAvailableOrders();
      } else {
        _driverLocationTimer?.cancel();
        _stopOrderSearchTimer();
      }
      _showTopNotification(
        active
            ? 'تم تفعيل الاتصال واستقبال الطلبات'
            : 'تم إيقاف استقبال الطلبات',
        color: active ? Colors.green : Colors.orange,
        icon: active ? Icons.radar_rounded : Icons.power_settings_new_rounded,
      );
    } else {
      if (err == 'GPS_DISABLED') {
        _showGpsDialog(
          'خدمات الـ GPS معطلة. يرجى تفعيل الـ GPS لتتمكن من استقبال الطلبات.',
        );
      } else if (err == 'GPS_DENIED' || err == 'GPS_DENIED_FOREVER') {
        _showGpsDialog(
          'صلاحية الوصول للموقع معطلة. يرجى إعطاء صلاحية الموقع للتطبيق.',
        );
      } else {
        _showTopNotification(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    }
  }

  void _showGpsDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تفعيل GPS إجباري'),
        content: Text(msg),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(
    OrderProvider orderProv,
    String id,
    String status,
  ) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final err = await orderProv.updateStatus(id, status);
      if (!mounted) return;
      if (err == null) {
        _showTopNotification(
          status == 'onTheWay'
              ? 'تم استلام الطلب وبدء التوصيل (في الطريق) بنجاح'
              : 'تم تحديث حالة الطلب',
          color: Colors.green,
          icon: Icons.check_circle_rounded,
        );
        await orderProv.loadOrders();
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).tryAutoLogin();
        }
      } else {
        _showTopNotification(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } catch (e) {
      if (mounted) {
        _showTopNotification('خطأ أثناء تحديث حالة الطلب: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _confirmDelivery(String orderId) async {
    if (_isUpdatingStatus) return;
    setState(() => _isUpdatingStatus = true);

    try {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final err = await orderProv.confirmDelivery(orderId);
      if (!mounted) return;
      if (err == null) {
        _showTopNotification(
          'تم إرسال طلب تأكيد الاستلام للعميل. يرجى الانتظار لتأكيد المعاملة.',
          color: Colors.orange,
          icon: Icons.send_rounded,
        );
        await orderProv.loadOrders();
      } else {
        _showTopNotification(err,
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } catch (e) {
      if (mounted) {
        _showTopNotification('خطأ أثناء تأكيد التوصيل: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  // OSRM Realtime Routing integration (drawn directly on the main map)
  Future<void> _fetchRouteForOrder(model.Order order) async {
    if (_driverLatLng == null) {
      await _fetchCurrentLocation(fetchRoute: false);
    }
    if (_driverLatLng == null) return;

    LatLng? targetLatLng;
    if (['delivery_accepted', 'preparing', 'ready'].contains(order.status)) {
      // Destination is the Restaurant
      if (order.restaurantId is Map) {
        final rMap = order.restaurantId as Map;
        final addr = rMap['address'];
        if (addr != null && addr['location'] != null) {
          final coords = addr['location']['coordinates'] as List;
          if (coords.length >= 2) {
            targetLatLng = LatLng(coords[1].toDouble(), coords[0].toDouble());
          }
        }
      }
      if (targetLatLng == null) {
        final restProv = Provider.of<RestaurantProvider>(
          context,
          listen: false,
        );
        final rests = restProv.restaurants
            .where((r) => r.id == order.restaurantIdStr)
            .toList();
        if (rests.isNotEmpty &&
            rests.first.address?.location?.coordinates != null) {
          final coords = rests.first.address!.location!.coordinates;
          if (coords.length >= 2) {
            targetLatLng = LatLng(coords[1], coords[0]);
          }
        }
      }
    } else {
      // Destination is the Customer
      if (order.deliveryAddress.location != null) {
        final coords = order.deliveryAddress.location!.coordinates;
        if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
          targetLatLng = LatLng(coords[1], coords[0]);
        }
      }
    }

    final destinationLatLng = targetLatLng ?? const LatLng(33.5150, 36.2850);

    // Only update and call OSRM route service if order state or ID actually changed, or route points empty
    if (_lastRoutedOrderId == order.id &&
        _lastRoutedOrderStatus == order.status &&
        _routePoints.isNotEmpty) {
      // Just update distance locally using Haversine to save API calls
      setState(() {
        _distanceKm = _calculateHaversineDistance(
          _driverLatLng!,
          destinationLatLng,
        );
      });
      _checkProximityAndAutoZoom(destinationLatLng);
      return;
    }

    _lastRoutedOrderId = order.id;
    _lastRoutedOrderStatus = order.status;

    setState(() => _isLoadingRoute = true);

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${_driverLatLng!.longitude},${_driverLatLng!.latitude};'
          '${destinationLatLng.longitude},${destinationLatLng.latitude}'
          '?overview=full&geometries=geojson';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          final points = geometry
              .map<LatLng>((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
              .toList();
          final distanceM = route['distance']?.toDouble() ?? 0.0;
          final durationS = route['duration']?.toDouble() ?? 0.0;

          if (mounted) {
            setState(() {
              _routePoints = points;
              _distanceKm = distanceM / 1000.0;
              _durationMin = durationS / 60.0;
              _isLoadingRoute = false;
            });
            _checkProximityAndAutoZoom(destinationLatLng);
            if (!_followDriver && points.length >= 2) {
              try {
                final bounds = LatLngBounds.fromPoints(points);
                _mapController.fitCamera(CameraFit.bounds(
                    bounds: bounds, padding: const EdgeInsets.all(60)));
              } catch (_) {}
            }
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = [_driverLatLng!, destinationLatLng];
        _distanceKm =
            _calculateHaversineDistance(_driverLatLng!, destinationLatLng);
        _durationMin = _distanceKm * 3.0;
        _isLoadingRoute = false;
      });
      _checkProximityAndAutoZoom(destinationLatLng);
      if (!_followDriver) {
        try {
          final bounds =
              LatLngBounds.fromPoints([_driverLatLng!, destinationLatLng]);
          _mapController.fitCamera(CameraFit.bounds(
              bounds: bounds, padding: const EdgeInsets.all(60)));
        } catch (_) {}
      }
    }
  }

  void _checkProximityAndAutoZoom(LatLng targetLatLng) {
    if (_driverLatLng == null) return;
    if (_distanceKm > 0 && _distanceKm <= 0.5) {
      if (!_hasAutoZoomedProximity) {
        _hasAutoZoomedProximity = true;
        _mapController.move(_driverLatLng!, 17.5);
        if (mounted) {
          _showTopNotification(
            'أنت قريب جداً من الوجهة! تم تكبير الخريطة لتوضيح الشوارع والمباني',
            color: AppTheme.primary,
            icon: Icons.my_location_rounded,
          );
        }
      }
    } else if (_distanceKm > 0.6) {
      _hasAutoZoomedProximity = false;
    }
  }

  double _calculateHaversineDistance(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(h));
  }

  double _calculateBearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _animateDriverTo(LatLng target) {
    if (_driverLatLng != null &&
        _calculateHaversineDistance(_driverLatLng!, target) < 0.005) {
      if (mounted) setState(() => _driverLatLng = target);
      return;
    }
    _driverAnimationTimer?.cancel();
    final start = _driverLatLng ?? target;
    final startTime = DateTime.now();
    const animDuration = Duration(milliseconds: 500);

    _driverAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / animDuration.inMilliseconds)
          .clamp(0.0, 1.0);
      final eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
      final lat = start.latitude + (target.latitude - start.latitude) * eased;
      final lng =
          start.longitude + (target.longitude - start.longitude) * eased;
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newPos = LatLng(lat, lng);
      _driverHeading =
          _calculateBearing(_previousDriverLatLng ?? start, newPos);
      if (mounted) {
        setState(() {
          _driverLatLng = newPos;
        });
      }
      if (t >= 1.0) {
        timer.cancel();
        _previousDriverLatLng = target;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;
    final orderProv = Provider.of<OrderProvider>(context);
    final isAvailable = currentUser?.driverInfo?.availability ?? false;

    final activeOrders = orderProv.orders
        .where(
          (o) =>
              o.driverIdStr == auth.currentUser?.id &&
              [
                'delivery_accepted',
                'preparing',
                'ready',
                'onTheWay',
                'delivered_pending',
              ].contains(o.status),
        )
        .toList();

    final restProv = Provider.of<RestaurantProvider>(context);
    final mapCenter = _driverLatLng ?? const LatLng(33.5138, 36.2765);

    // Build map markers dynamically based on active status
    final List<Marker> mapMarkers = [];

    if (activeOrders.isEmpty) {
      for (var r in restProv.restaurants) {
        final coords = r.address?.location?.coordinates;
        if (coords != null &&
            coords.length >= 2 &&
            !(coords[0] == 0.0 && coords[1] == 0.0)) {
          mapMarkers.add(
            Marker(
              point: LatLng(coords[1], coords[0]),
              width: 120,
              height: 52,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        r.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.restaurant,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }
    } else {
      // Active state: show only the current target location marker
      final activeOrder = activeOrders.first;
      if ([
        'delivery_accepted',
        'preparing',
        'ready',
      ].contains(activeOrder.status)) {
        // Target is restaurant
        LatLng? restLatLng;
        if (activeOrder.restaurantId is Map) {
          final rMap = activeOrder.restaurantId as Map;
          final addr = rMap['address'];
          if (addr != null && addr['location'] != null) {
            final coords = addr['location']['coordinates'] as List;
            if (coords.length >= 2) {
              restLatLng = LatLng(coords[1].toDouble(), coords[0].toDouble());
            }
          }
        }
        if (restLatLng == null) {
          final rests = restProv.restaurants
              .where((r) => r.id == activeOrder.restaurantIdStr)
              .toList();
          if (rests.isNotEmpty &&
              rests.first.address?.location?.coordinates != null) {
            final coords = rests.first.address!.location!.coordinates;
            if (coords.length >= 2) {
              restLatLng = LatLng(coords[1], coords[0]);
            }
          }
        }
        if (restLatLng != null) {
          mapMarkers.add(
            Marker(
              point: restLatLng,
              width: 100,
              height: 64,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        activeOrders.first.restaurantId is Map
                            ? ((activeOrders.first.restaurantId
                                    as Map)['name'] ??
                                'المطعم')
                            : 'المطعم',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6)
                        ],
                      ),
                      child: const Icon(Icons.restaurant,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        // Target is customer
        final deliveryAddr = activeOrder.deliveryAddress;
        if (deliveryAddr.location != null) {
          final coords = deliveryAddr.location!.coordinates;
          if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
            mapMarkers.add(
              Marker(
                point: LatLng(coords[1], coords[0]),
                width: 100,
                height: 64,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade800,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          deliveryAddr.street ?? deliveryAddr.label ?? 'العميل',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6)
                          ],
                        ),
                        child: const Icon(Icons.person_pin_circle,
                            color: Colors.white, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    if (_driverLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _driverLatLng!,
          width: 68,
          height: 68,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.35);
              final opacity = 1.0 - _pulseController.value;
              return SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
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
                      angle: _driverHeading * pi / 180,
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
                                blurRadius: 8),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    if (activeOrders.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 4,
                        right: 4,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_distanceKm.toStringAsFixed(1)} كم',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mapTileUrl = isDarkMode
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    return Scaffold(
      drawer: _buildDrawer(context, auth, isAvailable, orderProv),
      body: Stack(
        children: [
          // 1. Fullscreen Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 13.0,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) {
                    _followDriver = false;
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: mapTileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.wassalni.app',
                ),
                if (activeOrders.isNotEmpty && _routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        strokeWidth: 10.0,
                      ),
                      Polyline(
                        points: _routePoints,
                        color: AppTheme.primary,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
                MarkerLayer(markers: mapMarkers),
              ],
            ),
          ),

          // Route Loading Overlay
          if (_isLoadingRoute)
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
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8)
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('جاري حساب المسار...',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 2. Map Controls (Left side)
          Positioned(
            bottom: activeOrders.isNotEmpty ? 260 : 200,
            left: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlBtn(
                    heroTag: 'recenter_map_btn',
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
                    _buildMapControlBtn(
                      heroTag: 'fit_bounds_btn',
                      icon: Icons.fit_screen_rounded,
                      color: AppTheme.secondary,
                      onPressed: () {
                        try {
                          setState(() => _followDriver = false);
                          final bounds = LatLngBounds.fromPoints(_routePoints);
                          _mapController.fitCamera(
                            CameraFit.bounds(
                              bounds: bounds,
                              padding: const EdgeInsets.all(60.0),
                            ),
                          );
                        } catch (_) {}
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    heroTag: 'zoom_in_map_btn',
                    icon: Icons.add_rounded,
                    onPressed: () {
                      final z = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, z + 1);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlBtn(
                    heroTag: 'zoom_out_map_btn',
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      final z = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, z - 1);
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Bar
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
                    // Menu
                    Builder(
                      builder: (menuCtx) => _GlassBtn(
                        child: Icon(Icons.menu_rounded,
                            size: 20,
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color),
                        onTap: () => Scaffold.of(menuCtx).openDrawer(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Destination Info & Expandable Top Rectangle for Messages with Smooth Grow/Shrink Animation
                    Expanded(
                      child: _GlassCard(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.fastOutSlowIn,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 32,
                                child: activeOrders.isNotEmpty
                                    ? Row(
                                        children: [
                                          Icon(
                                            [
                                              'delivery_accepted',
                                              'preparing',
                                              'ready'
                                            ].contains(
                                                    activeOrders.first.status)
                                                ? Icons.restaurant_rounded
                                                : Icons
                                                    .person_pin_circle_rounded,
                                            color: [
                                              'delivery_accepted',
                                              'preparing',
                                              'ready'
                                            ].contains(
                                                    activeOrders.first.status)
                                                ? Colors.orange
                                                : Colors.red,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  [
                                                    'delivery_accepted',
                                                    'preparing',
                                                    'ready'
                                                  ].contains(activeOrders
                                                          .first.status)
                                                      ? 'التوجه للمطعم'
                                                      : 'التوجه للعميل',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                _isLoadingRoute
                                                    ? const Text(
                                                        'جاري المسار...',
                                                        style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 9))
                                                    : Text(
                                                        '${_distanceKm.toStringAsFixed(1)} كم • ${_durationMin.toStringAsFixed(0)} د',
                                                        style: const TextStyle(
                                                            fontFamily:
                                                                'Outfit',
                                                            color: Colors.blue,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 10),
                                                      ),
                                              ],
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              _lastRoutedOrderId = null;
                                              _fetchRouteForOrder(
                                                  activeOrders.first);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.refresh_rounded,
                                                  color: Colors.green,
                                                  size: 16),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.near_me_rounded,
                                              color: AppTheme.primary,
                                              size: 16),
                                          SizedBox(width: 6),
                                          Text('بانتظار طلب',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11)),
                                        ],
                                      ),
                              ),
                              if (_topNotificationMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: (_topNotificationColor ??
                                              AppTheme.primary)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: (_topNotificationColor ??
                                                AppTheme.primary)
                                            .withValues(alpha: 0.4),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_topNotificationColor ??
                                                  AppTheme.primary)
                                              .withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _topNotificationIcon ??
                                              Icons.info_outline_rounded,
                                          size: 16,
                                          color: _topNotificationColor ??
                                              AppTheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _topNotificationMessage ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Availability Toggle (Always visible, non-clickable/disabled during active order delivery)
                    const SizedBox(width: 8),
                    _AvailabilityBtn(
                      isAvailable: isAvailable,
                      isLoading: _isTogglingAvailability,
                      isDisabled: activeOrders.isNotEmpty,
                      onTap: (activeOrders.isNotEmpty ||
                              _isTogglingAvailability)
                          ? null
                          : () async {
                              setState(() => _isTogglingAvailability = true);
                              try {
                                await _toggleAvailability(auth, !isAvailable);
                              } catch (e) {
                                debugPrint('Toggle error: $e');
                              } finally {
                                if (mounted) {
                                  setState(
                                      () => _isTogglingAvailability = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Quick nav FABs (right side, active order)
          if (activeOrders.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 260,
              child: Column(
                children: [
                  _buildMapControlBtn(
                    heroTag: 'home_center_driver',
                    icon: Icons.my_location_rounded,
                    color: Colors.blue,
                    onPressed: () {
                      setState(() => _followDriver = true);
                      if (_driverLatLng != null) {
                        _mapController.move(_driverLatLng!, 15.0);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildMapControlBtn(
                    heroTag: 'home_center_destination',
                    icon: Icons.flag_rounded,
                    color: Colors.red,
                    onPressed: () {
                      setState(() => _followDriver = false);
                      LatLng? target;
                      final o = activeOrders.first;
                      if (['delivery_accepted', 'preparing', 'ready']
                          .contains(o.status)) {
                        if (o.restaurantId is Map) {
                          final rMap = o.restaurantId as Map;
                          final addr = rMap['address'];
                          if (addr != null && addr['location'] != null) {
                            final coords =
                                addr['location']['coordinates'] as List;
                            if (coords.length >= 2) {
                              target = LatLng(
                                  coords[1].toDouble(), coords[0].toDouble());
                            }
                          }
                        }
                        if (target == null) {
                          final rests = restProv.restaurants
                              .where((r) => r.id == o.restaurantIdStr)
                              .toList();
                          if (rests.isNotEmpty &&
                              rests.first.address?.location?.coordinates !=
                                  null) {
                            final coords =
                                rests.first.address!.location!.coordinates;
                            target = LatLng(coords[1], coords[0]);
                          }
                        }
                      } else {
                        if (o.deliveryAddress.location != null) {
                          final coords =
                              o.deliveryAddress.location!.coordinates;
                          target = LatLng(coords[1], coords[0]);
                        }
                      }
                      if (target != null) {
                        _mapController.move(target, 15.0);
                      }
                    },
                  ),
                ],
              ),
            ),

          // 5.5 Pending Settlement Request Banner (Admin requested settlement confirmation)
          if (currentUser?.pendingSettlement != null &&
              currentUser!.pendingSettlement!['requestId'] != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _buildPendingSettlementCard(auth, currentUser),
            ),

          // 6. Bottom card overlay (only active order)
          if (activeOrders.isNotEmpty)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildActiveOrderCard(orderProv, activeOrders.first),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingSettlementCard(AuthProvider auth, model.User user) {
    final pending = user.pendingSettlement;
    if (pending == null) return const SizedBox(width: 1, height: 1);

    final typeLabel = pending['settlementType'] == 'cash'
        ? 'تسديد وتصفير كاش الزبائن'
        : (pending['settlementType'] == 'earnings'
            ? 'صرف وتصفير أرباح التوصيل'
            : 'تصفير شامل للحسابين');
    final amount = (pending['amount'] is num)
        ? (pending['amount'] as num).toDouble()
        : (double.tryParse(pending['amount']?.toString() ?? '') ?? 0.0);
    final adminName = pending['requestedByName'] ?? 'الأدمن المحاسب';

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
          Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'طلب ترصيد وتأكيد من الأدمن: $adminName',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'يطلب الأدمن إجراء ($typeLabel) بمبلغ: ${amount.toStringAsFixed(0)} ل.س.',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    await auth.respondDriverSettlement(false);
                  },
                  child: const Text('رفض الطلب', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () async {
                    final err = await auth.respondDriverSettlement(true);
                    if (mounted) {
                      if (err == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('تم تأكيد الترصيد وتصفير الحساب بنجاح'),
                              backgroundColor: Colors.green),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(err), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('تأكيد وموافقة',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required String heroTag,
    required IconData icon,
    Color? color,
    required VoidCallback onPressed,
  }) {
    return Material(
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
              color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }

  String _orderStatusLabel(String status) {
    switch (status) {
      case 'restaurant_accepted':
        return 'في المطعم';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'جاهز للاستلام';
      case 'delivery_accepted':
        return 'في الطريق';
      case 'onTheWay':
        return 'توصيل';
      case 'delivered_pending':
        return 'بانتظار التأكيد';
      default:
        return '';
    }
  }

  Widget _buildActiveOrderCard(OrderProvider orderProv, model.Order order) {
    final statusSteps = [
      'restaurant_accepted',
      'preparing',
      'ready',
      'delivery_accepted',
      'onTheWay',
      'delivered_pending'
    ];
    final currentStepIdx = statusSteps.indexOf(order.status);
    final statusLabel = _orderStatusLabel(order.status);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark]),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.id.substring(order.id.length - 6)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$statusLabel • ${order.deliveryFee.toStringAsFixed(0)} ل.س',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Progress Steps
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _StepDot(filled: currentStepIdx >= 0, label: 'قبول'),
                _StepLine(filled: currentStepIdx >= 1),
                _StepDot(filled: currentStepIdx >= 1, label: 'تحضير'),
                _StepLine(filled: currentStepIdx >= 2),
                _StepDot(filled: currentStepIdx >= 2, label: 'جاهز'),
                _StepLine(filled: currentStepIdx >= 3),
                _StepDot(filled: currentStepIdx >= 3, label: 'توصيل'),
                _StepLine(filled: currentStepIdx >= 4),
                _StepDot(filled: currentStepIdx >= 4, label: 'استلام'),
              ],
            ),
          ),
          // Address
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${order.deliveryAddress.city ?? ""} - ${order.deliveryAddress.street ?? ""}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _buildOrderActionButtons(orderProv, order),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOrderActionButtons(OrderProvider orderProv, model.Order order) {
    final isReadyOrAccepted = ['ready', 'delivery_accepted', 'preparing', 'restaurant_accepted'].contains(order.status);
    
    if (isReadyOrAccepted) {
      String statusHint = 'يرجى التوجه للمطعم واستلام الطلب.';
      if (order.status == 'ready') {
        statusHint = 'الطلب جاهز للتوصيل الآن من المطعم!';
      } else if (order.status == 'preparing') {
        statusHint = 'المطعم يقوم بتحضير الطلب حالياً.';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (order.status == 'ready' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusHint,
              style: TextStyle(
                color: order.status == 'ready' ? Colors.green.shade800 : Colors.orange.shade900,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isUpdatingStatus
                  ? null
                  : () => _updateOrderStatus(orderProv, order.id, 'onTheWay'),
              icon: _isUpdatingStatus
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.directions_bike_rounded, size: 22),
              label: Text(
                _isUpdatingStatus
                    ? 'جاري التحديث...'
                    : 'استلمت الطلب وبدأت التوصيل (في الطريق)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == 'onTheWay') {
      final bool isCloseEnough = _distanceKm <= 1.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isCloseEnough) ...[
            Text(
              'المسافة المتبقية للعميل: ${_distanceKm.toStringAsFixed(1)} كم. يرجى الاقتراب لتسليم الطلب.',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              onPressed: _isUpdatingStatus ? null : () => _confirmDelivery(order.id),
              icon: _isUpdatingStatus
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: Text(
                _isUpdatingStatus
                    ? 'جاري الإرسال...'
                    : 'تم الوصول وتوصيل الطلب للعميل',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == 'delivered_pending') {
      return Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'بانتظار تأكيد العميل لاستلام الطلب...',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade800,
                side: BorderSide(color: Colors.orange.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isUpdatingStatus
                  ? null
                  : () async {
                      if (_isUpdatingStatus) return;
                      setState(() => _isUpdatingStatus = true);
                      try {
                        _isDialogShowing = false;
                        await orderProv.loadOrders();
                        final updated =
                            orderProv.orders.where((o) => o.id == order.id).toList();
                        if (updated.isEmpty || updated.first.status == 'delivered') {
                          _triggerDeliveryConfirmedSuccess();
                        } else {
                          _showTopNotification(
                            'العميل لم يقم بالتأكيد بعد، يرجى تذكيره بالنقر على تأكيد الاستلام.',
                            color: Colors.orange,
                            icon: Icons.timer_outlined,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isUpdatingStatus = false);
                      }
                    },
              icon: _isUpdatingStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تحديث حالة التأكيد',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    return const SizedBox();
  }
}

class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _GlassBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.88),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
            width: 44, height: 44, alignment: Alignment.center, child: child),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.88),
      child: child,
    );
  }
}

class _AvailabilityBtn extends StatelessWidget {
  final bool isAvailable;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback? onTap;

  const _AvailabilityBtn({
    required this.isAvailable,
    required this.isLoading,
    this.isDisabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled
        ? (isAvailable
            ? Colors.green.shade800.withValues(alpha: 0.55)
            : Colors.grey.shade700)
        : (isAvailable ? Colors.green.shade600 : Colors.red.shade700);

    Widget content = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: effectiveColor,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: (isAvailable ? Colors.green : Colors.red)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              isAvailable ? 'جاهز' : 'متوقف',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (isDisabled) {
      content = Tooltip(
        message: 'لا يمكنك تغيير الحالة أثناء وجود طلب نشط قيد التوصيل',
        child: content,
      );
    }

    return Material(
      elevation: isDisabled ? 1 : 3,
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: content,
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool filled;
  final String label;
  const _StepDot({required this.filled, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppTheme.primary : Colors.grey[300],
          ),
          child: Icon(
            filled ? Icons.check_rounded : Icons.circle_outlined,
            size: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 8,
                color: filled ? AppTheme.primary : Colors.grey[400],
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool filled;
  const _StepLine({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppTheme.primary : Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. صفحة الطلبات السابقة كجدول بكامل تفاصيل الطلبات وتصدير Excel وفلتر 20 طلب
// ============================================================================
class DriverOrdersHistoryScreen extends StatefulWidget {
  const DriverOrdersHistoryScreen({super.key});

  @override
  State<DriverOrdersHistoryScreen> createState() =>
      _DriverOrdersHistoryScreenState();
}

class _DriverOrdersHistoryScreenState extends State<DriverOrdersHistoryScreen> {
  bool _showLast20Only = true;

  void _exportToExcel(List<model.Order> orders) {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد طلبات لتصديرها')),
      );
      return;
    }

    final sb = StringBuffer();
    // UTF-8 BOM for Microsoft Excel Arabic compatibility
    sb.write('\uFEFF');
    sb.writeln(
        'رقم الطلب,التاريخ والوقت,المطعم,العميل,أجر التوصيل (ل.س),إجمالي الطلب (ل.س),طريقة الدفع,الحالة');

    for (var o in orders) {
      final idStr = o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;
      final dateStr = o.createdAt != null
          ? '${o.createdAt!.year}-${o.createdAt!.month.toString().padLeft(2, '0')}-${o.createdAt!.day.toString().padLeft(2, '0')} ${o.createdAt!.hour.toString().padLeft(2, '0')}:${o.createdAt!.minute.toString().padLeft(2, '0')}'
          : '--';
      final restName = o.restaurantId is Map
          ? ((o.restaurantId as Map)['name'] ?? 'مطعم')
          : 'مطعم';
      final custName =
          o.deliveryAddress.street ?? o.deliveryAddress.region ?? 'عميل';
      final deliveryFee = o.deliveryFee.toStringAsFixed(0);
      final totalAmount = o.totalAmount.toStringAsFixed(0);
      final payMethod = o.paymentMethod == 'wallet' ? 'محفظة' : 'كاش';
      final statusStr = o.status == 'delivered'
          ? 'مكتمل'
          : (o.status == 'cancelled' ? 'ملغى' : o.status);

      sb.writeln(
          '"$idStr","$dateStr","$restName","$custName",$deliveryFee,$totalAmount,"$payMethod","$statusStr"');
    }

    final csvText = sb.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.table_chart_rounded, color: Colors.green, size: 26),
            SizedBox(width: 10),
            Text('تصدير بيانات Excel',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم إعداد ملف Excel لعدد ${orders.length} طلب جاهز للتصدير.',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'معاينة نص التصدير (CSV المتوافق مع Excel):',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Container(
              height: 140,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('تم نسخ بيانات Excel إلى الحافظة بنجاح')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('نسخ البيانات'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ وتصدير ملف Excel بنجاح!')),
              );
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
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);

    final allDriverOrders = orderProv.orders
        .where((o) => o.driverIdStr == auth.currentUser?.id)
        .toList();

    allDriverOrders.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });

    final displayedOrders =
        _showLast20Only ? allDriverOrders.take(20).toList() : allDriverOrders;

    final double totalDeliveryFees =
        displayedOrders.fold(0.0, (sum, o) => sum + o.deliveryFee);
    final double totalOrdersAmount =
        displayedOrders.fold(0.0, (sum, o) => sum + o.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات كجدول'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => orderProv.loadOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Control & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    FilterChip(
                      selected: _showLast20Only,
                      label: const Text('آخر 20 طلب'),
                      onSelected: (v) => setState(() => _showLast20Only = true),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: !_showLast20Only,
                      label: Text('جميع الطلبات (${allDriverOrders.length})'),
                      onSelected: (v) =>
                          setState(() => _showLast20Only = false),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppTheme.primary,
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _exportToExcel(displayedOrders),
                      icon: const Icon(Icons.table_chart_rounded, size: 16),
                      label: const Text('تصدير Excel',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Orders Data Table
          Expanded(
            child: displayedOrders.isEmpty
                ? const Center(
                    child: Text('لا توجد طلبات سابقة تنطبق عليها هذا الفلتر'))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
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
                              label: Text('التاريخ والوقت',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('المطعم',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('العميل والمنطقة',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('أجر التوصيل',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('إجمالي الطلب',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('الدفع',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('الحالة',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: List.generate(displayedOrders.length, (idx) {
                          final o = displayedOrders[idx];
                          final idStr = o.id.length > 6
                              ? o.id.substring(o.id.length - 6)
                              : o.id;
                          final dateStr = o.createdAt != null
                              ? '${o.createdAt!.day}/${o.createdAt!.month} ${o.createdAt!.hour}:${o.createdAt!.minute.toString().padLeft(2, '0')}'
                              : '--';
                          final restName = o.restaurantId is Map
                              ? ((o.restaurantId as Map)['name'] ?? 'مطعم')
                              : 'مطعم';
                          final custAddr = o.deliveryAddress.region ??
                              o.deliveryAddress.city ??
                              'عميل';
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
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit'))),
                              DataCell(Text(dateStr,
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Text(restName,
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Text(custAddr,
                                  style: const TextStyle(fontSize: 12))),
                              DataCell(Text(
                                  '${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontFamily: 'Outfit'))),
                              DataCell(Text(
                                  '${o.totalAmount.toStringAsFixed(0)} ل.س',
                                  style:
                                      const TextStyle(fontFamily: 'Outfit'))),
                              DataCell(Chip(
                                label: Text(
                                    o.paymentMethod == 'wallet'
                                        ? 'محفظة'
                                        : 'كاش',
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isDelivered ? 'مكتمل' : 'ملغى',
                                  style: TextStyle(
                                      color: isDelivered
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              )),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),

          // Total Summary Footer Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              border: Border(
                  top: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المجموع الكلي (${displayedOrders.length} طلب):',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Row(
                  children: [
                    const Text('أرباح التوصيل: ',
                        style: TextStyle(fontSize: 12)),
                    Text(
                      '${totalDeliveryFees.toStringAsFixed(0)} ل.س',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 14),
                    const Text('المبيعات: ', style: TextStyle(fontSize: 12)),
                    Text(
                      '${totalOrdersAmount.toStringAsFixed(0)} ل.س',
                      style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. صفحة جدول كشف الرصيد والمحفظة بالتفاصيل والمجموع الكلي
// ============================================================================
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  bool _isSettling = false;

  Future<void> _confirmAndSettle(BuildContext context, AuthProvider auth,
      String settlementType, String title, String body) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              settlementType == 'cash'
                  ? Icons.payments_rounded
                  : (settlementType == 'earnings'
                      ? Icons.stars_rounded
                      : Icons.account_balance_wallet_rounded),
              color: settlementType == 'cash'
                  ? Colors.orange.shade800
                  : Colors.green.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ],
        ),
        content: Text(body, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: settlementType == 'cash'
                  ? Colors.orange.shade800
                  : Colors.green.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('تأكيد الترصيد والتصفير'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isSettling = true);
      final err = await auth.settleDriverWallet(settlementType);
      if (mounted) setState(() => _isSettling = false);

      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settlementType == 'cash'
                ? 'تم تسديد وتصفير كاش الزبائن بنجاح'
                : (settlementType == 'earnings'
                    ? 'تم صرف وتصفير أرباح التوصيل بنجاح'
                    : 'تم ترصيد وتصفير كامل الحسابات بنجاح')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);

    final driver = auth.currentUser;
    final customerPayments = driver?.customerPaymentsWallet ?? 0.0;
    final driverEarnings = driver?.driverEarningsWallet ?? 0.0;

    final driverOrders = orderProv.orders
        .where((o) => o.driverIdStr == driver?.id && o.status == 'delivered')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول كشف الرصيد وتصفير الحسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => orderProv.loadOrders(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 2 Main Wallet Cards with Independent Zeroing Buttons
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Card 1: أرباح التوصيل المستحقة للسائق
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF2E7D32),
                                Color(0xFF1B5E20)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.stars_rounded,
                                        color: Colors.amber, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'أرباح التوصيل (مستحقاتك)',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${driverEarnings.toStringAsFixed(0)} ل.س',
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.green.shade800,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: driverEarnings <= 0
                                        ? null
                                        : () => _confirmAndSettle(
                                              context,
                                              auth,
                                              'earnings',
                                              'قبض أرباح التوصيل',
                                              'هل تم قبض أرباح التوصيل كاش من المحاسب بقيمة ${driverEarnings.toStringAsFixed(0)} ل.س؟ عند التأكيد سيتم تصفير محفظة الأرباح.',
                                            ),
                                    icon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 14),
                                    label: const Text('قبض وتصفير الأرباح',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Card 2: كاش الزبائن المجمّع لدى السائق
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFE65100),
                                Color(0xFFBF360C)
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.payments_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'كاش الزبائن (ذمة بيدك)',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${customerPayments.toStringAsFixed(0)} ل.س',
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor:
                                          Colors.deepOrange.shade900,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onPressed: customerPayments <= 0
                                        ? null
                                        : () => _confirmAndSettle(
                                              context,
                                              auth,
                                              'cash',
                                              'تسديد كاش الزبائن',
                                              'هل تم تسليم كاش الزبائن للمحاسب بقيمة ${customerPayments.toStringAsFixed(0)} ل.س؟ عند التأكيد سيتم تصفير ذمة الكاش.',
                                            ),
                                    icon: const Icon(Icons.outbox_rounded,
                                        size: 14),
                                    label: const Text('تسديد وتصفير الكاش',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    // Optional Bulk Zeroing Option
                    if (customerPayments > 0 && driverEarnings > 0)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                              color: AppTheme.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _confirmAndSettle(
                          context,
                          auth,
                          'both',
                          'ترصيد الخزينتين معاً',
                          'هل تم إجراء التسوية الشاملة مع المحاسب لكاش الزبائن (${customerPayments.toStringAsFixed(0)} ل.س) ولأرباح التوصيل (${driverEarnings.toStringAsFixed(0)} ل.س)؟ سيتم تصفير الرصيدين معاً.',
                        ),
                        icon: const Icon(Icons.published_with_changes_rounded,
                            size: 16),
                        label: const Text('تصفيرات الخزينتين معاً (ترصيد شامل)',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('سجل حركة الطلبات التي كوّنت الرصيد الحالي:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 4),

              // Balance Breakdown Data Table
              Expanded(
                child: driverOrders.isEmpty
                    ? const Center(
                        child:
                            Text('لا توجد طلبات مكتملة مسجلة في الرصيد حالياً'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                                AppTheme.primary.withValues(alpha: 0.1)),
                            columns: const [
                              DataColumn(
                                  label: Text('رقم الطلب',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('التاريخ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('أرباحك التوصيل (+)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('كاش الزبون (ذمة)',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('طريقة الدفع',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('الحالة',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: List.generate(driverOrders.length, (idx) {
                              final o = driverOrders[idx];
                              final idStr = o.id.length > 6
                                  ? o.id.substring(o.id.length - 6)
                                  : o.id;
                              final dateStr = o.createdAt != null
                                  ? '${o.createdAt!.day}/${o.createdAt!.month} ${o.createdAt!.hour}:${o.createdAt!.minute.toString().padLeft(2, '0')}'
                                  : '--';
                              final isCash = o.paymentMethod == 'cash';
                              final cashReceived = isCash
                                  ? (o.totalAmount + o.deliveryFee)
                                  : 0.0;

                              return DataRow(
                                cells: [
                                  DataCell(Text('#$idStr',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit'))),
                                  DataCell(Text(dateStr,
                                      style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(
                                      '+${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontFamily: 'Outfit'))),
                                  DataCell(Text(
                                      '${cashReceived.toStringAsFixed(0)} ل.س',
                                      style: TextStyle(
                                          fontFamily: 'Outfit',
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
                                    visualDensity: VisualDensity.compact,
                                  )),
                                  DataCell(const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.green,
                                      size: 18)),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (_isSettling)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
