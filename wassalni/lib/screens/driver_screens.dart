// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
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

class _DriverHomeScreenState extends State<DriverHomeScreen> with SingleTickerProviderStateMixin {
  LatLng? _driverLatLng;
  bool _isDialogShowing = false;
  Timer? _driverLocationTimer;
  Timer? _orderSearchTimer;
  bool _followDriver = true;
  bool _isTogglingAvailability = false;
  late AnimationController _pulseController;

  // Real-time Routing properties (Merged from DeliveryMapScreen)
  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  double _durationMin = 0.0;
  bool _isLoadingRoute = false;
  String? _lastRoutedOrderId;
  String? _lastRoutedOrderStatus;
  bool _hasAutoZoomedProximity = false;
  final MapController _mapController = MapController();

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('تم تأكيد التوصيل! 🎉'),
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

  void _startOrderSearchTimer() {
    _orderSearchTimer?.cancel();
    _orderSearchTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) { timer.cancel(); return; }
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;
      if (!isAvailable) { timer.cancel(); return; }

      // Check if driver has active order already
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final driverId = auth.currentUser?.id;
      final hasActive = orderProv.orders.any((o) =>
        o.driverIdStr == driverId &&
        ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'].contains(o.status)
      );
      if (hasActive) return; // Don't search when already delivering

