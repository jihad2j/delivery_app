// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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
        centerTitle: false,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'الرصيد: ${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                style: const TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'طلباتي',
            onPressed: () => Navigator.pushNamed(context, '/customer-orders'),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'الملف الشخصي',
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
              // Welcome Header Card
              const SizedBox(height: 44),
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
                                : Colors.grey.withValues(alpha: 0.2),
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
                          margin: const EdgeInsets.only(bottom: 20),
                          clipBehavior: Clip.antiAlias,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/restaurant-detail',
                                arguments: rest,
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Full Width Restaurant Image
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 170,
                                      width: double.infinity,
                                      child: Image.network(
                                        info.logo,
                                        width: double.infinity,
                                        height: 170,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(
                                              Icons.restaurant_rounded,
                                              size: 50,
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
                                              Colors.black.withValues(
                                                alpha: 0.15,
                                              ),
                                              Colors.transparent,
                                              Colors.black.withValues(
                                                alpha: 0.4,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Top-Right Status Badge (مفتوح / مغلق)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: info.status == 'open'
                                              ? Colors.green.withValues(
                                                  alpha: 0.9,
                                                )
                                              : Colors.red.withValues(
                                                  alpha: 0.9,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              info.status == 'open'
                                                  ? Icons.check_circle_rounded
                                                  : Icons.cancel_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              info.status == 'open'
                                                  ? 'مفتوح'
                                                  : 'مغلق',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Cuisine Chip on Image
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.restaurant_menu_rounded,
                                              color: Colors.orangeAccent,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              info.cuisineType,
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // 2. Underneath Image: Name, Cuisine, Address, Status & Delivery Info
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Restaurant Name
                                      Text(
                                        rest.name,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // Type of Cuisine & Description
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.fastfood_outlined,
                                            size: 16,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'نوع الطعام: ${info.cuisineType} • ${info.description ?? "أشهى الوجبات والمأكولات"}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Restaurant Address
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_rounded,
                                            size: 16,
                                            color: Colors.redAccent,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'العنوان: ${rest.address?.city ?? "دمشق"} - ${rest.address?.street ?? "الشارع الرئيسي"}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      const Divider(height: 1),
                                      const SizedBox(height: 12),
                                      // Footer: Delivery fee + Action
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.delivery_dining_rounded,
                                                size: 20,
                                                color: AppTheme.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'توصيل: ${info.deliveryFee.toStringAsFixed(0)} ل.س',
                                                style: const TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Row(
                                            children: [
                                              Text(
                                                'عرض المنيو والطلب',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.secondary,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 12,
                                                color: AppTheme.secondary,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
                  const Divider(height: 22),
                  const Text(
                    'قائمة المأكولات',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
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
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final prod = availableMenu[index];
                      final isRestaurantOpen = info.status == 'open';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        clipBehavior: Clip.antiAlias,
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              // 1. Food Image covering the ENTIRE card
                              Positioned.fill(
                                child: Image.network(
                                  prod.image,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        size: 60,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Dark Gradient Overlay over image for text contrast
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.4),
                                        Colors.black.withValues(alpha: 0.1),
                                        Colors.black.withValues(alpha: 0.88),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // 3. Top-Right Corner Badge: Price (السعر)
                              Positioned(
                                top: 14,
                                right: 14,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${prod.price.toStringAsFixed(0)} ل.س',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),

                              // 4. Top-Left Corner: Add to Cart Icon Button (زر أيقونة إضافة للسلة)
                              Positioned(
                                top: 14,
                                left: 14,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () {
                                      if (!isRestaurantOpen) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'تمت إضافة "${prod.name}" إلى السلة 🛒',
                                            ),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                            action: SnackBarAction(
                                              label: 'السلة',
                                              textColor: Colors.amber,
                                              onPressed: () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/cart',
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'لا يمكنك إضافة منتجات من مطاعم مختلفة إلى نفس السلة. يرجى إفراغ السلة أولاً.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRestaurantOpen
                                            ? AppTheme.primary
                                            : Colors.grey,
                                        shape: BoxShape.circle,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add_shopping_cart_rounded,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 5. Bottom Overlay: Name (اسم الوجبة) & Description (الوصف)
                              Positioned(
                                bottom: 14,
                                left: 16,
                                right: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      prod.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (prod.description != null &&
                                        prod.description!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        prod.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 13,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 4,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
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
                    }, childCount: availableMenu.length),
                  ),
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
                                    color: Colors.grey.withValues(alpha: 0.4),
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
                                    color: Colors.grey.withValues(alpha: 0.4),
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
              padding: const EdgeInsets.all(16),
              itemBuilder: (ctx, idx) {
                final order = orderProv.orders[idx];
                final statusColor = _getStatusColor(order.status);
                final statusIcon = _getStatusIcon(order.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => OrderTrackScreen(order: order),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Order ID + Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '#${order.id.substring(order.id.length - 6)}',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${order.totalAmount.toStringAsFixed(0)} \u0644.\u0633',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Items summary
                            Text(
                              order.items
                                  .map(
                                    (it) => '${it.name} \u00d7${it.quantity}',
                                  )
                                  .join(' \u2022 '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Status badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getStatusText(order.status),
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'restaurant_accepted':
        return AppTheme.primary;
      case 'delivery_accepted':
        return Colors.blue;
      case 'preparing':
        return AppTheme.warning;
      case 'ready':
        return AppTheme.accent;
      case 'onTheWay':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'accepted':
      case 'restaurant_accepted':
        return Icons.restaurant_rounded;
      case 'delivery_accepted':
        return Icons.delivery_dining_rounded;
      case 'preparing':
        return Icons.soup_kitchen_rounded;
      case 'ready':
        return Icons.takeout_dining_rounded;
      case 'onTheWay':
        return Icons.directions_car_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.info_outline_rounded;
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

  late model.Order _currentOrder;
  LatLng? _driverLatLng;
  LatLng? _restaurantLatLng;
  LatLng? _customerLatLng;

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  double _durationMin = 0.0;
  bool _isLoadingRoute = false;
  bool _hasAutoZoomedProximity = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _initLocationsAndSockets();
  }

  void _initLocationsAndSockets() {
    // 1. Extract Customer location
    if (_currentOrder.deliveryAddress.location != null) {
      final coords = _currentOrder.deliveryAddress.location!.coordinates;
      if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
        _customerLatLng = LatLng(coords[1], coords[0]);
      }
    }

    // 2. Extract Restaurant location
    if (_currentOrder.restaurantId is Map) {
      final rMap = _currentOrder.restaurantId as Map;
      final addr = rMap['address'];
      if (addr != null && addr['location'] != null) {
        final coords = addr['location']['coordinates'] as List;
        if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
          _restaurantLatLng = LatLng(
            coords[1].toDouble(),
            coords[0].toDouble(),
          );
        }
      }
    }
    if (_restaurantLatLng == null) {
      final restProv = Provider.of<RestaurantProvider>(context, listen: false);
      final rests = restProv.restaurants
          .where((r) => r.id == _currentOrder.restaurantIdStr)
          .toList();
      if (rests.isNotEmpty &&
          rests.first.address?.location?.coordinates != null) {
        final coords = rests.first.address!.location!.coordinates;
        if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
          _restaurantLatLng = LatLng(coords[1], coords[0]);
        }
      }
    }
    // Fallback restaurant location
    _restaurantLatLng ??= const LatLng(33.5138, 36.2765);

    // 3. Extract Driver initial location
    if (_currentOrder.driverId is Map) {
      final dMap = _currentOrder.driverId as Map;
      final dInfo = dMap['driverInfo'];
      if (dInfo != null && dInfo['currentLocation'] != null) {
        final coords = dInfo['currentLocation']['coordinates'] as List;
        if (coords.length >= 2 && !(coords[0] == 0.0 && coords[1] == 0.0)) {
          _driverLatLng = LatLng(coords[1].toDouble(), coords[0].toDouble());
        }
      }
    }

    // Join order socket room
    SocketService.joinOrderRoom(_currentOrder.id);

    // Listen to real-time driver location updates
    SocketService.socket?.on('driverLocation', _handleDriverLocationUpdate);

    // Listen to real-time status updates
    SocketService.socket?.on('orderStatus', _handleOrderStatusChange);

    // Initial route calculation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoute();
    });
  }

  @override
  void dispose() {
    SocketService.leaveOrderRoom(_currentOrder.id);
    SocketService.socket?.off('driverLocation', _handleDriverLocationUpdate);
    SocketService.socket?.off('orderStatus', _handleOrderStatusChange);
    super.dispose();
  }

  void _handleDriverLocationUpdate(dynamic data) {
    if (!mounted) return;
    final orderId = data['orderId'];
    if (orderId != null && orderId != _currentOrder.id) return;

    final loc = data['location'];
    if (loc != null) {
      double? lat;
      double? lng;
      if (loc is Map) {
        lat =
            (loc['lat'] ??
                    (loc['coordinates'] is List ? loc['coordinates'][1] : null))
                ?.toDouble();
        lng =
            (loc['lng'] ??
                    (loc['coordinates'] is List ? loc['coordinates'][0] : null))
                ?.toDouble();
      }
      if (lat != null && lng != null) {
        setState(() {
          _driverLatLng = LatLng(lat!, lng!);
        });
        _fetchRoute();
      }
    }
  }

  void _handleOrderStatusChange(dynamic data) {
    if (!mounted) return;
    final orderId = data['orderId'] ?? data['_id'];
    final status = data['status'];

    if (orderId == _currentOrder.id) {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders().then((_) {
        if (!mounted) return;
        final updatedList = orderProv.orders
            .where((o) => o.id == _currentOrder.id)
            .toList();
        if (updatedList.isNotEmpty) {
          setState(() {
            _currentOrder = updatedList.first;
          });
          _fetchRoute();
        }
      });

      if (status == 'delivered_pending') {
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
            content: const Text('وصل عامل التوصيل بموقعك. هل استلمت الطلب؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ليس بعد'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(ctx);
                  orderProv.loadOrders();
                },
                child: const Text('نعم، استلمت الطلب'),
              ),
            ],
          ),
        );
      } else if (status == 'delivered') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تأكيد الاستلام وتوصيل الطلب بنجاح!'),
          ),
        );
      }
    }
  }

  Future<void> _fetchRoute() async {
    final hasDriver =
        [
          'delivery_accepted',
          'preparing',
          'ready',
          'onTheWay',
          'delivered_pending',
        ].contains(_currentOrder.status) &&
        _driverLatLng != null;

    LatLng origin;
    LatLng destination;

    if (hasDriver) {
      origin = _driverLatLng!;
      if ([
        'delivery_accepted',
        'preparing',
        'ready',
      ].contains(_currentOrder.status)) {
        destination = _restaurantLatLng ?? const LatLng(33.5138, 36.2765);
      } else {
        destination =
            _customerLatLng ??
            _restaurantLatLng ??
            const LatLng(33.5138, 36.2765);
      }
    } else {
      origin = _restaurantLatLng ?? const LatLng(33.5138, 36.2765);
      destination =
          _customerLatLng ??
          _restaurantLatLng ??
          const LatLng(33.5138, 36.2765);
    }

    if (origin.latitude == destination.latitude &&
        origin.longitude == destination.longitude) {
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
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
            _checkProximityAndAutoZoom(destination);
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      setState(() {
        _routePoints = [origin, destination];
        _distanceKm = _calculateHaversineDistance(origin, destination);
        _durationMin = _distanceKm * 3.0; // Rough estimation
        _isLoadingRoute = false;
      });
      _checkProximityAndAutoZoom(destination);
    }
  }

  void _checkProximityAndAutoZoom(LatLng destination) {
    if (_distanceKm > 0 && _distanceKm <= 0.5) {
      if (!_hasAutoZoomedProximity) {
        _hasAutoZoomedProximity = true;
        _mapController.move(destination, 17.5);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎯 عامل التوصيل أصبح قريباً جداً منك'),
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

  Future<void> _confirmReceipt(OrderProvider orderProv) async {
    if (_receivedBase64 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تصوير الطلب لتأكيد استلامه')),
      );
      return;
    }
    final err = await orderProv.customerConfirmDelivery(
      _currentOrder.id,
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

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);

    final mapCenter =
        _driverLatLng ??
        _restaurantLatLng ??
        _customerLatLng ??
        const LatLng(33.5138, 36.2765);

    final List<Marker> mapMarkers = [];

    // 1. Restaurant Marker
    if (_restaurantLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _restaurantLatLng!,
          width: 50,
          height: 50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Customer Location Marker
    if (_customerLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _customerLatLng!,
          width: 50,
          height: 50,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: const Icon(
                  Icons.person_pin_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Driver Live Location Marker
    final hasDriver =
        [
          'delivery_accepted',
          'preparing',
          'ready',
          'onTheWay',
          'delivered_pending',
        ].contains(_currentOrder.status) &&
        _driverLatLng != null;
    if (hasDriver) {
      mapMarkers.add(
        Marker(
          point: _driverLatLng!,
          width: 56,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.blueAccent,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تتبع طلب #${_currentOrder.id.length > 6 ? _currentOrder.id.substring(_currentOrder.id.length - 6) : _currentOrder.id}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              orderProv.loadOrders();
              _fetchRoute();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Map Section
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          Theme.of(context).brightness == Brightness.dark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.wassalni.app',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            strokeWidth: 9.0,
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

                // Floating Map Zoom & Recenter Controls
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'cust_recenter_btn',
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: AppTheme.primary,
                        onPressed: () {
                          _mapController.move(mapCenter, 15.0);
                        },
                        child: const Icon(Icons.my_location_rounded),
                      ),
                      if (_routePoints.length >= 2) ...[
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: 'cust_fit_bounds_btn',
                          backgroundColor: Theme.of(context).cardColor,
                          foregroundColor: AppTheme.secondary,
                          onPressed: () {
                            try {
                              final bounds = LatLngBounds.fromPoints(
                                _routePoints,
                              );
                              _mapController.fitCamera(
                                CameraFit.bounds(
                                  bounds: bounds,
                                  padding: const EdgeInsets.all(60.0),
                                ),
                              );
                            } catch (_) {}
                          },
                          child: const Icon(Icons.fit_screen_rounded),
                        ),
                      ],
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'cust_zoom_in_btn',
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.color,
                        onPressed: () {
                          final currentZoom = _mapController.camera.zoom;
                          _mapController.move(
                            _mapController.camera.center,
                            currentZoom + 1,
                          );
                        },
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),

                // Live ETA & Distance Card Overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasDriver
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            hasDriver
                                ? Icons.delivery_dining
                                : Icons.restaurant,
                            color: hasDriver ? Colors.blue : Colors.orange,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusText(_currentOrder.status),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _isLoadingRoute
                                  ? const Text(
                                      'جاري حساب الوقت والمسافة...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Text(
                                      hasDriver
                                          ? 'الوقت المتوقع للوصول: ${_durationMin.toStringAsFixed(0)} دقيقة (${_distanceKm.toStringAsFixed(1)} كم)'
                                          : 'المسافة للمطعم: ${_distanceKm.toStringAsFixed(1)} كم',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: hasDriver
                                            ? Colors.blue
                                            : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Timeline Progress & Details Section
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                children: [
                  _buildStep(
                    context,
                    'تم إرسال الطلب بنجاح',
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
                    ].contains(_currentOrder.status),
                  ),
                  _buildStep(
                    context,
                    'تم قبول الطلب وجاري التحضير بالمطعم',
                    [
                      'accepted',
                      'restaurant_accepted',
                      'preparing',
                      'ready',
                      'delivery_accepted',
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(_currentOrder.status),
                  ),
                  _buildStep(
                    context,
                    'الطلب جاهز وقبله عامل التوصيل',
                    [
                      'ready',
                      'delivery_accepted',
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(_currentOrder.status),
                  ),
                  _buildStep(
                    context,
                    'عامل التوصيل في الطريق إليك 🛵',
                    [
                      'onTheWay',
                      'delivered_pending',
                      'delivered',
                    ].contains(_currentOrder.status),
                  ),
                  _buildStep(
                    context,
                    'تم التوصيل والاستلام بنجاح ✓',
                    _currentOrder.status == 'delivered',
                  ),

                  if (_currentOrder.status == 'delivered_pending') ...[
                    const Divider(height: 32),
                    const Text(
                      'وصل السائق! الرجاء تصوير الطلب لتأكيد الاستلام:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickReceiptImage,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        _imageFile != null
                            ? 'تغيير الصورة'
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _confirmReceipt(orderProv),
                        child: const Text(
                          'نعم، استلمت الطلب (تأكيد التسليم)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ] else if (_currentOrder.status == 'delivered') ...[
                    const Divider(height: 32),
                    const Center(
                      child: Text(
                        'تم تأكيد استلام الطلب وتوصيله بنجاح 🎉',
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
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context, String title, bool isDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_off,
            color: isDone
                ? Colors.green
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                color: isDone
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
                fontSize: 14,
              ),
            ),
          ),
        ],
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
        return 'تم قبول التوصيل من عامل التوصيل';
      case 'preparing':
        return 'يتم التحضير بالمطعم';
      case 'ready':
        return 'جاهز للتوصيل ובانتظار السائق';
      case 'onTheWay':
        return 'السائق في الطريق إليك';
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
