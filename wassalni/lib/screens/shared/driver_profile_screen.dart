// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/providers.dart';
import '../../core/theme.dart';
import '../../core/services.dart';
import '../../models/models.dart' as model;
import '../../widgets/widgets.dart';
import 'screens.dart' show AppRoutes;

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  _DriverProfileScreenState createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _licensePlateController;
  late TextEditingController _vehicleTypeController;
  List<model.Address> _savedAddresses = [];
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final u = auth.currentUser;
    _nameController = TextEditingController(text: u?.name);
    _phoneController = TextEditingController(text: u?.phone);
    _emailController = TextEditingController(text: u?.email ?? '');
    _licensePlateController = TextEditingController(
      text: u?.driverInfo?.licenseNumber ?? '',
    );
    _vehicleTypeController = TextEditingController(
      text: u?.driverInfo?.vehicleType ?? 'دراجة نارية',
    );
    _isAvailable = u?.driverInfo?.availability ?? true;
    _savedAddresses = List<model.Address>.from(u?.addresses ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licensePlateController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final orderProv = Provider.of<OrderProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalDeliveries = orderProv.completedCountFor(user?.id);
    final todayEarnings = orderProv.todayEarningsFor(user?.id);
    final weeklyEarnings = orderProv.weeklyEarningsFor(user?.id);
    final rating = orderProv.ratingForDriver(user?.id);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 260,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: AppTheme.sunsetGradient(),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                child: SafeArea(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 41,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.local_taxi_rounded,
                                size: 44,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isAvailable
                                    ? AppColors.success
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAvailable ? 'متاح' : 'غير متاح',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.name ?? 'السائق',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'كابتن توصيل · ${_vehicleTypeController.text.isEmpty ? "مركبة" : _vehicleTypeController.text}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rating > 0
                                ? '${rating.toStringAsFixed(1)} / 5.0'
                                : '4.8 / 5.0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 1,
                            height: 14,
                            color: Colors.white54,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$totalDeliveries توصيل منفذ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
        ],
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                BalanceHeaderCard(
                  balance: user?.driverEarningsWallet ?? user?.balance ?? 0,
                  subtitle: 'يتم إيداع الأرباح في المحفظة بعد كل طلب',
                  actions: [
                    IconButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('سيتم تفعيل شحن المحفظة قريباً 💳'),
                          ),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildAvailabilityCard(auth),
                const SizedBox(height: 20),
                _buildDriverStats(
                  isDark,
                  todayEarnings,
                  weeklyEarnings,
                  rating,
                  totalDeliveries,
                ),
                const SizedBox(height: 20),
                _buildVehicleInfo(isDark, context),
                const SizedBox(height: 20),
                _buildInfoSection(context),
                const SizedBox(height: 20),
                _buildMyLocation(context, auth),
                const SizedBox(height: 28),
                ButtonWithIcon(
                  label: 'حفظ التغييرات',
                  icon: Icons.save_rounded,
                  onPressed: () => _saveProfile(auth),
                  isLoading: auth.isLoading,
                ),
                const SizedBox(height: 12),
                ButtonWithIcon(
                  label: 'تسجيل الخروج',
                  icon: Icons.logout_rounded,
                  color: AppColors.error,
                  isOutlined: true,
                  onPressed: () async {
                    await auth.logout();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityCard(AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: _isAvailable
            ? LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              )
            : LinearGradient(
                colors: [
                  Colors.grey.shade500.withValues(alpha: 0.1),
                  isDark ? AppColors.darkCard : Colors.white,
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isAvailable
              ? AppColors.success.withValues(alpha: 0.25)
              : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isAvailable
                  ? AppColors.success.withValues(alpha: 0.18)
                  : Colors.grey.shade400.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isAvailable ? Icons.tour_rounded : Icons.bedtime_rounded,
              color: _isAvailable ? AppColors.success : Colors.grey,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAvailable
                      ? 'حسناً أنت الآن جاهز للطلبات'
                      : 'أنت في وضع الإجازة',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAvailable
                      ? 'يمكن للعملاء طلبك وستظهر لك الطلبات على الخريطة'
                      : 'لن يتم إرسال أي طلبات لك حتى تعيد التفعيل',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (v) async {
              setState(() => _isAvailable = v);
              final err = await auth.toggleDriverAvailability(v);
              if (!mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      v ? 'تم التفعيل، ابدأ التوصيل 🚀' : 'تم الإيقاف المؤقت',
                    ),
                    backgroundColor: v ? AppColors.success : Colors.grey,
                  ),
                );
              }
            },
            activeColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverStats(
    bool isDark,
    double todayEarnings,
    double weeklyEarnings,
    double rating,
    int totalDeliveries,
  ) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        StatCard(
          title: 'التوصيلات',
          value: '$totalDeliveries',
          icon: Icons.local_shipping_outlined,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'كلفة اليوم',
          value: '${todayEarnings.toStringAsFixed(0)} ل.س',
          icon: Icons.point_of_sale_rounded,
          color: AppColors.secondary,
        ),
        StatCard(
          title: 'هذا الأسبوع',
          value: '${weeklyEarnings.toStringAsFixed(0)} ل.س',
          icon: Icons.calendar_view_week_rounded,
          color: AppColors.info,
        ),
        StatCard(
          title: 'التقييم',
          value: rating > 0 ? '${rating.toStringAsFixed(1)}⭐' : '4.8⭐',
          icon: Icons.star_half_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildVehicleInfo(bool isDark, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'معلومات المركبة', titleSize: 16),
          const SizedBox(height: 8),
          InfoListTile(
            icon: Icons.two_wheeler_rounded,
            label: 'نوع المركبة',
            value: _vehicleTypeController.text.isEmpty
                ? 'غير محدد'
                : _vehicleTypeController.text,
            iconColor: AppColors.primary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final v = await _openFieldEditor(
                  'نوع المركبة',
                  _vehicleTypeController.text,
                );
                if (v != null) setState(() => _vehicleTypeController.text = v);
              },
            ),
          ),
          const Divider(height: 20),
          InfoListTile(
            icon: Icons.label_important_outline_rounded,
            label: 'رقم اللوحة / الرخصة',
            value: _licensePlateController.text.isEmpty
                ? 'غير محدد'
                : _licensePlateController.text,
            iconColor: AppColors.secondary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final v = await _openFieldEditor(
                  'رقم اللوحة / الرخصة',
                  _licensePlateController.text,
                );
                if (v != null) setState(() => _licensePlateController.text = v);
              },
            ),
          ),
          const Divider(height: 20),
          const InfoListTile(
            icon: Icons.verified_user_outlined,
            label: 'حالة المستندات',
            value: 'جاهزة ومراجعة ✅',
            iconColor: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'البيانات الشخصية', titleSize: 16),
          const SizedBox(height: 8),
          InfoListTile(
            icon: Icons.person_outline,
            label: 'الاسم الكامل',
            value: _nameController.text,
            iconColor: AppColors.primary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final v = await _openFieldEditor('الاسم', _nameController.text);
                if (v != null) setState(() => _nameController.text = v);
              },
            ),
          ),
          const Divider(height: 20),
          InfoListTile(
            icon: Icons.phone_android_rounded,
            label: 'الهاتف',
            value: _phoneController.text,
            iconColor: AppColors.secondary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final v = await _openFieldEditor(
                  'الهاتف',
                  _phoneController.text,
                );
                if (v != null) setState(() => _phoneController.text = v);
              },
            ),
          ),
          const Divider(height: 20),
          InfoListTile(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: _emailController.text.isEmpty
                ? 'غير محدد'
                : _emailController.text,
            iconColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildMyLocation(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'موقعك الحالي للالتقاطات', titleSize: 16),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final coords =
                          user?.driverInfo?.currentLocation?.coordinates ??
                          user?.address?.location?.coordinates;
                      if (coords != null && coords.length >= 2) {
                        return Text(
                          '${coords[1].toStringAsFixed(5)}°N  ${coords[0].toStringAsFixed(5)}°E',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }
                      return const Text('لم يتم تسجيل موقع بعد');
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _updateDriverGps(auth),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.gps_fixed_rounded),
              label: const Text('تحديث موقعي الحالي بالـ GPS'),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _openFieldEditor(String title, String initial) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل $title'),
          content: TextField(
            autofocus: true,
            controller: ctrl,
            decoration: InputDecoration(labelText: title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDriverGps(AuthProvider auth) async {
    final err = await LocationHelper.checkAndRequestPermissions();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء تفعيل الـ GPS')));
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final newAddr = model.Address(
        street: 'موقع السائق الحالي',
        city: 'دمشق',
        label: 'العمل',
        location: model.Location(coordinates: [pos.longitude, pos.latitude]),
      );
      final updatedDriverInfo = model.DriverInfo(
        vehicleType: _vehicleTypeController.text.isNotEmpty
            ? _vehicleTypeController.text
            : null,
        licenseNumber: _licensePlateController.text.isNotEmpty
            ? _licensePlateController.text
            : null,
        availability: _isAvailable,
        currentLocation: model.Location(
          coordinates: [pos.longitude, pos.latitude],
        ),
      );
      setState(() {
        _savedAddresses
          ..removeWhere((a) => a.label == 'العمل')
          ..add(newAddr);
      });
      await auth.updateProfile(
        address: newAddr,
        addresses: _savedAddresses,
        driverInfo: updatedDriverInfo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ تم تحديث موقعك بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: $e')));
    }
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final fs = _formKey.currentState;
    if (fs == null || !fs.validate()) return;
    final updatedDriverInfo = model.DriverInfo(
      vehicleType: _vehicleTypeController.text.isNotEmpty
          ? _vehicleTypeController.text
          : null,
      licenseNumber: _licensePlateController.text.isNotEmpty
          ? _licensePlateController.text
          : null,
      availability: _isAvailable,
      currentLocation: auth.currentUser?.driverInfo?.currentLocation,
    );
    await auth.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _savedAddresses.isNotEmpty ? _savedAddresses.first : null,
      addresses: _savedAddresses,
      driverInfo: updatedDriverInfo,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم حفظ كل التغييرات بنجاح')),
    );
  }
}