      await orderProv.loadAvailableOrders();
    });
  }

  void _stopOrderSearchTimer() {
    _orderSearchTimer?.cancel();
    _orderSearchTimer = null;
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final err = await LocationHelper.checkAndRequestPermissions();
      if (err != null) return;

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        final newLatLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _driverLatLng = newLatLng;
        });

        // Auto-follow: move map camera to driver location
        if (_followDriver) {
          try {
            _mapController.move(newLatLng, _mapController.camera.zoom);
          } catch (_) {}
        }

        // Recalculate route if active order is present
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
    } catch (e) {
      debugPrint('Fetch driver location error: $e');
    }
  }

  @override
  void dispose() {
    _driverLocationTimer?.cancel();
    _orderSearchTimer?.cancel();
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
        final completed = orderProv.orders.where((o) => o.id == lastId && o.status == 'delivered').toList();
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

        if (availableOrders.isNotEmpty && !_isDialogShowing) {
          _showOrderOfferDialog(availableOrders.first);
        }
      }
    }
  }

  void _showOrderOfferDialog(model.Order order) {
    if (!mounted || _isDialogShowing) return;

    _isDialogShowing = true;
    _dismissedOrderIds.add(order.id);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('يوجد طلب قريب!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('سعر التوصيل: ${order.deliveryFee.toStringAsFixed(0)} ل.س'),
            const SizedBox(height: 8),
            Text('المسافة: 2.5 كم تقريباً'),
            const SizedBox(height: 12),
            const Text(
              'تفاصيل الوجبة:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...order.items.map((it) => Text('• ${it.name} (${it.quantity})')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final orderProv = Provider.of<OrderProvider>(
                context,
                listen: false,
              );
              orderProv.rejectOrder(order.id);
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _acceptOrder(order.id);
            },
            child: const Text('قبول (تأكيد)'),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Future<void> _acceptOrder(String orderId) async {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final err = await orderProv.acceptOrder(orderId);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول الطلب! اتبع مسار الخريطة للوصول للمطعم'),
        ),
      );
      await orderProv.loadOrders();
      await orderProv.loadAvailableOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'restaurant_accepted':
        return 'مقبول من المطعم';
      case 'preparing':
        return 'جاري التحضير';
      case 'ready':
        return 'جاهز للتوصيل';
      case 'delivery_accepted':
        return 'مقبول من السائق';
      case 'onTheWay':
        return 'في الطريق';
      case 'delivered_pending':
        return 'بانتظار العميل';
      case 'delivered':
        return 'تم التوصيل بنجاح ✓';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  void _showHistoryDialog(
    BuildContext context,
    OrderProvider orderProv,
    String? userId,
  ) {
    final driverOrders = orderProv.orders
        .where((o) => o.driverIdStr == userId)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سجل الطلبات المكتملة', textAlign: TextAlign.right),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: driverOrders.isEmpty
              ? const Center(child: Text('لا توجد طلبات سابقة'))
              : ListView.builder(
                  itemCount: driverOrders.length,
                  itemBuilder: (context, idx) {
                    final order = driverOrders[idx];
                    final isDelivered = order.status == 'delivered';
                    final statusColor = isDelivered ? Colors.green : Colors.red;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Theme.of(context).cardColor,
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: statusColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'طلب #${order.id.substring(order.id.length - 6)}',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'أجر التوصيل: ${order.deliveryFee.toStringAsFixed(0)} ل.س',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusText(order.status),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
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

  void _showWalletDialog(
    BuildContext context,
    AuthProvider auth,
    double totalEarnings,
  ) {
    final driver = auth.currentUser;
    final customerPayments = driver?.customerPaymentsWallet ?? 0;
    final driverEarnings = driver?.driverEarningsWallet ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 24),
            SizedBox(width: 8),
            Text('محافظ السائق المزدوجة', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. محفظة أرباح الدليفري
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.walletGradient(isSecondary: false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'رصيد أرباح الدليفري (أجرك الخاص)',
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${driverEarnings.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. محفظة مدفوعات زبائن (كاش)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: AppTheme.walletGradient(isSecondary: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'رصيد مدفوعات زبائن (مبالغ كاش)',
                        style: TextStyle(fontFamily: 'Outfit', color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${customerPayments.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'ملاحظة: يتم تسوية مبالغ الكاش المستلمة وأرباح التوصيل بالتنسيق مع الإدارة.',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
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
    final double totalEarnings = orderProv.orders
        .where(
          (o) =>
              o.driverIdStr == auth.currentUser?.id && o.status == 'delivered',
        )
        .fold(0.0, (sum, o) => sum + o.deliveryFee);

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
          SwitchListTile(
            title: const Text(
              'جاهز للعمل',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              orderProv.orders.any((o) =>
                  o.driverIdStr == auth.currentUser?.id &&
                  ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'].contains(o.status))
                  ? 'لديك طلب نشط جاري توصيله 🛵'
                  : (isAvailable ? 'أنت متصل وتستقبل الطلبات' : 'متوقف عن العمل'),
              style: TextStyle(
                color: orderProv.orders.any((o) =>
                    o.driverIdStr == auth.currentUser?.id &&
                    ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'].contains(o.status))
                    ? Colors.orange
                    : (isAvailable ? Colors.green : Colors.grey),
              ),
            ),
            value: isAvailable,
            activeColor: Colors.green,
            onChanged: orderProv.orders.any((o) =>
                    o.driverIdStr == auth.currentUser?.id &&
                    ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'].contains(o.status))
                ? null
                : (val) {
                    _toggleAvailability(auth, val);
                  },
            secondary: Icon(
              Icons.radar,
              color: isAvailable ? Colors.green : Colors.grey,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.blue),
            title: const Text('الطلبات السابقة'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(context);
              _showHistoryDialog(context, orderProv, auth.currentUser?.id);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.account_balance_wallet,
              color: Colors.green,
            ),
            title: const Text('الرصيد'),
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
              _showWalletDialog(context, auth, totalEarnings);
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
      ['delivery_accepted', 'preparing', 'ready', 'onTheWay', 'delivered_pending'].contains(o.status)
    );

    if (hasActiveOrder && !active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكنك إيقاف العمل أثناء وجود طلب نشط قيد التوصيل!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final err = await auth.toggleDriverAvailability(active);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'تم تفعيل الاتصال واستقبال الطلبات'
                : 'تم إيقاف استقبال الطلبات',
          ),
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
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
    final err = await orderProv.updateStatus(id, status);
    if (err == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الطلب')));
      orderProv.loadOrders();
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).tryAutoLogin(); // Update balance
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _confirmDelivery(String orderId) async {
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final err = await orderProv.confirmDelivery(orderId);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلب تأكيد الاستلام للعميل. يرجى الانتظار لتأكيد المعاملة.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // OSRM Realtime Routing integration (drawn directly on the main map)
  Future<void> _fetchRouteForOrder(model.Order order) async {
    if (_driverLatLng == null) {
      await _fetchCurrentLocation();
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
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${_driverLatLng!.longitude},${_driverLatLng!.latitude};'
          '${destinationLatLng.longitude},${destinationLatLng.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

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
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      setState(() {
        _routePoints = [_driverLatLng!, destinationLatLng];
        _distanceKm = _calculateHaversineDistance(_driverLatLng!, destinationLatLng);
        _durationMin = _distanceKm * 3.0; // rough guess
        _isLoadingRoute = false;
      });
      _checkProximityAndAutoZoom(destinationLatLng);
    }
  }

  void _checkProximityAndAutoZoom(LatLng targetLatLng) {
    if (_driverLatLng == null) return;
    if (_distanceKm > 0 && _distanceKm <= 0.5) {
      if (!_hasAutoZoomedProximity) {
        _hasAutoZoomedProximity = true;
        _mapController.move(_driverLatLng!, 17.5);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎯 أنت قريب جداً من الوجهة! تم تكبير الخريطة لتوضيح الشوارع والمباني'),
              duration: Duration(seconds: 3),
              backgroundColor: AppTheme.primary,
            ),
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
    final h =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * R * asin(sqrt(h));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);
    final isAvailable = auth.currentUser?.driverInfo?.availability ?? false;

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
      // Idle state: show all nearby restaurants
      for (var r in restProv.restaurants) {
        final coords = r.address?.location?.coordinates;
        if (coords != null &&
            coords.length >= 2 &&
            !(coords[0] == 0.0 && coords[1] == 0.0)) {
          mapMarkers.add(
            Marker(
              point: LatLng(coords[1], coords[0]),
              width: 40,
              height: 40,
              child: Tooltip(
                message: r.name,
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.red,
                  size: 30,
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
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          );
        }
      } else {
        // Target is customer
        if (activeOrder.deliveryAddress.location != null) {
          final coords = activeOrder.deliveryAddress.location!.coordinates;
          if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
            mapMarkers.add(
              Marker(
                point: LatLng(coords[1], coords[0]),
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            );
          }
        }
      }
    }

    // Always overlay driver's current marker with pulse animation
    if (_driverLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _driverLatLng!,
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.4);
              final opacity = 1.0 - _pulseController.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse ring
                  Container(
                    width: 48 * scale,
                    height: 48 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isAvailable ? Colors.green : Colors.blue).withValues(alpha: 0.3 * opacity),
                    ),
                  ),
                  // Driver dot
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
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
                    icon: _followDriver ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
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

          // 3. Top Bar: Semi-transparent Menu (Right) + Destination Box (Center) + Status Toggle (Left)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Drawer Menu Button (Right side)
                    Builder(
                      builder: (context) => Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Scaffold.of(context).openDrawer(),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.menu_rounded,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Destination Box (Center)
                    Expanded(
                      child: Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(14),
                        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          child: activeOrders.isNotEmpty
                              ? Row(
                                  children: [
                                    Icon(
                                      ['delivery_accepted', 'preparing', 'ready'].contains(activeOrders.first.status)
                                          ? Icons.restaurant_rounded
                                          : Icons.person_pin_circle_rounded,
                                      color: ['delivery_accepted', 'preparing', 'ready'].contains(activeOrders.first.status)
                                          ? Colors.orange
                                          : Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ['delivery_accepted', 'preparing', 'ready'].contains(activeOrders.first.status)
                                                ? 'التوجه للمطعم'
                                                : 'التوجه للعميل',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          _isLoadingRoute
                                              ? const Text(
                                                  'جاري المسار...',
                                                  style: TextStyle(color: Colors.grey, fontSize: 10),
                                                )
                                              : Text(
                                                  '${_distanceKm.toStringAsFixed(1)} كم • ${_durationMin.toStringAsFixed(0)} د',
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        _lastRoutedOrderId = null;
                                        _fetchRouteForOrder(activeOrders.first);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(Icons.refresh_rounded, color: Colors.green, size: 18),
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.near_me_rounded, color: AppTheme.primary, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'الوجهة: بانتظار طلب',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    // Compact & Semi-transparent Status Button (Left side - only visible when NO active order)
                    if (activeOrders.isEmpty) ...[
                      const SizedBox(width: 8),
                      Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _isTogglingAvailability
                              ? null
                              : () async {
                                  setState(() => _isTogglingAvailability = true);
                                  await _toggleAvailability(auth, !isAvailable);
                                  if (mounted) setState(() => _isTogglingAvailability = false);
                                },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: !isAvailable
                                  ? Colors.red.shade700.withValues(alpha: 0.85)
                                  : Colors.green.shade600.withValues(alpha: 0.85),
                              boxShadow: [
                                BoxShadow(
                                  color: (!isAvailable ? Colors.red : Colors.green).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isTogglingAvailability)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(
                                    !isAvailable
                                        ? Icons.power_settings_new_rounded
                                        : Icons.wifi_tethering_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  !isAvailable ? 'متوقف' : 'جاهز',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                      if (['delivery_accepted', 'preparing', 'ready'].contains(o.status)) {
                        if (o.restaurantId is Map) {
                          final rMap = o.restaurantId as Map;
                          final addr = rMap['address'];
                          if (addr != null && addr['location'] != null) {
                            final coords = addr['location']['coordinates'] as List;
                            if (coords.length >= 2) {
                              target = LatLng(coords[1].toDouble(), coords[0].toDouble());
                            }
                          }
                        }
                        if (target == null) {
                          final rests = restProv.restaurants.where((r) => r.id == o.restaurantIdStr).toList();
                          if (rests.isNotEmpty && rests.first.address?.location?.coordinates != null) {
                            final coords = rests.first.address!.location!.coordinates;
                            target = LatLng(coords[1], coords[0]);
                          }
                        }
                      } else {
                        if (o.deliveryAddress.location != null) {
                          final coords = o.deliveryAddress.location!.coordinates;
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
          width: 40, height: 40,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: color ?? Theme.of(context).textTheme.bodyLarge?.color),
        ),
      ),
    );
  }


  Widget _buildActiveOrderCard(OrderProvider orderProv, model.Order order) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'طلب نشط #${order.id.substring(order.id.length - 6)}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${order.deliveryFee.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${order.deliveryAddress.city ?? ""} - ${order.deliveryAddress.street ?? ""}',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildOrderActionButtons(orderProv, order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActionButtons(OrderProvider orderProv, model.Order order) {
    if (order.status == 'restaurant_accepted' || order.status == 'preparing') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'المطعم يقوم بتحضير الطلب حالياً. يرجى التوجه للمطعم.',
            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => orderProv.loadOrders(),
            child: const Text('تحديث حالة التحضير'),
          ),
        ],
      );
    }
    if (order.status == 'ready' || order.status == 'delivery_accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _updateOrderStatus(orderProv, order.id, 'onTheWay'),
          child: const Text(
            'استلمت الطلب وبدأت التوصيل (في الطريق)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    if (order.status == 'onTheWay') {
      final bool isCloseEnough = _distanceKm <= 1.0;
      if (!isCloseEnough) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'المسافة المتبقية للعميل: ${_distanceKm.toStringAsFixed(1)} كم. يرجى الاقتراب لتسليم الطلب.',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                _lastRoutedOrderId = null; // force recalc
                _fetchRouteForOrder(order);
              },
              child: const Text('تحديث المسار والموقع'),
            ),
          ],
        );
      } else {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirmDelivery(order.id),
            icon: const Icon(Icons.check_circle_outline, size: 24),
            label: const Text(
              'تم الوصول وتوصيل الطلب للعميل',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                _isDialogShowing = false;
                await orderProv.loadOrders();
                final updated = orderProv.orders.where((o) => o.id == order.id).toList();
                if (updated.isEmpty || updated.first.status == 'delivered') {
                  _triggerDeliveryConfirmedSuccess();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('العميل لم يقم بالتأكيد بعد، يرجى تذكيره بالنقر على تأكيد الاستلام.')),
                  );
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تحديث حالة التأكيد 🔄', style: TextStyle(fontFamily: 'Outfit', fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }
    return const SizedBox();
  }
}
