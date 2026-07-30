// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart' as model;
import '../core/theme.dart';

class RestaurantHomeScreen extends StatefulWidget {
  const RestaurantHomeScreen({super.key});

  @override
  _RestaurantHomeScreenState createState() => _RestaurantHomeScreenState();
}

class _RestaurantHomeScreenState extends State<RestaurantHomeScreen> {
  int _tabIndex = 0; // 0: Dashboard, 1: Orders, 2: Menu, 3: Settings
  Timer? _ordersAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders();
      orderProv.setupSocketListeners();
    });

    _ordersAutoRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false).loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _ordersAutoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);
    final isOpen = auth.currentUser?.restaurantInfo?.status == 'open';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 6.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Restaurant Name & Interactive Status Toggle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_rounded,
                              color: AppTheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.currentUser?.name ?? 'المطعم',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Status Indicator & Interactive Toggle Button
                        InkWell(
                          onTap: () async {
                            final info = auth.currentUser?.restaurantInfo;
                            if (info == null) return;
                            final newStatus = isOpen ? 'closed' : 'open';
                            final updatedInfo = model.RestaurantInfo(
                              description: info.description,
                              logo: info.logo,
                              status: newStatus,
                              minOrderAmount: info.minOrderAmount,
                              deliveryFee: info.deliveryFee,
                              menu: info.menu,
                              cuisineType: info.cuisineType,
                              firebaseNotifications: info.firebaseNotifications,
                            );
                            await auth.updateProfile(
                              restaurantInfo: updatedInfo,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newStatus == 'open'
                                      ? 'تم فتح المطعم بنجاح واستقبال الطلبات 🟢'
                                      : 'تم إغلاق المطعم وتوقف استقبال الطلبات 🔴',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isOpen ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isOpen ? Colors.green : Colors.red)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOpen ? Colors.green : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isOpen
                                      ? 'المطعم: مفتوح (انقر للتغيير 🟢)'
                                      : 'المطعم: مغلق (انقر للتغيير 🔴)',
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOpen ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Profile Button with Dropdown Popup Menu
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'profile':
                          Navigator.pushNamed(context, '/profile');
                          break;
                        case 'sales':
                          Navigator.pushNamed(context, '/completed-orders');
                          break;
                        case 'finance':
                          _showFinancialDialog(context, auth, orderProv);
                          break;
                        case 'logout':
                          await auth.logout();
                          Navigator.pushReplacementNamed(context, '/login');
                          break;
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'الملف الشخصي',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sales',
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.blue,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'سجل المبيعات',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'finance',
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.green,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'إدارة الأموال',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'تسجيل الخروج',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildSelectedTab(auth, orderProv),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (idx) => setState(() => _tabIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'إدارة الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu_rounded),
            label: 'قائمة الطعام',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  void _showFinancialDialog(
    BuildContext context,
    AuthProvider auth,
    OrderProvider orderProv,
  ) {
    final completedOrders = orderProv.orders
        .where((o) => o.status == 'delivered')
        .toList();
    final double salesVolume = completedOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
            SizedBox(width: 10),
            Text(
              'إدارة الأموال والأرباح',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الرصيد المتاح حالياً:',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إجمالي حجم المبيعات:',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${salesVolume.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'من إجمالي ${completedOrders.length} طلب مكتمل',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              auth.tryAutoLogin();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تحديث البيانات المالية والرصيد'),
                ),
              );
            },
            child: const Text(
              'تحديث البيانات',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق', style: TextStyle(fontFamily: 'Outfit')),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTab(AuthProvider auth, OrderProvider orderProv) {
    switch (_tabIndex) {
      case 0:
        return _buildDashboard(auth, orderProv);
      case 1:
        return _buildOrderManagement(orderProv);
      case 2:
        return const ManageMenuScreen();
      case 3:
        return _buildSettings(auth);
      default:
        return const SizedBox();
    }
  }

  // Dashboard (الرئيسية)
  Widget _buildDashboard(AuthProvider auth, OrderProvider orderProv) {
    final restaurantInfo = auth.currentUser?.restaurantInfo;

    // Calculations
    final completedOrders = orderProv.orders
        .where((o) => o.status == 'delivered')
        .toList();
    final double salesVolume = completedOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    final preparingCount = orderProv.orders
        .where(
          (o) =>
              o.status == 'restaurant_accepted' ||
              o.status == 'delivery_accepted' ||
              o.status == 'preparing',
        )
        .length;
    final newCount = orderProv.orders
        .where((o) => o.status == 'pending')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card: Balance and Quick Info
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.primaryGradient().copyWith(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الرصيد المتاح:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  '${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'حالة المطعم: ${restaurantInfo?.status == 'open' ? 'مفتوح 🟢' : 'مغلق 🔴'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'التصنيف: ${restaurantInfo?.cuisineType ?? 'غير محدد'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sales statistics
          const Text(
            'إحصائيات المبيعات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.green.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'حجم المبيعات',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${salesVolume.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, '/completed-orders');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    color: Colors.blue.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'الطلبات المكتملة',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${completedOrders.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Action Items
          const Text(
            'الطلبات المشتراة التي يجب تحضيرها',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCounter(
                context,
                'طلبات جديدة',
                newCount,
                Colors.redAccent,
                onTap: () {
                  setState(() {
                    _tabIndex = 1;
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildStatCounter(
                context,
                'قيد التحضير',
                preparingCount,
                Colors.orange,
                onTap: () {
                  setState(() {
                    _tabIndex = 1;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCounter(
    BuildContext context,
    String title,
    int count,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(title, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern Kitchen Order Management - Unified Single-Page View (إدارة الطلبات في قائمة مدمجة موحدة)
  Widget _buildOrderManagement(OrderProvider orderProv) {
    final activeOrders = orderProv.orders
        .where(
          (o) =>
              o.status == 'pending' ||
              o.status == 'restaurant_accepted' ||
              o.status == 'preparing' ||
              o.status == 'delivery_accepted' ||
              o.status == 'ready',
        )
        .toList();

    int statusPriority(String status) {
      switch (status) {
        case 'pending':
          return 1;
        case 'restaurant_accepted':
        case 'preparing':
        case 'delivery_accepted':
          return 2;
        case 'ready':
          return 3;
        default:
          return 4;
      }
    }

    activeOrders.sort((a, b) => statusPriority(a.status).compareTo(statusPriority(b.status)));

    return Column(
      children: [
        // Sub-Header Bar: Active Orders Header & Shortcut to Completed Orders Page
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'الطلبات الجارية',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${activeOrders.length}',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              // Button to open completed orders standalone page
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/completed-orders'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Colors.green,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'الطلبات المكتملة 🟢',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Unified Body: All active orders listed together without section dividers
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => orderProv.loadOrders(),
            child: activeOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد طلبات جارية حالياً',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(orderProv, activeOrders[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderProvider orderProv, model.Order order) {
    final isWallet = order.paymentMethod == 'wallet';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (order.status) {
      case 'pending':
        statusColor = AppTheme.error;
        statusLabel = 'جديد 🔴';
        statusIcon = Icons.new_releases_rounded;
        break;
      case 'restaurant_accepted':
      case 'preparing':
        statusColor = Colors.orange;
        statusLabel = 'قيد التحضير 🍳';
        statusIcon = Icons.soup_kitchen_rounded;
        break;
      case 'ready':
        statusColor = Colors.green;
        statusLabel = 'جاهزة للتوصيل 🟢';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'delivery_accepted':
        statusColor = Colors.blue;
        statusLabel = 'مع الكابتن 🛵';
        statusIcon = Icons.directions_bike_rounded;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusLabel = 'مكتمل ومسلّم 🟢';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = order.status;
        statusIcon = Icons.info_outline_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distinct Color Banner Header for each order status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            color: statusColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isWallet ? '💳 محفظة' : '💵 كاش',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const SizedBox(height: 14),

            // Customer Info Box
            Builder(
              builder: (context) {
                String customerName = 'زبون المطعم';
                if (order.customerId is model.User) {
                  customerName = (order.customerId as model.User).name;
                } else if (order.customerId is Map) {
                  customerName = order.customerId['name'] ?? 'زبون المطعم';
                }

                final addressStr = [
                  order.deliveryAddress.region,
                  order.deliveryAddress.details ?? order.deliveryAddress.street,
                  order.deliveryAddress.governorate,
                ].where((s) => s != null && s.isNotEmpty).join(' - ');

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_pin_circle_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'العميل: $customerName',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (addressStr.isNotEmpty)
                              Text(
                                'عنوان التوصيل: $addressStr',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Items List
            const Text(
              'الوجبات والأصناف المطلوبة:',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: order.items
                    .map(
                      (it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '×${it.quantity}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                it.name,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(it.price * it.quantity).toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Total price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المبلغ الإجمالي:',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${order.totalAmount.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildOrderActionButtons(orderProv, order),
          ],
        ),
      ),
    ],
  ),
);
  }

  Widget _buildOrderActionButtons(OrderProvider orderProv, model.Order order) {
    if (order.status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(140, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.bolt_rounded, color: Colors.white),
            onPressed: () =>
                orderProv.updateStatus(order.id, 'restaurant_accepted'),
            label: const Text(
              'قبول الطلب',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    if (order.status == 'restaurant_accepted') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              minimumSize: const Size(140, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.white),
            onPressed: () => orderProv.updateStatus(order.id, 'preparing'),
            label: const Text(
              'بدء التحضير',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    if (order.status == 'preparing') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              minimumSize: const Size(160, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.takeout_dining_rounded, color: Colors.white),
            onPressed: () => _markAsReadyWithPicture(orderProv, order.id),
            label: const Text(
              'تغليف وجاهز للتوصيل',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }
    if (order.status == 'ready') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.radar_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'الطلب جاهز! جاري رصد وبحث كابتن توصيل قريب...',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (order.status == 'delivery_accepted') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم قبول الطلب من قبل الكابتن وهو في الطريق للمطعم',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (order.status == 'delivered') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم توصيل هذا الطلب للعميل واستلامه بنجاح 🟢',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox();
  }

  // Camera integration for packaged/safety photo
  Future<void> _markAsReadyWithPicture(
    OrderProvider orderProv,
    String orderId,
  ) async {
    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('صورة تغليف الطلب'),
          content: const Text(
            'التقط صورة لتغليف الطلب، أو اختر من المعرض، أو استخدم صورة افتراضية للتجربة السريعة:',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'default'),
              child: const Text('صورة افتراضية (للتجربة)'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'gallery'),
              child: const Text('المعرض'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, 'camera'),
              child: const Text('الكاميرا'),
            ),
          ],
        ),
      );

      if (choice == null) return;

      if (choice == 'camera') {
        pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 50,
        );
      } else if (choice == 'gallery') {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 50,
        );
      } else if (choice == 'default') {
        const base64Image =
            'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'; // tiny transparent 1x1 image
        final err = await orderProv.updateStatus(
          orderId,
          'ready',
          packagedPicture: base64Image,
        );
        if (err == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال تنبيه الطلب جاهز وجاري البحث عن كابتن'),
            ),
          );
          orderProv.loadOrders();
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err)));
        }
        return;
      }
    } catch (e) {
      debugPrint('Image picking error: $e');
    }

    if (pickedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء التقاط الصورة')));
      return;
    }

    final bytes = await File(pickedFile.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    final err = await orderProv.updateStatus(
      orderId,
      'ready',
      packagedPicture: base64Image,
    );
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال تنبيه الطلب جاهز وجاري البحث عن كابتن'),
        ),
      );
      orderProv.loadOrders();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // Settings (الإعدادات)
  Widget _buildSettings(AuthProvider auth) {
    final info = auth.currentUser?.restaurantInfo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'إعدادات المطعم',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // Open/Closed Dropdown
              DropdownButtonFormField<String>(
                value: info?.status ?? 'open',
                decoration: const InputDecoration(
                  labelText: 'حالة فتح/إغلاق المطعم',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'open',
                    child: Text('مفتوح حالياً (يستقبل طلبات)'),
                  ),
                  DropdownMenuItem(
                    value: 'closed',
                    child: Text('مغلق حالياً (لا يستقبل طلبات)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    auth.updateProfile(
                      restaurantInfo: model.RestaurantInfo(
                        logo: info?.logo ?? '',
                        status: val,
                        minOrderAmount: info?.minOrderAmount ?? 0,
                        deliveryFee: info?.deliveryFee ?? 0,
                        menu: info?.menu ?? [],
                        cuisineType: info?.cuisineType ?? 'مشاوي',
                        firebaseNotifications:
                            info?.firebaseNotifications ?? true,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Firebase notifications toggle
              SwitchListTile(
                title: const Text('تنبيهات فايرباس (إشعار طلب جديد)'),
                value: info?.firebaseNotifications ?? true,
                onChanged: (val) {
                  auth.updateProfile(
                    restaurantInfo: model.RestaurantInfo(
                      logo: info?.logo ?? '',
                      status: info?.status ?? 'open',
                      minOrderAmount: info?.minOrderAmount ?? 0,
                      deliveryFee: info?.deliveryFee ?? 0,
                      menu: info?.menu ?? [],
                      cuisineType: info?.cuisineType ?? 'مشاوي',
                      firebaseNotifications: val,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ManageMenuScreen extends StatefulWidget {
  const ManageMenuScreen({super.key});

  @override
  _ManageMenuScreenState createState() => _ManageMenuScreenState();
}

class _ManageMenuScreenState extends State<ManageMenuScreen> {
  String _selectedCategoryFilter = 'الكل';

  final List<String> _categories = [
    'الكل',
    'وجبة رئيسية',
    'حلويات',
    'مشروبات',
    'مقبلات',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        Provider.of<RestaurantProvider>(
          context,
          listen: false,
        ).loadMenu(auth.currentUser!.id);
      }
    });
  }

  List<dynamic> _getFilteredMenu(List<dynamic> fullMenu) {
    if (_selectedCategoryFilter == 'الكل') return fullMenu;
    return fullMenu.where((p) {
      final cat = p.category;
      if (_selectedCategoryFilter == 'وجبة رئيسية') {
        return cat == 'mainCourse' || cat == 'وجبة رئيسية';
      }
      if (_selectedCategoryFilter == 'حلويات') {
        return cat == 'dessert' || cat == 'حلويات';
      }
      if (_selectedCategoryFilter == 'مشروبات') {
        return cat == 'drink' || cat == 'مشروبات';
      }
      if (_selectedCategoryFilter == 'مقبلات') {
        return cat == 'appetizer' || cat == 'مقبلات';
      }
      return true;
    }).toList();
  }

  String _getCategoryLabel(String? cat) {
    switch (cat) {
      case 'mainCourse':
      case 'وجبة رئيسية':
        return '🍔 وجبة رئيسية';
      case 'dessert':
      case 'حلويات':
        return '🍰 حلويات';
      case 'drink':
      case 'مشروبات':
        return '🥤 مشروبات';
      case 'appetizer':
      case 'مقبلات':
        return '🍟 مقبلات';
      default:
        return cat ?? 'وجبة';
    }
  }

  @override
  Widget build(BuildContext context) {
    final restProv = Provider.of<RestaurantProvider>(context);
    final filteredMenu = _getFilteredMenu(restProv.currentMenu);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة قائمة الطعام (المنيو)')),
      body: restProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Filter Pills
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      itemBuilder: (ctx, idx) {
                        final cat = _categories[idx];
                        final isSelected = _selectedCategoryFilter == cat;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategoryFilter = cat),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.grey.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Menu items summary bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'إجمالي الوجبات: ${filteredMenu.length}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _selectedCategoryFilter == 'الكل'
                            ? 'جميع التصنيفات'
                            : 'التصنيف: $_selectedCategoryFilter',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Menu Items List
                Expanded(
                  child: filteredMenu.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 72,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد وجبات في هذا التصنيف حالياً',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اضغط + لإضافة وجبتك الأولى',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: filteredMenu.length,
                          itemBuilder: (ctx, idx) {
                            final prod = filteredMenu[idx];
                            return _buildMenuItemCard(context, restProv, prod);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => Navigator.pushNamed(context, '/add-product'),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'إضافة وجبة جديدة',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(
    BuildContext context,
    RestaurantProvider restProv,
    dynamic prod,
  ) {
    final isAvailable = prod.isAvailable as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Food Image Banner
          Stack(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  prod.image,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.fastfood_rounded,
                        size: 54,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Availability Badge (Top-Right)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? Colors.green.withValues(alpha: 0.9)
                        : Colors.red.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    isAvailable ? '🟢 متوفر بالمنيو' : '🔴 مخفي من العرض',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Category Chip (Top-Left)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _getCategoryLabel(prod.category),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Meal Info Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        prod.name,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${prod.price.toStringAsFixed(0)} ل.س',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                if (prod.description != null &&
                    prod.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    prod.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // 3. Action Controls Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Toggle Availability Button
                    InkWell(
                      onTap: () => restProv.updateProductAvailability(
                        prod.id,
                        !isAvailable,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAvailable
                                ? Colors.orange.withValues(alpha: 0.3)
                                : Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: isAvailable ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAvailable
                                  ? 'إخفاء الوجبة من العرض'
                                  : 'إظهار الوجبة بالمنيو',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAvailable
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Delete Button with Dialog Confirmation
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      tooltip: 'حذف الوجبة',
                      onPressed: () =>
                          _confirmDeleteProduct(restProv, prod.id, prod.name),
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

  void _confirmDeleteProduct(
    RestaurantProvider restProv,
    String id,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف الوجبة'),
        content: Text(
          'هل أنت تأكد من رغبتك في حذف وجبة "$name" من قائمة الطعام؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await restProv.deleteProduct(id);
              if (err == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم حذف وجبة "$name" بنجاح')),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            },
            child: const Text('حذف الوجبة'),
          ),
        ],
      ),
    );
  }
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _imageController = TextEditingController(
    text: 'https://via.placeholder.com/150',
  );
  String _category = 'mainCourse';
  bool _isAvailable = true;

  @override
  Widget build(BuildContext context) {
    final restProv = Provider.of<RestaurantProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة وجبة جديدة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.primaryGradient().copyWith(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.restaurant_menu_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'أضف وجبة جديدة للمنيو',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'أدخل تفاصيل الوجبة لعرضها في قائمتك',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات الوجبة',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الوجبة',
                          prefixIcon: Icon(Icons.fastfood_rounded),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال اسم الوجبة' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر (ل.س)',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال السعر' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'وصف الوجبة (اختياري)',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _imageController,
                        decoration: const InputDecoration(
                          labelText: 'رابط صورة الوجبة',
                          prefixIcon: Icon(Icons.image_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعدادات الوجبة',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _category,
                        decoration: const InputDecoration(
                          labelText: 'التصنيف',
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'mainCourse',
                            child: Text('وجبة رئيسية'),
                          ),
                          DropdownMenuItem(
                            value: 'dessert',
                            child: Text('حلويات'),
                          ),
                          DropdownMenuItem(
                            value: 'drink',
                            child: Text('مشروبات'),
                          ),
                          DropdownMenuItem(
                            value: 'appetizer',
                            child: Text('مقبلات'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الوجبة متوفرة حالياً بالمنيو'),
                        subtitle: Text(
                          _isAvailable ? 'ستظهر للعملاء' : 'مخفية من العملاء',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            color: _isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                        value: _isAvailable,
                        onChanged: (val) => setState(() => _isAvailable = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              restProv.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: () => _submit(restProv),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('إضافة الوجبة'),
                    ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(RestaurantProvider restProv) async {
    if (!_formKey.currentState!.validate()) return;
    final err = await restProv.addProduct(
      name: _nameController.text,
      price: double.tryParse(_priceController.text) ?? 0,
      image: _imageController.text,
      category: _category,
      description: _descController.text,
      isAvailable: _isAvailable,
    );

    if (err == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إضافة الوجبة للمنيو!')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

class CompletedOrdersScreen extends StatefulWidget {
  const CompletedOrdersScreen({super.key});

  @override
  _CompletedOrdersScreenState createState() => _CompletedOrdersScreenState();
}

class _CompletedOrdersScreenState extends State<CompletedOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final allCompletedOrders = orderProv.orders
        .where((o) => o.status == 'delivered')
        .toList();

    final double salesVolume = allCompletedOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );

    // Apply search filter by Order ID if entered
    List<model.Order> filteredOrders = allCompletedOrders;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      filteredOrders = filteredOrders.where((o) {
        return o.id.toLowerCase().contains(q);
      }).toList();
    }

    // Restrict display to the LAST 20 completed orders as requested
    final displayedOrders = filteredOrders.take(20).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات المكتملة 🟢')),
      body: RefreshIndicator(
        onRefresh: () => orderProv.loadOrders(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary Header Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: AppTheme.primaryGradient().copyWith(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'إجمالي المبيعات المكتملة',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${salesVolume.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'إجمالي المكتملة: ${allCompletedOrders.length} طلب (عرض أحدث 20 طلب)',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar for Order ID (البحث برقم الطلب)
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'البحث برقم الطلب (أدخل رقم الطلب)...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.primary,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (displayedOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 72,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد طلبات مكتملة تطابق رقم الطلب "$_searchQuery"'
                            : 'لا توجد طلبات مكتملة حالياً',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...displayedOrders.map((order) {
                return _CompletedOrderCard(order: order);
              }),
          ],
        ),
      ),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  final model.Order order;
  const _CompletedOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isWallet = order.paymentMethod == 'wallet';

    String customerName = 'زبون المطعم';
    if (order.customerId is model.User) {
      customerName = (order.customerId as model.User).name;
    } else if (order.customerId is Map) {
      customerName = order.customerId['name'] ?? 'زبون المطعم';
    }

    final addressStr = [
      order.deliveryAddress.region,
      order.deliveryAddress.details ?? order.deliveryAddress.street,
      order.deliveryAddress.governorate,
    ].where((s) => s != null && s.isNotEmpty).join(' - ');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Order ID, Payment Badge, Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '#${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isWallet
                            ? Colors.purple.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isWallet ? '💳 محفظة' : '💵 كاش',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isWallet ? Colors.purple : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'مكتمل ومسلّم 🟢',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Customer Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_pin_circle_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'العميل: $customerName',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (addressStr.isNotEmpty)
                          Text(
                            'عنوان التوصيل: $addressStr',
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Items List
            const Text(
              'الوجبات المطلوبة:',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: order.items
                    .map(
                      (it) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '×${it.quantity}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                it.name,
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${(it.price * it.quantity).toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'إجمالي المبلغ المستلم:',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${order.totalAmount.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
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
