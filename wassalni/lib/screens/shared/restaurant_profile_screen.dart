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

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({super.key});

  @override
  _RestaurantProfileScreenState createState() => _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _restaurantNameCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _cuisineCtrl;
  TimeOfDay _openingTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 23, minute: 30);
  bool _isOpen = true;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final u = auth.currentUser;
    _nameController = TextEditingController(text: u?.name);
    _phoneController = TextEditingController(text: u?.phone);
    _emailController = TextEditingController(text: u?.email ?? '');
    _restaurantNameCtrl = TextEditingController(text: u?.restaurantName ?? u?.name);
    _descriptionCtrl = TextEditingController(text: u?.restaurantDescription ?? '');
    _cuisineCtrl = TextEditingController(text: u?.cuisineType ?? 'شامي تقليدي');
    if (u?.openingTime != null && u!.openingTime!.contains(':')) {
      final parts = u.openingTime!.split(':');
      _openingTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    if (u?.closingTime != null && u!.closingTime!.contains(':')) {
      final parts = u.closingTime!.split(':');
      _closingTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 23,
          minute: int.tryParse(parts[1]) ?? 30);
    }
    _isOpen = u?.isRestaurantOpen ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _restaurantNameCtrl.dispose();
    _descriptionCtrl.dispose();
    _cuisineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: AppTheme.successGradient(),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                child: SafeArea(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.restaurant_menu_rounded,
                                size: 46,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _isOpen
                                    ? AppColors.success
                                    : AppColors.error,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: Text(
                                _isOpen ? 'مفتوح الآن' : 'مغلق',
                                style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _restaurantNameCtrl.text.isEmpty
                            ? 'المطعم'
                            : _restaurantNameCtrl.text,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.name ?? 'صاحب المطعم',
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_filled_rounded,
                                size: 14, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              'ساعات العمل: ${_formatTime(_openingTime)} — ${_formatTime(_closingTime)}',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontSize: 12,
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
                  balance: user?.balance ?? 0,
                  subtitle:
                      'تقنية وصول يومية عن طريق التطبيق، تواصل مع الإدارة لسحب الأرباح',
                ),
                const SizedBox(height: 18),
                _buildOpenCloseCard(),
                const SizedBox(height: 20),
                _buildRestaurantStats(context, isDark, user),
                const SizedBox(height: 20),
                _buildRestaurantDetails(context),
                const SizedBox(height: 20),
                _buildLocationSection(context, auth),
                const SizedBox(height: 20),
                _buildOwnerInfo(context),
                const SizedBox(height: 20),
                _buildWorkingHoursSection(context),
                const SizedBox(height: 28),
                ButtonWithIcon(
                  label: 'حفظ إعدادات المطعم',
                  icon: Icons.save_rounded,
                  onPressed: () => _saveProfile(auth),
                  isLoading: auth.isLoading,
                ),
                const SizedBox(height: 12),
                ButtonWithIcon(
                  label: 'تسجيل الخروج',
                  icon: Icons.logout_rounded,
                  isOutlined: true,
                  color: AppColors.error,
                  onPressed: () async {
                    await auth.logout();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.login, (_) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpenCloseCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: _isOpen
            ? LinearGradient(
                colors: [
                  AppColors.success.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
              )
            : LinearGradient(
                colors: [
                  AppColors.error.withValues(alpha: 0.12),
                  Colors.red.shade50,
                ],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isOpen
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isOpen
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.error.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
                _isOpen
                    ? Icons.storefront_rounded
                    : Icons.lock_outline_rounded,
                size: 26,
                color: _isOpen ? AppColors.success : AppColors.error),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOpen ? 'المطعم مفتوح ويتلقى الطلبات' : 'المطعم متوقف عن استقبال الطلبات',
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  _isOpen
                      ? 'سيتم عرض مطعمك للزبائن وتلقى طلبات جديدة'
                      : 'لن يتم عرض مطعمك للزبائن حتى تعيد الفتح',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _isOpen,
            onChanged: (v) async {
              setState(() => _isOpen = v);
              final auth =
                  Provider.of<AuthProvider>(context, listen: false);
              final currentInfo = auth.currentUser?.restaurantInfo;
              final updatedInfo = model.RestaurantInfo(
                description: currentInfo?.description,
                logo: currentInfo?.logo ?? 'https://via.placeholder.com/150',
                status: v ? 'open' : 'closed',
                minOrderAmount: currentInfo?.minOrderAmount ?? 0,
                deliveryFee: currentInfo?.deliveryFee ?? 0,
                menu: currentInfo?.menu ?? [],
                cuisineType: currentInfo?.cuisineType ?? 'مشاوي',
                firebaseNotifications: currentInfo?.firebaseNotifications ?? true,
                openingTime: _formatTime(_openingTime),
                closingTime: _formatTime(_closingTime),
              );
              await auth.updateProfile(restaurantInfo: updatedInfo);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(v ? 'المطعم مفتوح ✅' : 'تم إيقاف استقبال الطلبات'),
                  backgroundColor: v ? AppColors.success : AppColors.error,
                ),
              );
            },
            activeColor: AppColors.success,
            inactiveTrackColor: AppColors.error.withValues(alpha: 0.4),
            inactiveThumbColor: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantStats(BuildContext context, bool isDark, model.User? user) {
    final orderProv = Provider.of<OrderProvider>(context);
    final todaySales = orderProv.todaySalesForRestaurant(user?.id);
    final pendingCount = orderProv.pendingOrdersCountForRestaurant(user?.id);
    final weeklySales = orderProv.weeklySalesForRestaurant(user?.id);
    final rating = orderProv.ratingForRestaurant(user?.id);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        StatCard(
          title: 'مبيعات اليوم',
          value: '${todaySales.toStringAsFixed(0)} ل.س',
          icon: Icons.attach_money_rounded,
          color: AppColors.secondary,
        ),
        StatCard(
          title: 'الطلبات الجديدة',
          value: '$pendingCount',
          icon: Icons.receipt_long_rounded,
          color: AppColors.primary,
        ),
        StatCard(
          title: 'هذا الأسبوع',
          value: '${weeklySales.toStringAsFixed(0)} ل.س',
          icon: Icons.calendar_month_rounded,
          color: AppColors.info,
        ),
        StatCard(
          title: 'التقييم',
          value: '${rating.toStringAsFixed(1)}⭐',
          icon: Icons.star_rate_rounded,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildRestaurantDetails(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
              title: 'معلومات المطعم', titleSize: 16),
          const SizedBox(height: 8),
          TextFormField(
            controller: _restaurantNameCtrl,
            decoration: const InputDecoration(
              labelText: 'اسم المطعم',
              prefixIcon: Icon(Icons.storefront_rounded),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'ادخل اسم المطعم' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cuisineCtrl,
            decoration: const InputDecoration(
              labelText: 'نوع المأكولات (شامي، لبناني...)',
              prefixIcon: Icon(Icons.restaurant_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'وصف قصير للمطعم',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_rounded),
              hintText: 'الأطباق الشهية، التوصيل السريع...',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.manageMenu),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('إدارة قائمة الطعام (منتجات - أسعار)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'موقع المطعم على الخريطة', titleSize: 16),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.secondary.withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.primary),
                    child: const Icon(Icons.pin_drop_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final coords =
                          user?.address?.location?.coordinates;
                      if (coords != null && coords.length >= 2) {
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'خط الطول: ${coords[0].toStringAsFixed(6)}\nخط العرض: ${coords[1].toStringAsFixed(6)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }
                      return const Text('لم يتم تحديد الموقع بدقة');
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
              onPressed: () => _updateRestaurantGps(auth),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.gps_fixed_rounded),
              label: const Text('تحديث موقع المطعم عبر الـ GPS'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerInfo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'معلومات المالك', titleSize: 16),
          const SizedBox(height: 8),
          InfoListTile(
            icon: Icons.person_outline_rounded,
            label: 'الاسم الكامل',
            value: _nameController.text,
            iconColor: AppColors.primary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final v =
                    await _openFieldEditor('الاسم', _nameController.text);
                if (v != null) setState(() => _nameController.text = v);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
          const Divider(height: 20),
          InfoListTile(
            icon: Icons.phone_android_rounded,
            label: 'رقم الهاتف',
            value: _phoneController.text,
            iconColor: AppColors.secondary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final v =
                    await _openFieldEditor('الهاتف', _phoneController.text);
                if (v != null) setState(() => _phoneController.text = v);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
          ),
          const Divider(height: 20),
          InfoListTile(
            icon: Icons.email_outlined,
            label: 'البريد الإلكتروني',
            value: _emailController.text.isEmpty ? 'غير محدد' : _emailController.text,
            iconColor: AppColors.info,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ساعات العمل', titleSize: 16),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'فتح',
                  icon: Icons.wb_sunny_rounded,
                  iconColor: AppColors.secondary,
                  time: _openingTime,
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _openingTime);
                    if (t != null) setState(() => _openingTime = t);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimeTile(
                  label: 'إغلاق',
                  icon: Icons.dark_mode_rounded,
                  iconColor: AppColors.primaryDark,
                  time: _closingTime,
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _closingTime);
                    if (t != null) setState(() => _closingTime = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const InfoListTile(
            icon: Icons.calendar_view_day_rounded,
            label: 'أيام العمل',
            value: 'كل الأيام من السبت إلى الجمعة',
            iconColor: AppColors.accentPurple,
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
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateRestaurantGps(AuthProvider auth) async {
    final err = await LocationHelper.checkAndRequestPermissions();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تفعيل الـ GPS أولاً')));
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));
      final updatedAddr = model.Address(
        street: 'موقع المطعم GPS',
        city: 'دمشق',
        label: 'المطعم',
        location: model.Location(coordinates: [pos.longitude, pos.latitude]),
      );
      await auth.updateProfile(address: updatedAddr);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحديث موقع المطعم بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('خطأ GPS: $e')));
    }
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final fs = _formKey.currentState;
    if (fs == null || !fs.validate()) return;
    final currentInfo = auth.currentUser?.restaurantInfo;
    final updatedInfo = model.RestaurantInfo(
      description: _descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : currentInfo?.description,
      logo: currentInfo?.logo ?? 'https://via.placeholder.com/150',
      status: _isOpen ? 'open' : 'closed',
      minOrderAmount: currentInfo?.minOrderAmount ?? 0,
      deliveryFee: currentInfo?.deliveryFee ?? 0,
      menu: currentInfo?.menu ?? [],
      cuisineType: _cuisineCtrl.text.isNotEmpty ? _cuisineCtrl.text : (currentInfo?.cuisineType ?? 'شامي تقليدي'),
      firebaseNotifications: currentInfo?.firebaseNotifications ?? true,
      openingTime: _formatTime(_openingTime),
      closingTime: _formatTime(_closingTime),
    );
    await auth.updateProfile(
      name: _restaurantNameCtrl.text.isNotEmpty ? _restaurantNameCtrl.text : _nameController.text,
      phone: _phoneController.text,
      restaurantInfo: updatedInfo,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ كل إعدادات المطعم بنجاح')));
  }

  static String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _TimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text('$hh:$mm',
                      style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
