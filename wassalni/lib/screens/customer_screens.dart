// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/providers.dart';
import '../models/models.dart' as model;
import '../core/theme.dart';
import '../core/services.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  String _selectedCategory = 'الكل';
  final List<String> _categories = [
    'الكل',
    'مشروبات',
    'حلويات',
    'مشاوي',
    'شاورما فروج',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<RestaurantProvider>(context, listen: false).loadRestaurants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final restProv = Provider.of<RestaurantProvider>(context);

    // Filter restaurants locally based on category
    final filteredRestaurants = _selectedCategory == 'الكل'
        ? restProv.restaurants
        : restProv.restaurants
              .where((r) => r.restaurantInfo?.cuisineType == _selectedCategory)
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('تطبيق وصلني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            onPressed: () => Navigator.pushNamed(context, '/customer-orders'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => restProv.loadRestaurants(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card with Balance
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumGradientDeco().copyWith(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً بك، ${auth.currentUser?.name} 👋',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'الرصيد الحالي:',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Category filter pills
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
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
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'المطاعم المتاحة',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              restProv.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredRestaurants.isEmpty
                  ? const Center(
                      child: Text('لا توجد مطاعم نشطة تحت هذا التصنيف حالياً'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredRestaurants.length,
                      itemBuilder: (context, index) {
                        final rest = filteredRestaurants[index];
                        final info = rest.restaurantInfo;
                        if (info == null) return const SizedBox();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/restaurant-detail',
                                arguments: rest,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      info.logo,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.restaurant,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rest.name,
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${info.cuisineType} • ${info.description ?? 'لا يوجد وصف'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: info.status == 'open'
                                                    ? Colors.green.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.red.withOpacity(
                                                        0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                info.status == 'open'
                                                    ? 'مفتوح'
                                                    : 'مغلق',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: info.status == 'open'
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(
                                              Icons.delivery_dining_rounded,
                                              size: 16,
                                              color: AppTheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${info.deliveryFee.toStringAsFixed(0)} ل.س',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/cart'),
        backgroundColor: AppTheme.primary,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.shopping_cart_rounded, color: Colors.white),
            Positioned(
              right: 0,
              top: 0,
              child: Consumer<CartProvider>(
                builder: (context, cart, child) {
                  if (cart.itemCount == 0) return const SizedBox();
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cart.itemCount}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

class RestaurantDetailScreen extends StatefulWidget {
  final model.User restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  _RestaurantDetailScreenState createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<RestaurantProvider>(
        context,
        listen: false,
      ).loadMenu(widget.restaurant.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final restProv = Provider.of<RestaurantProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final info = widget.restaurant.restaurantInfo!;

    // Hide products that are not available (isAvailable == false)
    final availableMenu = restProv.currentMenu
        .where((p) => p.isAvailable)
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.restaurant.name),
              background: Image.network(
                info.logo,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تصنيف المطعم: ${info.cuisineType}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.description ?? 'لا يوجد وصف للمطعم',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الحد الأدنى للطلب: ${info.minOrderAmount.toStringAsFixed(0)} ل.س',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'رسوم التوصيل: ${info.deliveryFee.toStringAsFixed(0)} ل.س',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'قائمة المأكولات',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          restProv.isLoading
              ? const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                )
              : availableMenu.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('لا توجد وجبات متوفرة حالياً'),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final prod = availableMenu[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                prod.image,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.fastfood,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (prod.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      prod.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    '${prod.price.toStringAsFixed(0)} ل.س',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppTheme.primary,
                                size: 28,
                              ),
                              onPressed: () {
                                if (info.status != 'open') {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'المطعم مغلق حالياً ولا يقبل الطلبات',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final success = cart.addItem(prod);
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تمت إضافة ${prod.name} إلى السلة',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'لا يمكنك إضافة منتجات من مطاعم مختلفة إلى نفس السلة. يرجى إفراغ السلة أولاً.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: availableMenu.length),
                ),
        ],
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  model.Address? _selectedSavedAddress;
  bool _useSavedAddress = true;
  Position? _detectedPosition;
  bool _gpsDetermined = false;
  bool _saveToProfile = false;
  final _addressLabelController = TextEditingController();

  String? _houseDoorBase64;
  File? _imageFile;

  final ImagePicker _picker = ImagePicker();
  final String _paymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.currentUser != null) {
        if (auth.currentUser!.addresses.isNotEmpty) {
          setState(() {
            _selectedSavedAddress = auth.currentUser!.addresses.first;
            _useSavedAddress = true;
          });
        } else {
          setState(() {
            _useSavedAddress = false;
          });
        }
      }
    });
  }

  Future<void> _pickDoorImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _imageFile = File(pickedFile.path);
        _houseDoorBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _determineGPSPosition() async {
    final permissionError = await LocationHelper.checkAndRequestPermissions();
    if (permissionError != null) {
      String msg = 'حدث خطأ في صلاحية الموقع';
      if (permissionError == 'GPS_DISABLED') {
        msg = 'الرجاء تفعيل خدمة تحديد الموقع (GPS)';
      } else if (permissionError == 'GPS_DENIED') {
        msg = 'تم رفض صلاحية تحديد موقعك الجغرافي';
      } else if (permissionError == 'GPS_DENIED_FOREVER') {
        msg = 'صلاحية الموقع مرفوضة دائماً، الرجاء تفعيلها من الإعدادات';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري تحديد موقعك الجغرافي بالـ GPS...'),
          ],
        ),
      ),
    );

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      Navigator.pop(context);
      setState(() {
        _detectedPosition = pos;
        _gpsDetermined = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديد موقع الـ GPS بنجاح!')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final orderProv = Provider.of<OrderProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('سلة المشتريات')),
      body: cart.items.isEmpty
          ? const Center(child: Text('السلة فارغة!'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, index) {
                      final item = cart.items.values.toList()[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(item.product.name),
                          subtitle: Text(
                            '${item.product.price.toStringAsFixed(0)} ل.س × ${item.quantity}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () =>
                                    cart.removeItem(item.product.id),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  final success = cart.addItem(item.product);
                                  if (!success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'لا يمكنك إضافة منتجات من مطاعم مختلفة إلى نفس السلة.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'موقع التوصيل',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Option 1: Saved locations dropdown
                          if (auth.currentUser?.addresses.isNotEmpty ==
                              true) ...[
                            DropdownButtonFormField<model.Address>(
                              value: _useSavedAddress
                                  ? _selectedSavedAddress
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'اختر من مواقعك المخزنة',
                                prefixIcon: const Icon(Icons.bookmark_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              items: auth.currentUser!.addresses.map((addr) {
                                return DropdownMenuItem<model.Address>(
                                  value: addr,
                                  child: Text(
                                    '${addr.label ?? "موقع"} (${addr.governorate ?? ""} - ${addr.region ?? ""})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (addr) {
                                setState(() {
                                  _selectedSavedAddress = addr;
                                  _useSavedAddress = true;
                                  _gpsDetermined = false;
                                  _detectedPosition = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'أو',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Option 2: GPS location button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _gpsDetermined
                                    ? Colors.green
                                    : AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () async {
                                await _determineGPSPosition();
                                if (_gpsDetermined) {
                                  setState(() {
                                    _useSavedAddress = false;
                                    _selectedSavedAddress = null;
                                  });
                                }
                              },
                              icon: Icon(
                                _gpsDetermined
                                    ? Icons.check_circle
                                    : Icons.my_location,
                                size: 22,
                              ),
                              label: Text(
                                _gpsDetermined
                                    ? 'تم تحديد موقعي بنجاح ✓'
                                    : '📍 موقعي الحالي (GPS)',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          // Save to profile option (only when GPS is used)
                          if (_gpsDetermined && !_useSavedAddress) ...[
                            const SizedBox(height: 12),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'حفظ هذا الموقع في حسابي للمرات القادمة',
                              ),
                              value: _saveToProfile,
                              onChanged: (val) {
                                setState(() {
                                  _saveToProfile = val ?? false;
                                });
                              },
                            ),
                            if (_saveToProfile) ...[
                              TextField(
                                controller: _addressLabelController,
                                decoration: InputDecoration(
                                  labelText: 'اسم الموقع (مثال: بيتي - المحل)',
                                  prefixIcon: const Icon(Icons.label_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ],

                          const Divider(height: 32),
                          const Text(
                            'صورة باب المنزل أو المكان (للأمان):',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (_imageFile != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _imageFile!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _pickDoorImage,
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: Text(
                                _imageFile != null
                                    ? 'تغيير الصورة'
                                    : 'التقاط صورة للباب',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'طريقة الدفع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RadioListTile<String>(
                            title: const Text('نقداً (Cash)'),
                            value: 'cash',
                          ),
                          RadioListTile<String>(
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('المحفظة الإلكترونية (Wallet)'),
                                Text(
                                  'رصيدك: ${auth.currentUser?.balance.toStringAsFixed(0) ?? "0"} ل.س',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            value: 'wallet',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي:'),
                          Text(
                            '${cart.totalAmount.toStringAsFixed(0)} ل.س',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      orderProv.isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: () => _checkout(cart, orderProv),
                              child: const Text('تأكيد الطلب (شراء)'),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _checkout(CartProvider cart, OrderProvider orderProv) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    model.Address finalDeliveryAddress;

    if (_useSavedAddress && _selectedSavedAddress != null) {
      finalDeliveryAddress = _selectedSavedAddress!;
    } else if (_gpsDetermined && _detectedPosition != null) {
      finalDeliveryAddress = model.Address(
        label: _saveToProfile
            ? _addressLabelController.text.trim()
            : 'موقع GPS',
        location: model.Location(
          coordinates: [
            _detectedPosition!.longitude,
            _detectedPosition!.latitude,
          ],
        ),
      );

      if (_saveToProfile) {
        final label = _addressLabelController.text.trim();
        if (label.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى تسمية الموقع (مثال: بيتي)')),
          );
          return;
        }
        finalDeliveryAddress = model.Address(
          label: label,
          location: model.Location(
            coordinates: [
              _detectedPosition!.longitude,
              _detectedPosition!.latitude,
            ],
          ),
        );
        final errSave = await auth.addCustomerAddress(finalDeliveryAddress);
        if (errSave != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل حفظ الموقع: $errSave')));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى تحديد موقعك عبر GPS أو اختيار موقع مخزن'),
        ),
      );
      return;
    }

    final firstItem = cart.items.values.first;
    final restaurantId = firstItem.product.restaurantId;

    final items = cart.items.values
        .map(
          (x) => model.OrderItem(
            productId: x.product.id,
            name: x.product.name,
            quantity: x.quantity,
            price: x.product.price,
          ),
        )
        .toList();

    final err = await orderProv.createOrder(
      restaurantId: restaurantId,
      items: items,
      totalAmount: cart.totalAmount,
      deliveryAddress: model.Address(
        label: finalDeliveryAddress.label,
        governorate: finalDeliveryAddress.governorate,
        region: finalDeliveryAddress.region,
        details: finalDeliveryAddress.details,
        street: finalDeliveryAddress.street,
        city: finalDeliveryAddress.city,
        location: finalDeliveryAddress.location,
        houseDoorPicture: _houseDoorBase64,
      ),
      paymentMethod: _paymentMethod,
    );

    if (err == null) {
      cart.clear();
      await auth.tryAutoLogin(); // Update local wallet balance
      Navigator.pushReplacementNamed(context, '/customer-orders');
    } else {
      if (err == 'GPS_DISABLED') {
        _showGpsWarning(
          'خدمات الـ GPS معطلة. يرجى تفعيل الـ GPS لإكمال عملية الشراء.',
        );
      } else if (err == 'GPS_DENIED' || err == 'GPS_DENIED_FOREVER') {
        _showGpsWarning(
          'صلاحية الوصول للموقع معطلة. يرجى إعطاء صلاحية الموقع للتطبيق.',
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
    }
  }

  void _showGpsWarning(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تنبيه الموقع (GPS)'),
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
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  _CustomerOrdersScreenState createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
      Provider.of<OrderProvider>(context, listen: false).setupSocketListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: orderProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderProv.orders.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة'))
          : ListView.builder(
              itemCount: orderProv.orders.length,
              itemBuilder: (ctx, idx) {
                final order = orderProv.orders[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      'طلب رقم: ${order.id.substring(order.id.length - 6)}',
                    ),
                    subtitle: Text(
                      'الحالة: ${_getStatusText(order.status)}\nالإجمالي: ${order.totalAmount} ل.س',
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => OrderTrackScreen(order: order),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
      case 'restaurant_accepted':
        return 'تم قبول الطلب من المطعم';
      case 'delivery_accepted':
        return 'تم قبول التوصيل من السائق';
      case 'preparing':
        return 'يتم التحضير بالمطعم';
      case 'ready':
        return 'جاهز للتوصيل وبانتظار السائق';
      case 'onTheWay':
        return 'في الطريق إليك';
      case 'delivered':
        return 'تم التوصيل بنجاح';
      case 'cancelled':
        return 'تم الإلغاء';
      default:
        return status;
    }
  }
}

class OrderTrackScreen extends StatefulWidget {
  final model.Order order;

  const OrderTrackScreen({super.key, required this.order});

  @override
  _OrderTrackScreenState createState() => _OrderTrackScreenState();
}

class _OrderTrackScreenState extends State<OrderTrackScreen> {
  String? _receivedBase64;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Listen for delivery confirmation from driver
    SocketService.socket?.on('orderStatus', _handleOrderStatusChange);
  }

  @override
  void dispose() {
    SocketService.socket?.off('orderStatus', _handleOrderStatusChange);
    super.dispose();
  }

  void _handleOrderStatusChange(dynamic data) {
    final orderId = data['orderId'] ?? data['_id'];
    final status = data['status'];
    if (orderId == widget.order.id &&
        status == 'delivered_pending' &&
        mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(
            Icons.delivery_dining,
            color: Colors.orange,
            size: 64,
          ),
          title: const Text('وصل الكابتن! 🚗'),
          content: const Text('هل استلمت الطلب من عامل التوصيل؟'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: const Text('ليس بعد'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.pop(ctx);
                Provider.of<OrderProvider>(context, listen: false).loadOrders();
              },
              child: const Text('نعم، استلمت الطلب'),
            ),
          ],
        ),
      );
    } else if (orderId == widget.order.id && status == 'delivered' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الاستلام وتوصيل الطلب بنجاح!')),
      );
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
    }
  }

  Future<void> _pickReceiptImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _imageFile = File(pickedFile.path);
        _receivedBase64 = base64Encode(bytes);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تتبع طلبك')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              'حالة الطلب: ${_getStatusText(widget.order.status)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: [
                  _buildStep(
                    context,
                    'تم استلام الطلب',
                    [
                      'pending',
                      'accepted',
                      'restaurant_accepted',
                      'preparing',
                      'ready',
                      'delivery_accepted',
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(widget.order.status),
                  ),
                  _buildStep(
                    context,
                    'تم القبول ويتم التحضير',
                    [
                      'accepted',
                      'restaurant_accepted',
                      'preparing',
                      'ready',
                      'delivery_accepted',
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(widget.order.status),
                  ),
                  _buildStep(
                    context,
                    'الطلب جاهز وبانتظار السائق',
                    [
                      'ready',
                      'delivery_accepted',
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(widget.order.status),
                  ),
                  _buildStep(
                    context,
                    'السائق في الطريق إليك',
                    [
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(widget.order.status),
                  ),
                  _buildStep(
                    context,
                    'تم التوصيل بنجاح',
                    widget.order.status == 'delivered',
                  ),

                  if (widget.order.status == 'delivered_pending') ...[
                    const Divider(height: 48),
                    const Text(
                      'الرجاء التقاط صورة للطلب قبل استلامه للأمان وتأكيد الاستلام:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickReceiptImage,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _imageFile != null
                            ? 'تغيير صورة الطلب المستلم'
                            : 'تصوير الطلب المستلم',
                      ),
                    ),
                    if (_imageFile != null) ...[
                      const SizedBox(height: 12),
                      Image.file(_imageFile!, height: 120, fit: BoxFit.cover),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () => _confirmReceipt(orderProv),
                        child: const Text('نعم، استلمت الطلب (تأكيد)'),
                      ),
                    ],
                  ] else if (widget.order.status == 'delivered') ...[
                    const Divider(height: 48),
                    const Center(
                      child: Text(
                        'تم تأكيد استلام الطلب وتوصيله بنجاح ✓',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReceipt(OrderProvider orderProv) async {
    if (_receivedBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تصوير الطلب لتأكيد استلامه')),
      );
      return;
    }
    final err = await orderProv.customerConfirmDelivery(
      widget.order.id,
      receivedPicture: _receivedBase64,
    );
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد استلام الطلب بنجاح. شكراً لك!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Widget _buildStep(BuildContext context, String title, bool isDone) {
    return ListTile(
      leading: Icon(
        isDone ? Icons.check_circle : Icons.radio_button_off,
        color: isDone ? Colors.green : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'accepted':
      case 'restaurant_accepted':
        return 'تم قبول الطلب من المطعم';
      case 'delivery_accepted':
        return 'تم قبول التوصيل من السائق';
      case 'preparing':
        return 'يتم التحضير بالمطعم';
      case 'ready':
        return 'جاهز للتوصيل وبانتظار السائق';
      case 'onTheWay':
        return 'في الطريق إليك';
      case 'delivered_pending':
        return 'وصل السائق وبانتظار تأكيدك';
      case 'delivered':
        return 'تم التوصيل بنجاح';
      case 'cancelled':
        return 'تم الإلغاء';
      default:
        return status;
    }
  }
}
