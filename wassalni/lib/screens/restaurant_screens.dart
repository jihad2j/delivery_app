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
              ),
              const SizedBox(width: 12),
              _buildStatCounter(
                context,
                'قيد التحضير',
                preparingCount,
                Colors.orange,
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
    Color color,
  ) {
    return Expanded(
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
    );
  }

  // Order Management (إدارة الطلبات)
  Widget _buildOrderManagement(OrderProvider orderProv) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'جديدة'),
              Tab(text: 'قيد التحضير'),
              Tab(text: 'جاهزة للتوصيل'),
              Tab(text: 'مكتملة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOrderList(orderProv, 'pending'),
                _buildOrderList(orderProv, 'preparing'),
                _buildOrderList(orderProv, 'ready'),
                _buildOrderList(orderProv, 'delivered'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(OrderProvider orderProv, String status) {
    final List<model.Order> list;
    if (status == 'preparing') {
      list = orderProv.orders
          .where(
            (o) =>
                o.status == 'restaurant_accepted' ||
                o.status == 'delivery_accepted' ||
                o.status == 'preparing',
          )
          .toList();
    } else {
      list = orderProv.orders.where((o) => o.status == status).toList();
    }
    if (list.isEmpty) {
      return const Center(child: Text('لا توجد طلبات في هذه الحالة حالياً'));
    }

    return ListView.builder(
      itemCount: list.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, idx) {
        final order = list[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'طلب #${order.id.substring(order.id.length - 6)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${order.totalAmount} ل.س',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...order.items.map(
                  (it) => Text('• ${it.name} × ${it.quantity}'),
                ),
                const Divider(),
                _buildOrderActionButtons(orderProv, order),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderActionButtons(OrderProvider orderProv, model.Order order) {
    if (order.status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 40)),
            onPressed: () =>
                orderProv.updateStatus(order.id, 'restaurant_accepted'),
            child: const Text('قبول الطلب'),
          ),
        ],
      );
    }
    if (order.status == 'restaurant_accepted') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(120, 40),
            ),
            onPressed: () => orderProv.updateStatus(order.id, 'preparing'),
            child: const Text('بدء التحضير'),
          ),
        ],
      );
    }
    if (order.status == 'preparing') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(120, 40),
            ),
            onPressed: () => _markAsReadyWithPicture(orderProv, order.id),
            child: const Text('جاهز للتوصيل (تغليف الطلب)'),
          ),
        ],
      );
    }
    if (order.status == 'ready') {
      return const Row(
        children: [
          Icon(Icons.directions_bike, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            'جاري رصد وبحث كابتن توصيل قريب...',
            style: TextStyle(color: Colors.blue),
          ),
        ],
      );
    }
    if (order.status == 'delivery_accepted') {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text(
            'تم قبول الطلب من قبل الكابتن وهو في الطريق للمطعم',
            style: TextStyle(color: Colors.green),
          ),
        ],
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
