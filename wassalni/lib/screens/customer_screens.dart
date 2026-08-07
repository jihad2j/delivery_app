// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'dart:async';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'default';
  String? _detectedGovernorate;
  String? _detectedRegion;
  bool _isDetectingLocation = true;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'الكل', 'icon': Icons.dashboard_rounded},
    {'name': 'مشروبات', 'icon': Icons.local_drink_rounded},
    {'name': 'حلويات', 'icon': Icons.cake_rounded},
    {'name': 'مشاوي', 'icon': Icons.fireplace_rounded},
    {'name': 'شاورما فروج', 'icon': Icons.restaurant_menu_rounded},
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _initUserLocation();
    });
  }

  Future<void> _initUserLocation() async {
    if (!mounted) return;
    setState(() => _isDetectingLocation = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    String? gov;
    String? reg;

    // 1. الأولوية الأولى: موقع الـ GPS
    try {
      final gpsErr = await LocationHelper.checkAndRequestPermissions();
      if (gpsErr == null) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );

        // مطابقة الـ GPS مع العناوين المخزنة القريبة أولاً للمطابقة التامة
        if (user != null) {
          if (user.address?.location?.coordinates != null &&
              user.address!.location!.coordinates.length == 2) {
            final double sLng = user.address!.location!.coordinates[0];
            final double sLat = user.address!.location!.coordinates[1];
            if (sLat != 0 && sLng != 0) {
              final dist = Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                sLat,
                sLng,
              );
              if (dist < 3000 &&
                  (user.address?.governorate?.isNotEmpty ?? false) &&
                  (user.address?.region?.isNotEmpty ?? false)) {
                gov = user.address!.governorate;
                reg = user.address!.region;
              }
            }
          }

          if (gov == null) {
            for (final addr in user.addresses) {
              if (addr.location?.coordinates != null &&
                  addr.location!.coordinates.length == 2) {
                final double sLng = addr.location!.coordinates[0];
                final double sLat = addr.location!.coordinates[1];
                if (sLat != 0 && sLng != 0) {
                  final dist = Geolocator.distanceBetween(
                    pos.latitude,
                    pos.longitude,
                    sLat,
                    sLng,
                  );
                  if (dist < 3000 &&
                      (addr.governorate?.isNotEmpty ?? false) &&
                      (addr.region?.isNotEmpty ?? false)) {
                    gov = addr.governorate;
                    reg = addr.region;
                    break;
                  }
                }
              }
            }
          }
        }

        // إذا لم تطابق عنواناً مخزناً، نقوم بعكس الترميز من OSM Nominatim
        if (gov == null) {
          final geo =
              await LocationHelper.reverseGeocode(pos.latitude, pos.longitude);
          if (geo != null &&
              ((geo['governorate']?.isNotEmpty ?? false) ||
                  (geo['region']?.isNotEmpty ?? false))) {
            gov = geo['governorate'];
            reg = geo['region'];
          }
        }
      }
    } catch (e) {
      debugPrint('GPS location resolution error: $e');
    }

    // 2. الأولوية الثانية: الموقع الأساسي للمستخدم (currentUser.address)
    if ((gov == null || gov.isEmpty) &&
        (reg == null || reg.isEmpty) &&
        user?.address != null) {
      if (user!.address?.governorate != null &&
          user.address!.governorate!.isNotEmpty) {
        gov = user.address!.governorate;
        reg = user.address!.region ?? '';
      }
    }

    // 3. الأولوية الثالثة: أحد المواقع المخزنة سابقاً (currentUser.addresses)
    if ((gov == null || gov.isEmpty) &&
        (reg == null || reg.isEmpty) &&
        user != null &&
        user.addresses.isNotEmpty) {
      for (final addr in user.addresses) {
        if (addr.governorate != null && addr.governorate!.isNotEmpty) {
          gov = addr.governorate;
          reg = addr.region ?? '';
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _detectedGovernorate = gov;
        _detectedRegion = reg;
        _isDetectingLocation = false;
      });

      Provider.of<RestaurantProvider>(context, listen: false).loadRestaurants(
        governorate: gov,
        region: reg,
      );
    }
  }

  String get _locationSubtitle {
    final gov = _detectedGovernorate?.trim() ?? '';
    final reg = _detectedRegion?.trim() ?? '';
    if (gov.isNotEmpty && reg.isNotEmpty) {
      return 'موقعك الحالي $gov - $reg';
    } else if (gov.isNotEmpty) {
      return 'موقعك الحالي $gov';
    } else if (reg.isNotEmpty) {
      return 'موقعك الحالي $reg';
    }
    return 'موقعك غير محدد';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final restProv = Provider.of<RestaurantProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredRestaurants = restProv.restaurants.where((r) {
      final matchesCategory = _selectedCategory == 'الكل' ||
          r.restaurantInfo?.cuisineType == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          r.name.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesLocation = true;
      final currentGov = _detectedGovernorate?.trim().toLowerCase();
      final currentReg = _detectedRegion?.trim().toLowerCase();

      if (currentReg != null && currentReg.isNotEmpty) {
        final restReg = (r.address?.region ?? '').trim().toLowerCase();
        final restGov = (r.address?.governorate ?? '').trim().toLowerCase();

        final regionMatch = restReg.isNotEmpty &&
            (restReg == currentReg ||
                restReg.contains(currentReg) ||
                currentReg.contains(restReg));
        final govMatch = currentGov != null &&
            currentGov.isNotEmpty &&
            restGov.isNotEmpty &&
            restGov == currentGov;

        matchesLocation = regionMatch || govMatch;
      } else if (currentGov != null && currentGov.isNotEmpty) {
        final restGov = (r.address?.governorate ?? '').trim().toLowerCase();
        matchesLocation = restGov.isEmpty || restGov == currentGov;
      }

      return matchesCategory && matchesSearch && matchesLocation;
    }).toList();

    if (_sortBy == 'delivery_fee') {
      filteredRestaurants.sort((a, b) => (a.restaurantInfo?.deliveryFee ?? 0)
          .compareTo(b.restaurantInfo?.deliveryFee ?? 0));
    } else if (_sortBy == 'min_order') {
      filteredRestaurants.sort((a, b) => (a.restaurantInfo?.minOrderAmount ?? 0)
          .compareTo(b.restaurantInfo?.minOrderAmount ?? 0));
    }

    final activeOrders = Provider.of<OrderProvider>(context)
        .orders
        .where((o) => !['delivered', 'cancelled'].contains(o.status))
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _initUserLocation(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Header with Gradient
            SliverAppBar(
              expandedHeight: 185,
              pinned: true,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Container(
                  decoration: AppTheme.primaryGradient(),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 45, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'مرحباً ${auth.currentUser?.name ?? "عميلنا العزيز"}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white70,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            _isDetectingLocation
                                                ? 'جاري تحديد موقعك...'
                                                : _locationSubtitle,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.8),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w400,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _HeaderBtn(
                                icon: Icons.receipt_long_rounded,
                                onTap: () => Navigator.pushNamed(
                                    context, '/customer-orders'),
                              ),
                              const SizedBox(width: 8),
                              _HeaderBtn(
                                icon: Icons.person_outline_rounded,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/profile'),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'الرصيد: ${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'ابحث عن مطعم...',
                            hintStyle: TextStyle(
                                color: Colors.grey[400], fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: Colors.grey[400], size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 0, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.tune_rounded,
                              color: _sortBy != 'default'
                                  ? AppTheme.primary
                                  : Colors.grey[600]),
                          onPressed: () {
                            _showFilterSheet(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Active Order Banner
            if (activeOrders.isNotEmpty)
              SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OrderTrackScreen(order: activeOrders.first),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade400],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.green.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delivery_dining_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('لديك طلب نشط',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(
                                _getStatusText(activeOrders.first.status),
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white.withValues(alpha: 0.7),
                            size: 16),
                      ],
                    ),
                  ),
                ),
              ),

            // 3. Category Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final name = cat['name'] as String;
                    final isSelected = _selectedCategory == name;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
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
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(cat['icon'] as IconData,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 4. Section Title
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: AppTheme.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'المطاعم المتاحة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (filteredRestaurants.isNotEmpty)
                      Text(
                        '${filteredRestaurants.length} مطعم',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ),

            // 5. Loading / Empty / Restaurants List
            if (restProv.isLoading)
              const SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (filteredRestaurants.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج لبحثك'
                            : 'لا توجد مطاعم تحت هذا التصنيف',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final rest = filteredRestaurants[index];
                    final info = rest.restaurantInfo;
                    if (info == null) return const SizedBox();
                    final isOpen = info.status == 'open';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RestaurantCard(
                        rest: rest,
                        info: info,
                        isOpen: isOpen,
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(
                            context, '/restaurant-detail',
                            arguments: rest),
                      ),
                    );
                  }, childCount: filteredRestaurants.length),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.itemCount == 0) return const SizedBox();
          return FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/cart'),
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.shopping_cart_rounded,
                color: Colors.white, size: 20),
            label: Text(
              '${cart.itemCount} • ${cart.grandTotal.toStringAsFixed(0)} ل.س',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13),
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ترتيب المطاعم (بحث متقدم)',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                RadioListTile<String>(
                  title: const Text('الترتيب الافتراضي'),
                  value: 'default',
                  groupValue: _sortBy,
                  onChanged: (val) {
                    setModalState(() => _sortBy = val!);
                    setState(() => _sortBy = val!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('الأقل أجرة توصيل'),
                  value: 'delivery_fee',
                  groupValue: _sortBy,
                  onChanged: (val) {
                    setModalState(() => _sortBy = val!);
                    setState(() => _sortBy = val!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('الأقل للحد الأدنى للطلب'),
                  value: 'min_order',
                  groupValue: _sortBy,
                  onChanged: (val) {
                    setModalState(() => _sortBy = val!);
                    setState(() => _sortBy = val!);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        });
      },
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final model.User rest;
  final model.RestaurantInfo info;
  final bool isOpen;
  final bool isDark;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.rest,
    required this.info,
    required this.isOpen,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    info.logo,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Center(
                        child: Icon(Icons.restaurant_rounded,
                            size: 48, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ),
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
                Positioned(
                    top: 10, right: 10, child: _StatusBadge(isOpen: isOpen)),
                Positioned(
                    bottom: 10,
                    right: 10,
                    child: _CuisineChip(cuisine: info.cuisineType)),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Consumer<RestaurantProvider>(
                    builder: (context, restProv, _) {
                      final isFav = restProv.isFavorite(rest.id);
                      return Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            restProv.toggleFavorite(rest.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFav ? Colors.red : Colors.grey[600],
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(rest.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Text(
                        '${info.deliveryFee.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 14, color: Colors.redAccent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${rest.address?.city ?? "دمشق"} - ${rest.address?.street ?? ""}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.delivery_dining_rounded,
                          size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'توصيل',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (info.description != null &&
                      info.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      info.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isOpen ? Colors.green : Colors.red).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOpen ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'مفتوح' : 'مغلق',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CuisineChip extends StatelessWidget {
  final String cuisine;
  const _CuisineChip({required this.cuisine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu_rounded,
              color: Colors.orangeAccent, size: 13),
          const SizedBox(width: 4),
          Text(cuisine,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
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
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<RestaurantProvider>(context, listen: false)
          .loadMenu(widget.restaurant.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final restProv = Provider.of<RestaurantProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final info = widget.restaurant.restaurantInfo!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availableMenu =
        restProv.currentMenu.where((p) => p.isAvailable).toList();
    final categories = availableMenu.map((p) => p.category).toSet().toList()
      ..sort();
    final filteredMenu = _selectedCategory == null
        ? availableMenu
        : availableMenu.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            actions: [
              Consumer<RestaurantProvider>(
                builder: (context, restProv, _) {
                  final isFav = restProv.isFavorite(widget.restaurant.id);
                  return IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white,
                    ),
                    onPressed: () {
                      restProv.toggleFavorite(widget.restaurant.id);
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    info.logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: isDark ? Colors.grey[850] : Colors.grey[200]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.restaurant.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 6)
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _InfoChip(
                              icon: Icons.restaurant_menu_rounded,
                              label: info.cuisineType,
                            ),
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.motorcycle_rounded,
                              label:
                                  '${info.deliveryFee.toStringAsFixed(0)} ل.س',
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: info.status == 'open'
                                    ? Colors.green.withValues(alpha: 0.9)
                                    : Colors.red.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                info.status == 'open' ? 'مفتوح' : 'مغلق',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
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

          // ── Description ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 15, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'عن المطعم',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.description ?? 'لا يوجد وصف للمطعم',
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.5),
                  ),
                  if (info.openingTime != null || info.closingTime != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 15, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          '${info.openingTime ?? '--'} - ${info.closingTime ?? '--'}',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Category Filters ──
          if (categories.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 15, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'قائمة المأكولات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'الكل',
                            selected: _selectedCategory == null,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          ...categories.map((cat) => _CategoryChip(
                                label: cat,
                                selected: _selectedCategory == cat,
                                onTap: () =>
                                    setState(() => _selectedCategory = cat),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Menu Items ──
          restProv.isLoading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : filteredMenu.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restaurant_rounded,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('لا توجد وجبات متوفرة حالياً',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final prod = filteredMenu[index];
                          final isRestaurantOpen = info.status == 'open';

                          return _MenuItemCard(
                            product: prod,
                            isRestaurantOpen: isRestaurantOpen,
                            deliveryFee: info.deliveryFee,
                            onAddToCart: () {
                              if (!isRestaurantOpen) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'المطعم مغلق حالياً ولا يقبل الطلبات')),
                                );
                                return;
                              }
                              final success = cart.addItem(prod,
                                  restaurantDeliveryFee: info.deliveryFee);
                              if (!mounted) return;
                              if (success) {
                                ScaffoldMessenger.of(context)
                                    .hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'تمت إضافة "${prod.name}" إلى السلة'),
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'السلة',
                                      textColor: Colors.amber,
                                      onPressed: () =>
                                          Navigator.pushNamed(context, '/cart'),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'لا يمكنك إضافة منتجات من مطاعم مختلفة إلى نفس السلة. يرجى إفراغ السلة أولاً.')),
                                );
                              }
                            },
                          );
                        }, childCount: filteredMenu.length),
                      ),
                    ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : Colors.grey[400]!,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  final model.Product product;
  final bool isRestaurantOpen;
  final double deliveryFee;
  final VoidCallback onAddToCart;

  const _MenuItemCard({
    required this.product,
    required this.isRestaurantOpen,
    required this.deliveryFee,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final prod = product;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(18)),
              child: SizedBox(
                width: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      prod.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[850],
                        child: const Icon(Icons.fastfood_rounded,
                            size: 40, color: Colors.white24),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${prod.price.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prod.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (prod.description != null &&
                        prod.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        prod.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500], height: 1.3),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          prod.category,
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                        const Spacer(),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: isRestaurantOpen ? onAddToCart : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isRestaurantOpen
                                    ? AppTheme.primary.withValues(alpha: 0.12)
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 14,
                                    color: isRestaurantOpen
                                        ? AppTheme.primary
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'أضف',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isRestaurantOpen
                                          ? AppTheme.primary
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
  bool _useSavedAddress = true; // true = Saved location, false = GPS
  Position? _detectedPosition;
  bool _gpsDetermined = false;
  bool _saveToProfile = false;
  final _addressLabelController = TextEditingController();

  String? _houseDoorBase64;
  File? _imageFile;

  final ImagePicker _picker = ImagePicker();
  String _paymentMethod = 'cash';

  final _promoController = TextEditingController();
  String? _appliedPromoCode;
  double _discountAmount = 0.0;
  bool _isValidatingPromo = false;

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Text('جاري تحديد موقعك بالـ GPS...'),
          ],
        ),
      ),
    );

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return;
      Navigator.pop(context);
      setState(() {
        _detectedPosition = pos;
        _gpsDetermined = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديد موقع الـ GPS بنجاح!')),
      );
    } catch (e) {
      if (!mounted) return;
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
    final hasSavedAddresses = auth.currentUser?.addresses.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سلة المشتريات',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_shopping_cart_rounded,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'السلة فارغة حالياً!',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Items Section
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag_rounded,
                                  size: 16, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Text(
                                'المنتجات المطلوبة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...cart.items.values.map((item) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.product.price.toStringAsFixed(0)} ل.س',
                                          style: const TextStyle(
                                            fontFamily: 'Outfit',
                                            color: AppTheme.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[800]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              cart.removeItem(item.product.id),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(Icons.remove,
                                                size: 16, color: Colors.grey),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            final success =
                                                cart.addItem(item.product);
                                            if (!success) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'لا يمكنك إضافة منتجات من مطاعم مختلفة إلى نفس السلة.')),
                                              );
                                            }
                                          },
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(Icons.add,
                                                size: 16,
                                                color: AppTheme.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 12),

                        // 2. Delivery Location Section (Selector: Saved vs GPS)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: AppTheme.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'موقع التوصيل',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Mode Toggle Switch (Segmented design)
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _useSavedAddress = true,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _useSavedAddress
                                                  ? Theme.of(context).cardColor
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: _useSavedAddress
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.bookmark_rounded,
                                                  size: 16,
                                                  color: _useSavedAddress
                                                      ? AppTheme.primary
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'موقع مخزن',
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: _useSavedAddress
                                                        ? AppTheme.primary
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => setState(
                                            () => _useSavedAddress = false,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: !_useSavedAddress
                                                  ? Theme.of(context).cardColor
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: !_useSavedAddress
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                        blurRadius: 4,
                                                      ),
                                                    ]
                                                  : [],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.my_location_rounded,
                                                  size: 16,
                                                  color: !_useSavedAddress
                                                      ? AppTheme.primary
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'تحديد GPS',
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: !_useSavedAddress
                                                        ? AppTheme.primary
                                                        : Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Choice Content: Stored Dropdown
                                if (_useSavedAddress) ...[
                                  if (hasSavedAddresses)
                                    DropdownButtonFormField<model.Address>(
                                      value: _selectedSavedAddress,
                                      isDense: true,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        labelText: 'اختر موقعك التوصيل',
                                        labelStyle: const TextStyle(
                                          fontSize: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      items: auth.currentUser!.addresses.map((
                                        addr,
                                      ) {
                                        return DropdownMenuItem<model.Address>(
                                          value: addr,
                                          child: Text(
                                            '${addr.label ?? "موقع"} (${addr.city ?? addr.governorate ?? ""})',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (addr) {
                                        setState(
                                          () => _selectedSavedAddress = addr,
                                        );
                                      },
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'لا توجد مواقع مخزنة في حسابك. استخدم تحديد الـ GPS.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ]
                                // Choice Content: GPS Fetch
                                else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _gpsDetermined
                                            ? Colors.green
                                            : AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: _determineGPSPosition,
                                      icon: Icon(
                                        _gpsDetermined
                                            ? Icons.check_circle_rounded
                                            : Icons.gps_fixed_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        _gpsDetermined
                                            ? 'تم تحديد موقعك بنجاح'
                                            : 'انقر لتحديد الموقع بالـ GPS',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_gpsDetermined) ...[
                                    const SizedBox(height: 6),
                                    CheckboxListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        'حفظ هذا الموقع في حسابي',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      value: _saveToProfile,
                                      onChanged: (val) => setState(
                                        () => _saveToProfile = val ?? false,
                                      ),
                                    ),
                                    if (_saveToProfile)
                                      SizedBox(
                                        height: 40,
                                        child: TextField(
                                          controller: _addressLabelController,
                                          style: const TextStyle(fontSize: 12),
                                          decoration: InputDecoration(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            labelText:
                                                'اسم الموقع (مثال: بيتي)',
                                            labelStyle: const TextStyle(
                                              fontSize: 11,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 3. Door Photo & Security (Optional Compact)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sensor_door_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'صورة المكان/الباب',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      Text(
                                        'اختياري لزيادة الأمان للتوصيل',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_imageFile != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      _imageFile!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _pickDoorImage,
                                  child: Text(
                                    _imageFile != null ? 'تغيير' : 'كاميرا',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 4. Payment Method Choice
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.payment_rounded,
                                      color: AppTheme.primary,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'طريقة الدفع',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                RadioListTile<String>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'دفع كاش (نقداً عند الاستلام)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  value: 'cash',
                                  groupValue: _paymentMethod,
                                  onChanged: (val) => setState(
                                    () => _paymentMethod = val ?? 'cash',
                                  ),
                                ),
                                RadioListTile<String>(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'المحفظة الإلكترونية',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${auth.currentUser?.balance.toStringAsFixed(0) ?? "0"} ل.س',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  value: 'wallet',
                                  groupValue: _paymentMethod,
                                  onChanged: (val) => setState(
                                    () => _paymentMethod = val ?? 'wallet',
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

                // 5. Checkout Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPromoCodeField(orderProv, cart),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('المجموع الفرعي',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            const Spacer(),
                            Text(
                              '${cart.totalAmount.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('رسوم التوصيل',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(Icons.motorcycle_rounded,
                                    size: 13, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  '+${cart.deliveryFee.toStringAsFixed(0)} ل.س',
                                  style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_discountAmount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('الخصم ($_appliedPromoCode)',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                              const Spacer(),
                              Text(
                                '-${_discountAmount.toStringAsFixed(0)} ل.س',
                                style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Colors.grey[300], height: 1),
                        ),
                        Row(
                          children: [
                            const Text(
                              'المجموع الكلي',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              '${(cart.grandTotal - _discountAmount > 0 ? cart.grandTotal - _discountAmount : 0).toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: orderProv.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => _checkout(cart, orderProv),
                                  icon: const Icon(Icons.shopping_bag_rounded,
                                      size: 20),
                                  label: const Text(
                                    'تأكيد الطلب',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _checkout(CartProvider cart, OrderProvider orderProv) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    model.Address finalDeliveryAddress;

    if (_useSavedAddress) {
      if (_selectedSavedAddress == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى اختيار موقع من مواقعك المخزنة')),
        );
        return;
      }
      finalDeliveryAddress = _selectedSavedAddress!;
    } else {
      if (!_gpsDetermined || _detectedPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى النقر على زر "تحديد الموقع بالـ GPS" أولاً'),
          ),
        );
        return;
      }
      final label =
          _saveToProfile ? _addressLabelController.text.trim() : 'موقع GPS';
      if (_saveToProfile && label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى كتابة اسم للموقع (مثال: بيتي)')),
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

      if (_saveToProfile) {
        await auth.addCustomerAddress(finalDeliveryAddress);
      }
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
      deliveryFee: cart.deliveryFee,
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
      await auth.tryAutoLogin();
      if (!mounted) return;
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

  Widget _buildPromoCodeField(OrderProvider orderProv, CartProvider cart) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _promoController,
              decoration: InputDecoration(
                hintText: 'أدخل كود الخصم',
                hintStyle: const TextStyle(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 40,
          child: ElevatedButton(
            onPressed: _isValidatingPromo
                ? null
                : () async {
                    if (_promoController.text.trim().isEmpty) return;
                    setState(() => _isValidatingPromo = true);
                    final promo = await orderProv.validatePromoCode(_promoController.text.trim());
                    setState(() => _isValidatingPromo = false);

                    if (promo != null) {
                      setState(() {
                        _appliedPromoCode = promo['code'];
                        if (promo['discountType'] == 'percentage') {
                          _discountAmount = (cart.totalAmount * (promo['discountValue'] / 100));
                        } else {
                          _discountAmount = promo['discountValue'].toDouble();
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم تطبيق كود الخصم بنجاح!')),
                      );
                    } else {
                      setState(() {
                        _appliedPromoCode = null;
                        _discountAmount = 0.0;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('كود الخصم غير صحيح أو منتهي الصلاحية')),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isValidatingPromo
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('تطبيق', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  _CustomerOrdersScreenState createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  Timer? _pollingTimer;
  late TabController _tabController;

  final List<String> _tabLabels = ['الكل', 'نشط', 'مكتمل', 'ملغى'];
  final List<String?> _tabFilters = [null, 'active', 'delivered', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);

    Future.microtask(() {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders();
      orderProv.setupSocketListeners();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      final hasActive = orderProv.orders
          .any((o) => !['delivered', 'cancelled'].contains(o.status));
      if (hasActive) orderProv.loadOrders();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<model.Order> _filteredOrders(List<model.Order> orders, String? filter) {
    if (filter == null) return orders;
    if (filter == 'active') {
      return orders
          .where((o) => !['delivered', 'cancelled'].contains(o.status))
          .toList();
    }
    if (filter == 'delivered') {
      return orders.where((o) => o.status == 'delivered').toList();
    }
    if (filter == 'cancelled') {
      return orders.where((o) => o.status == 'cancelled').toList();
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final filtered =
        _filteredOrders(orderProv.orders, _tabFilters[_tabController.index]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: orderProv.isLoading && orderProv.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_rounded,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        _tabController.index == 0
                            ? 'لا توجد طلبات بعد'
                            : _tabController.index == 1
                                ? 'لا توجد طلبات نشطة'
                                : _tabController.index == 2
                                    ? 'لا توجد طلبات مكتملة'
                                    : 'لا توجد طلبات ملغية',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => orderProv.loadOrders(),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (ctx, idx) {
                      final order = filtered[idx];
                      final statusColor = _getStatusColor(order.status);
                      final statusIcon = _getStatusIcon(order.status);
                      final progress = _orderProgress(order.status);

                      return _OrderCard(
                        order: order,
                        statusColor: statusColor,
                        statusIcon: statusIcon,
                        progress: progress,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackScreen(order: order),
                              ));
                        },
                        onRate: () => _showRatingDialog(context, order, orderProv),
                      );
                    },
                  ),
                ),
    );
  }

  double _orderProgress(String status) {
    switch (status) {
      case 'pending':
        return 0.1;
      case 'restaurant_accepted':
        return 0.25;
      case 'preparing':
        return 0.4;
      case 'ready':
        return 0.55;
      case 'delivery_accepted':
        return 0.7;
      case 'onTheWay':
        return 0.85;
      case 'delivered_pending':
        return 0.95;
      case 'delivered':
        return 1.0;
      case 'cancelled':
        return 0.0;
      default:
        return 0.0;
    }
  }

  void _showRatingDialog(BuildContext context, model.Order order, OrderProvider orderProv) {
    int _rating = 5;
    final _reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('تقييم الطلب', textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ما هو تقييمك لجودة الطلب والتوصيل؟'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اكتب رأيك (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final err = await orderProv.rateOrder(order.id, _rating, _reviewController.text.trim());
                    if (!mounted) return;
                    if (err == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('شكراً لتقييمك!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('إرسال التقييم'),
                )
              ],
            );
          },
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final model.Order order;
  final Color statusColor;
  final IconData statusIcon;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback? onRate;

  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.statusIcon,
    required this.progress,
    required this.onTap,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
        border:
            Border.all(color: statusColor.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#${order.id.substring(order.id.length - 6)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${order.totalAmount.toStringAsFixed(0)} ل.س',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress Bar
                if (order.status != 'cancelled')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor:
                          isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  order.items
                      .map((it) => '${it.name} ×${it.quantity}')
                      .join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 6),
                          Text(
                            order.status == 'delivered'
                                ? 'تم التوصيل'
                                : _getStatusText(order.status),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.grey[400]),
                  ],
                ),
                if (order.status == 'delivered' && order.rating == null && onRate != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRate,
                      icon: const Icon(Icons.star_border_rounded, size: 18),
                      label: const Text('قيم الطلب'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                ] else if (order.status == 'delivered' && order.rating != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('تقييمك: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ...List.generate(5, (index) {
                        return Icon(
                          index < order.rating! ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      return 'جاهز للتوصيل وانتظار السائق';
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
    case 'delivered_pending':
      return AppTheme.warning;
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
    case 'delivered_pending':
      return Icons.handshake_rounded;
    case 'delivered':
      return Icons.check_circle_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.info_outline_rounded;
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
  LatLng? _previousDriverLatLng;
  double _driverHeading = 0;
  LatLng? _restaurantLatLng;
  LatLng? _customerLatLng;

  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  double _durationMin = 0.0;
  bool _isLoadingRoute = false;
  bool _hasAutoZoomedProximity = false;
  bool _hasAutoFitted = false;

  Timer? _driverAnimationTimer;
  final MapController _mapController = MapController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _initLocationsAndSockets();

    Future.microtask(() {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.addListener(_onOrderProviderChange);
      orderProv.loadOrders();
    });

    // Auto-poll status every 3 seconds while order is active
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (['delivered', 'cancelled'].contains(_currentOrder.status)) {
        timer.cancel();
        return;
      }
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      await orderProv.loadOrders();
      if (!mounted) return;
      final match =
          orderProv.orders.where((o) => o.id == _currentOrder.id).toList();
      if (match.isNotEmpty && match.first.status != _currentOrder.status) {
        setState(() {
          _currentOrder = match.first;
        });
        _fetchRoute();
      }
    });
  }

  void _onOrderProviderChange() {
    if (!mounted) return;
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final match =
        orderProv.orders.where((o) => o.id == _currentOrder.id).toList();
    if (match.isNotEmpty && match.first.status != _currentOrder.status) {
      setState(() {
        _currentOrder = match.first;
      });
      _fetchRoute();
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoute().then((_) {
        if (mounted && !_hasAutoFitted && _routePoints.length >= 2) {
          _hasAutoFitted = true;
          try {
            final bounds = LatLngBounds.fromPoints(_routePoints);
            _mapController.fitCamera(CameraFit.bounds(
                bounds: bounds, padding: const EdgeInsets.all(80)));
          } catch (_) {}
        }
      });
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _driverAnimationTimer?.cancel();
    try {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.removeListener(_onOrderProviderChange);
    } catch (_) {}
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
        lat = (loc['lat'] ??
                (loc['coordinates'] is List ? loc['coordinates'][1] : null))
            ?.toDouble();
        lng = (loc['lng'] ??
                (loc['coordinates'] is List ? loc['coordinates'][0] : null))
            ?.toDouble();
      }
      if (lat != null && lng != null) {
        if (lat == 0.0 && lng == 0.0) return;
        _animateDriverTo(LatLng(lat, lng));
        _fetchRoute();
      }
    }
  }

  void _handleOrderStatusChange(dynamic data) {
    if (!mounted) return;
    final orderId =
        data != null ? (data['orderId'] ?? data['_id'] ?? data['id']) : null;
    final status = data != null ? data['status'] : null;

    if (orderId == null || orderId.toString() == _currentOrder.id.toString()) {
      final orderProv = Provider.of<OrderProvider>(context, listen: false);
      orderProv.loadOrders().then((_) {
        if (!mounted) return;
        final updatedList =
            orderProv.orders.where((o) => o.id == _currentOrder.id).toList();
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
            title: const Text('وصل الكابتن'),
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
    final hasDriver = [
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
        destination = _customerLatLng ??
            _restaurantLatLng ??
            const LatLng(33.5138, 36.2765);
      }
    } else {
      origin = _restaurantLatLng ?? const LatLng(33.5138, 36.2765);
      destination = _customerLatLng ??
          _restaurantLatLng ??
          const LatLng(33.5138, 36.2765);
    }

    if (origin.latitude == destination.latitude &&
        origin.longitude == destination.longitude) {
      return;
    }

    setState(() => _isLoadingRoute = true);

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
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
            _checkProximityAndAutoZoom(destination);
            if (!_hasAutoFitted && points.length >= 2) {
              _hasAutoFitted = true;
              try {
                final bounds = LatLngBounds.fromPoints(points);
                _mapController.fitCamera(CameraFit.bounds(
                    bounds: bounds, padding: const EdgeInsets.all(80)));
              } catch (_) {}
            }
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _routePoints = [origin, destination];
        _distanceKm = _calculateHaversineDistance(origin, destination);
        _durationMin = _distanceKm * 3.0;
        _isLoadingRoute = false;
      });
      _checkProximityAndAutoZoom(destination);
      if (!_hasAutoFitted) {
        _hasAutoFitted = true;
        try {
          final allPoints = [origin, destination];
          final bounds = LatLngBounds.fromPoints(allPoints);
          _mapController.fitCamera(CameraFit.bounds(
              bounds: bounds, padding: const EdgeInsets.all(80)));
        } catch (_) {}
      }
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
              content: Text('عامل التوصيل أصبح قريباً جداً منك'),
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
    _driverAnimationTimer?.cancel();
    final start = _driverLatLng ?? target;
    final startTime = DateTime.now();
    const animDuration = Duration(milliseconds: 1500);

    _driverAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 30), (timer) {
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
      setState(() {
        _driverLatLng = newPos;
      });
      if (t >= 1.0) {
        timer.cancel();
        _previousDriverLatLng = target;
      }
    });
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
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد استلام الطلب بنجاح. شكراً لك!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    final mapCenter = _driverLatLng ??
        _restaurantLatLng ??
        _customerLatLng ??
        const LatLng(33.5138, 36.2765);

    final List<Marker> mapMarkers = [];

    if (_restaurantLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _restaurantLatLng!,
          width: 100,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('المطعم',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6)
                  ],
                ),
                child:
                    const Icon(Icons.restaurant, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    if (_customerLatLng != null) {
      mapMarkers.add(
        Marker(
          point: _customerLatLng!,
          width: 100,
          height: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('موقعي',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6)
                  ],
                ),
                child: const Icon(Icons.person_pin_circle,
                    color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      );
    }

    final hasDriver = [
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
          width: 68,
          height: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getStatusText(_currentOrder.status),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              Transform.rotate(
                angle: _driverHeading * pi / 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.blueAccent,
                          blurRadius: 10,
                          spreadRadius: 2),
                    ],
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isCancelled = _currentOrder.status == 'cancelled';
    final isDelivered = _currentOrder.status == 'delivered';

    return Scaffold(
      body: Stack(
        children: [
          // Full Screen Map Background
          Positioned.fill(
            child: _buildMapSection(mapCenter, mapMarkers, orderProv),
          ),

          // Floating Header Bar (Top Navigation)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Back button
                    Material(
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: const CircleBorder(),
                      color: Theme.of(context).cardColor,
                      child: IconButton(
                        icon:
                            const Icon(Icons.arrow_back_ios_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Order ID Card & Refresh
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              'طلب #${_currentOrder.id.length > 6 ? _currentOrder.id.substring(_currentOrder.id.length - 6) : _currentOrder.id}',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              onPressed: () {
                                orderProv.loadOrders();
                                _fetchRoute();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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

          // Bottom Sheet - 50% initial screen height with rest of details
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.25,
            maxChildSize: 0.88,
            snap: true,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    // Sheet Drag Handle Indicator
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // Status info chip
                    if (!hasDriver && !isDelivered && !isCancelled)
                      _buildMapInfoCard(hasDriver),

                    // Driver info card
                    if (hasDriver) _buildDriverInfoCard(),

                    // If delivered or cancelled show final state
                    if (isDelivered || isCancelled)
                      _buildFinalStateCard(orderProv),

                    // Timeline Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('حالة الطلب',
                              style: textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildStepTimeline(context),
                        ],
                      ),
                    ),

                    // Order summary
                    _buildOrderSummaryCard(),

                    // Receipt section
                    if (_currentOrder.status == 'delivered_pending')
                      _buildReceiptSection(orderProv),

                    if (isDelivered)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('تم توصيل الطلب بنجاح',
                                style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),
                      ),

                    if (isCancelled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text('تم إلغاء الطلب',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(
      LatLng mapCenter, List<Marker> mapMarkers, OrderProvider orderProv) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: mapCenter, initialZoom: 14.0),
          children: [
            TileLayer(
              urlTemplate: Theme.of(context).brightness == Brightness.dark
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
                      strokeWidth: 9),
                  Polyline(
                      points: _routePoints,
                      color: AppTheme.primary,
                      strokeWidth: 5),
                ],
              ),
            MarkerLayer(markers: mapMarkers),
          ],
        ),
        // Loading indicator
        if (_isLoadingRoute)
          Positioned(
            top: 75,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 6),
                    Text('جاري تحديث المسار...',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        // Zoom controls
        Positioned(
          top: 75,
          left: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'cust_recenter_btn',
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: AppTheme.primary,
                onPressed: () => _mapController.move(mapCenter, 15.0),
                child: const Icon(Icons.my_location_rounded, size: 20),
              ),
              if (_routePoints.length >= 2) ...[
                const SizedBox(height: 6),
                FloatingActionButton.small(
                  heroTag: 'cust_fit_bounds_btn',
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: AppTheme.secondary,
                  onPressed: () {
                    try {
                      final bounds = LatLngBounds.fromPoints(_routePoints);
                      _mapController.fitCamera(CameraFit.bounds(
                          bounds: bounds, padding: const EdgeInsets.all(60)));
                    } catch (_) {}
                  },
                  child: const Icon(Icons.fit_screen_rounded, size: 18),
                ),
              ],
              const SizedBox(height: 6),
              FloatingActionButton.small(
                heroTag: 'cust_zoom_in_btn',
                backgroundColor: Theme.of(context).cardColor,
                foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                onPressed: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1),
                child: const Icon(Icons.add, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapInfoCard(bool hasDriver) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasDriver
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                hasDriver
                    ? Icons.delivery_dining_rounded
                    : Icons.restaurant_rounded,
                color: hasDriver ? Colors.blue : Colors.orange,
                size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getStatusText(_currentOrder.status),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                _isLoadingRoute
                    ? const Text('جاري حساب الوقت والمسافة...',
                        style: TextStyle(fontSize: 12, color: Colors.grey))
                    : Text(
                        hasDriver
                            ? 'الوقت المتوقع للوصول: ${_durationMin.toStringAsFixed(0)} دقيقة (${_distanceKm.toStringAsFixed(1)} كم)'
                            : 'المسافة للمطعم: ${_distanceKm.toStringAsFixed(1)} كم',
                        style: TextStyle(
                            fontSize: 12,
                            color: hasDriver ? Colors.blue : Colors.grey[700],
                            fontWeight: FontWeight.w600),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard() {
    String driverName = '';
    String driverPhone = '';
    if (_currentOrder.driverId is Map) {
      final dMap = _currentOrder.driverId as Map;
      driverName = dMap['name'] ?? '';
      driverPhone = dMap['phone'] ?? dMap['email'] ?? '';
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(driverName.isNotEmpty ? driverName : 'عامل التوصيل',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.delivery_dining_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(_getStatusText(_currentOrder.status),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          if (driverPhone.isNotEmpty)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('رقم السائق: $driverPhone')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinalStateCard(OrderProvider orderProv) {
    final isDelivered = _currentOrder.status == 'delivered';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDelivered
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: (isDelivered ? AppTheme.primary : Colors.red)
                .withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isDelivered ? AppTheme.primary : Colors.red)
                  .withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isDelivered ? AppTheme.primary : Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isDelivered ? 'تم التوصيل بنجاح' : 'تم إلغاء الطلب',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDelivered ? AppTheme.primary : Colors.red)),
                const SizedBox(height: 4),
                Text(isDelivered ? 'شكراً لطلبك مع وصلني' : 'هذا الطلب ملغى',
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTimeline(BuildContext context) {
    final steps = <List<String>>[
      [
        'pending',
        'accepted',
        'restaurant_accepted',
        'preparing',
        'ready',
        'delivery_accepted',
        'onTheWay',
        'delivered_pending',
        'delivered'
      ],
      [
        'accepted',
        'restaurant_accepted',
        'preparing',
        'ready',
        'delivery_accepted',
        'onTheWay',
        'delivered_pending',
        'delivered'
      ],
      [
        'ready',
        'delivery_accepted',
        'onTheWay',
        'delivered_pending',
        'delivered'
      ],
      ['onTheWay', 'delivered_pending', 'delivered'],
      ['delivered'],
    ];
    final labels = [
      'تم إرسال الطلب',
      'قبول الطلب والتحضير',
      'الطلب جاهز',
      'السائق في الطريق',
      'تم التوصيل',
    ];
    final icons = [
      Icons.send_rounded,
      Icons.restaurant_rounded,
      Icons.check_circle_rounded,
      Icons.delivery_dining_rounded,
      Icons.task_alt_rounded,
    ];

    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = steps[i].any((s) => _currentOrder.status == s);
        final isActive = _currentOrder.status == steps[i].first;
        return _buildTimelineStep(
            labels[i], icons[i], isDone, isActive, i == steps.length - 1);
      }),
    );
  }

  Widget _buildTimelineStep(
      String title, IconData icon, bool isDone, bool isActive, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        isDone ? AppTheme.primary : Theme.of(context).cardColor,
                    border: Border.all(
                      color: isDone
                          ? AppTheme.primary
                          : (isActive
                              ? AppTheme.primary
                              : Colors.grey.withValues(alpha: 0.3)),
                      width: 2,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isDone
                        ? Colors.white
                        : (isActive
                            ? AppTheme.primary
                            : Colors.grey.withValues(alpha: 0.5)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone
                          ? AppTheme.primary.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                      color: isDone
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  if (isActive && !isDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 6),
                          Text('قيد التنفيذ',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    double total = _currentOrder.totalAmount;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.receipt_long_rounded,
                    size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Text('تفاصيل الطلب',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          // Items
          ...List.generate(_currentOrder.items.length, (i) {
            final item = _currentOrder.items[i];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: i < _currentOrder.items.length - 1 ? 10 : 0),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${item.quantity}x',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600])),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(item.name,
                          style: const TextStyle(fontSize: 13))),
                  if (item.price > 0)
                    Text(
                        '${(item.price * item.quantity).toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                ],
              ),
            );
          }),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('رسوم التوصيل', style: TextStyle(fontSize: 13)),
              Text('${_currentOrder.deliveryFee.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${total.toStringAsFixed(0)} ل.س',
                  style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_rounded,
                  size: 18, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentOrder.deliveryAddress.details?.isNotEmpty == true
                      ? _currentOrder.deliveryAddress.details!
                      : '${_currentOrder.deliveryAddress.region ?? ''} - ${_currentOrder.deliveryAddress.governorate ?? ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSection(OrderProvider orderProv) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delivery_dining_rounded,
                    color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('وصل السائق! الرجاء تصوير الطلب لتأكيد الاستلام',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pickReceiptImage,
              icon: Icon(_imageFile != null
                  ? Icons.camera_alt_rounded
                  : Icons.camera_alt_rounded),
              label: Text(
                  _imageFile != null ? 'تغيير الصورة' : 'تصوير الطلب المستلم'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _imageFile != null ? Colors.orange : AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          if (_imageFile != null) ...[
            const SizedBox(height: 14),
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                image: DecorationImage(
                    image: FileImage(_imageFile!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmReceipt(orderProv),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('تأكيد استلام الطلب',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

