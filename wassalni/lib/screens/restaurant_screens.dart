// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

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
  int _tabIndex = 0; // 0: Dashboard, 1: Orders, 2: Settings
  String _selectedFilter = 'all'; // 'all', 'pending', 'preparing', 'ready', 'delivered'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders();
      orderProv.setupSocketListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storefront, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(auth.currentUser?.name ?? 'المطعم'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restaurant_menu_rounded),
            onPressed: () => Navigator.pushNamed(context, '/manage-menu'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _buildSelectedTab(auth, orderProv),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (idx) => setState(() => _tabIndex = idx),
        selectedItemColor: AppTheme.primary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'إدارة الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'الإعدادات',
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
            decoration: AppTheme.premiumGradientDeco().copyWith(
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
                  color: Colors.green.withOpacity(0.05),
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
                    setState(() {
                      _tabIndex = 1;
                      _selectedFilter = 'delivered';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    color: Colors.blue.withOpacity(0.05),
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
                    _selectedFilter = 'pending';
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
                    _selectedFilter = 'preparing';
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

  // Modern Kitchen Order Management - Unified Single-Page View (إدارة الطلبات في صفحة واحدة)
  Widget _buildOrderManagement(OrderProvider orderProv) {
    final newOrders = orderProv.orders.where((o) => o.status == 'pending').toList();
    final preparingOrders = orderProv.orders
        .where(
          (o) =>
              o.status == 'restaurant_accepted' ||
              o.status == 'delivery_accepted' ||
              o.status == 'preparing',
        )
        .toList();
    final readyOrders = orderProv.orders.where((o) => o.status == 'ready').toList();
    final completedOrders = orderProv.orders.where((o) => o.status == 'delivered').toList();

    return Column(
      children: [
        // Quick Filter Bar at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل (في صفحة واحدة)', 'all', orderProv.orders.length, AppTheme.primary),
                const SizedBox(width: 8),
                _buildFilterChip('جديدة', 'pending', newOrders.length, AppTheme.error),
                const SizedBox(width: 8),
                _buildFilterChip('قيد التحضير', 'preparing', preparingOrders.length, AppTheme.warning),
                const SizedBox(width: 8),
                _buildFilterChip('جاهزة للتوصيل', 'ready', readyOrders.length, AppTheme.accent),
                const SizedBox(width: 8),
                _buildFilterChip('مكتملة', 'delivered', completedOrders.length, Colors.green),
              ],
            ),
          ),
        ),

        // Main Unified Body showing all order statuses on the same page
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => orderProv.loadOrders(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_selectedFilter == 'all' || _selectedFilter == 'pending')
                  _buildStatusSection(
                    title: 'الطلبات الجديدة',
                    icon: Icons.new_releases_rounded,
                    color: AppTheme.error,
                    orders: newOrders,
                    emptyMessage: 'لا توجد طلبات جديدة حالياً',
                    orderProv: orderProv,
                  ),

                if (_selectedFilter == 'all' || _selectedFilter == 'preparing')
                  _buildStatusSection(
                    title: 'قيد التحضير',
                    icon: Icons.soup_kitchen_rounded,
                    color: AppTheme.warning,
                    orders: preparingOrders,
                    emptyMessage: 'لا توجد طلبات قيد التحضير حالياً',
                    orderProv: orderProv,
                  ),

                if (_selectedFilter == 'all' || _selectedFilter == 'ready')
                  _buildStatusSection(
                    title: 'جاهزة للتوصيل',
                    icon: Icons.takeout_dining_rounded,
                    color: AppTheme.accent,
                    orders: readyOrders,
                    emptyMessage: 'لا توجد طلبات جاهزة للتوصيل حالياً',
                    orderProv: orderProv,
                  ),

                if (_selectedFilter == 'all' || _selectedFilter == 'delivered')
                  _buildStatusSection(
                    title: 'الطلبات المكتملة',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    orders: completedOrders,
                    emptyMessage: 'لا توجد طلبات مكتملة حالياً',
                    orderProv: orderProv,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String filterKey, int count, Color color) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: color.withOpacity(0.18),
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: isSelected ? color : Colors.grey.withOpacity(0.3),
        width: isSelected ? 1.8 : 1,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<model.Order> orders,
    required String emptyMessage,
    required OrderProvider orderProv,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(top: 8, bottom: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${orders.length}',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Section Content
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.inbox_outlined, size: 20, color: Colors.grey[400]),
                const SizedBox(width: 10),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...orders.map((order) => _buildOrderCard(orderProv, order)),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildOrderCard(OrderProvider orderProv, model.Order order) {
    final isWallet = order.paymentMethod == 'wallet';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassmorphismDeco(cardColor: Theme.of(context).cardColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Order ID, Payment Method Badge, Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isWallet ? Colors.purple.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isWallet ? '💳 محفظة' : '💵 كاش',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isWallet ? Colors.purple : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${order.totalAmount.toStringAsFixed(0)} ل.س',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('الأصناف المطلوبة:', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          ...order.items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('×${it.quantity}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(it.name, style: const TextStyle(fontFamily: 'Outfit', fontSize: 15))),
                  Text('${(it.price * it.quantity).toStringAsFixed(0)} ل.س', style: const TextStyle(fontFamily: 'Outfit', color: Colors.grey)),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          _buildOrderActionButtons(orderProv, order),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.bolt_rounded, color: Colors.white),
            onPressed: () => orderProv.updateStatus(order.id, 'restaurant_accepted'),
            label: const Text('قبول الطلب', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.white),
            onPressed: () => orderProv.updateStatus(order.id, 'preparing'),
            label: const Text('بدء التحضير', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.takeout_dining_rounded, color: Colors.white),
            onPressed: () => _markAsReadyWithPicture(orderProv, order.id),
            label: const Text('تغليف وجاهز للتوصيل', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }
    if (order.status == 'ready') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.radar_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'الطلب جاهز! جاري رصد وبحث كابتن توصيل قريب...',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.blue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (order.status == 'delivery_accepted') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم قبول الطلب من قبل الكابتن وهو في الطريق للمطعم',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    if (order.status == 'delivered') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم توصيل هذا الطلب للعميل واستلامه بنجاح 🟢',
                style: TextStyle(fontFamily: 'Outfit', color: Colors.green, fontWeight: FontWeight.w600),
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<RestaurantProvider>(
        context,
        listen: false,
      ).loadMenu(auth.currentUser!.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final restProv = Provider.of<RestaurantProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة قائمة الطعام')),
      body: restProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : restProv.currentMenu.isEmpty
          ? const Center(child: Text('لا توجد وجبات في المنيو الخاص بك'))
          : ListView.builder(
              itemCount: restProv.currentMenu.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (ctx, idx) {
                final prod = restProv.currentMenu[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        prod.image,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                        ),
                      ),
                    ),
                    title: Text(prod.name),
                    subtitle: Text('${prod.price.toStringAsFixed(0)} ل.س'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show/Hide meal switch
                        Switch(
                          value: prod.isAvailable,
                          onChanged: (val) {
                            restProv.updateProductAvailability(prod.id, val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteProduct(restProv, prod.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => Navigator.pushNamed(context, '/add-product'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _deleteProduct(RestaurantProvider restProv, String id) async {
    final err = await restProv.deleteProduct(id);
    if (err == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الوجبة بنجاح')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم الوجبة'),
                validator: (v) => v!.isEmpty ? 'يرجى إدخال اسم الوجبة' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'السعر (ل.س)'),
                validator: (v) => v!.isEmpty ? 'يرجى إدخال السعر' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'وصف الوجبة'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _imageController,
                decoration: const InputDecoration(
                  labelText: 'رابط صورة الوجبة',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: const [
                  DropdownMenuItem(
                    value: 'mainCourse',
                    child: Text('وجبة رئيسية'),
                  ),
                  DropdownMenuItem(value: 'dessert', child: Text('حلويات')),
                  DropdownMenuItem(value: 'drink', child: Text('مشروبات')),
                  DropdownMenuItem(value: 'appetizer', child: Text('مقبلات')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('الوجبة متوفرة حالياً بالمنيو'),
                value: _isAvailable,
                onChanged: (val) => setState(() => _isAvailable = val),
              ),
              const SizedBox(height: 40),
              restProv.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () => _submit(restProv),
                      child: const Text('إضافة الوجبة'),
                    ),
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
