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

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  _CustomerProfileScreenState createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  List<model.Address> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
    _emailController = TextEditingController(text: user?.email ?? '');
    _savedAddresses = List<model.Address>.from(user?.addresses ?? []);
    if (user?.address != null && _savedAddresses.isEmpty) {
      _savedAddresses.add(user!.address!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: AppTheme.primaryGradient(),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                child: SafeArea(
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 39,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 42,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.name ?? 'الزبون',
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
                        child: const Text(
                          'زبون · وصلني',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
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
                BalanceHeaderCard(balance: user?.balance ?? 0),
                const SizedBox(height: 20),
                _buildQuickActions(context),
                const SizedBox(height: 24),
                _buildInfoSection(context),
                const SizedBox(height: 20),
                _buildAddressesSection(context, user),
                const SizedBox(height: 28),
                auth.isLoading
                    ? const LoadingIndicator(message: 'جاري الحفظ...')
                    : ButtonWithIcon(
                        label: 'حفظ التغييرات',
                        icon: Icons.save_rounded,
                        onPressed: () => _saveProfile(auth),
                      ),
                const SizedBox(height: 12),
                ButtonWithIcon(
                  label: 'تسجيل الخروج من الحساب',
                  icon: Icons.logout_rounded,
                  isOutlined: true,
                  color: AppColors.error,
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

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: Icons.shopping_bag_outlined,
              label: 'طلباتي',
              color: AppColors.primary,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.customerOrders),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.local_offer_outlined,
              label: 'العروض',
              color: AppColors.secondary,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('قريباً لا توجد عروض حالياً')),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.support_agent_rounded,
              label: 'دعم فني',
              color: AppColors.info,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى الاتصال: 999')),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.favorite_border_rounded,
              label: 'المفضلة',
              color: AppColors.error,
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('المفضلة قريباً')));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المعلومات الشخصية', titleSize: 16),
          const SizedBox(height: 8),
          InfoListTile(
            icon: Icons.person_outline_rounded,
            label: 'الاسم الكامل',
            value: _nameController.text.isEmpty
                ? 'غير محدد'
                : _nameController.text,
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
            label: 'رقم الهاتف',
            value: _phoneController.text.isEmpty
                ? 'غير محدد'
                : _phoneController.text,
            iconColor: AppColors.secondary,
            trailing: IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final v = await _openFieldEditor(
                  'رقم الهاتف',
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

  Widget _buildAddressesSection(BuildContext context, model.User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'مواقع التوصيل المحفوظة',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 16),
                ),
              ),
              TextButton.icon(
                onPressed: () => _openAddressFormDialog(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_savedAddresses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.2),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    color: AppColors.secondary,
                    size: 40,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'لا توجد مواقع محفوظة',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'إضغط على زر "إضافة" لحفظ عنوان التوصيل',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ..._savedAddresses.asMap().entries.map((entry) {
              final idx = entry.key;
              final addr = entry.value;
              final isMain =
                  user?.address?.street == addr.street &&
                  user?.address?.city == addr.city;
              return Container(
                margin: EdgeInsets.only(
                  bottom: idx == _savedAddresses.length - 1 ? 0 : 12,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMain
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                    width: isMain ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            (isMain ? AppColors.primary : AppColors.secondary)
                                .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppTheme.getAddressIcon(addr.label),
                        color: isMain ? AppColors.primary : AppColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                addr.label ?? 'عنوان',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (isMain) ...[
                                const SizedBox(width: 6),
                                StatusBadge(
                                  label: 'رئيسي',
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${addr.governorate ?? addr.city ?? "دمشق"} · ${addr.region ?? addr.street ?? ""}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: () => _openAddressFormDialog(
                        addressToEdit: addr,
                        index: idx,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      onPressed: () => _deleteAddress(idx),
                    ),
                  ],
                ),
              );
            }),
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

  void _openAddressFormDialog({model.Address? addressToEdit, int? index}) {
    final labelCtrl = TextEditingController(
      text: addressToEdit?.label ?? 'المنزل',
    );
    final govCtrl = TextEditingController(
      text: addressToEdit?.governorate ?? 'دمشق',
    );
    final regCtrl = TextEditingController(
      text: addressToEdit?.region ?? addressToEdit?.city ?? '',
    );
    final streetCtrl = TextEditingController(text: addressToEdit?.street ?? '');
    final detailsCtrl = TextEditingController(
      text: addressToEdit?.details ?? '',
    );
    List<double>? capturedCoords = addressToEdit?.location?.coordinates;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setBottomSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      addressToEdit != null
                          ? 'تعديل موقع التوصيل'
                          : 'إضافة موقع جديد',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموقع (المنزل / العمل)',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value:
                      [
                        'دمشق',
                        'ريف دمشق',
                        'حلب',
                        'حمص',
                        'اللاذقية',
                        'طرطوس',
                        'حماة',
                      ].contains(govCtrl.text)
                      ? govCtrl.text
                      : 'دمشق',
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items:
                      [
                            'دمشق',
                            'ريف دمشق',
                            'حلب',
                            'حمص',
                            'اللاذقية',
                            'طرطوس',
                            'حماة',
                          ]
                          .map(
                            (g) => DropdownMenuItem(value: g, child: Text(g)),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) govCtrl.text = v;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: regCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المنطقة / الحي',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: streetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الشارع / البناء',
                    prefixIcon: Icon(Icons.add_road_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل دقيقة (طابق - أمانة...)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final err =
                        await LocationHelper.checkAndRequestPermissions();
                    if (!mounted) return;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('فضلاً فعّل الـ GPS')),
                      );
                      return;
                    }
                    try {
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                        timeLimit: const Duration(seconds: 10),
                      );
                      if (!mounted) return;
                      setBottomSheetState(() {
                        capturedCoords = [pos.longitude, pos.latitude];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم التقاط الموقع')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('خطأ GPS: $e')));
                    }
                  },
                  icon: Icon(
                    capturedCoords != null
                        ? Icons.gps_fixed_rounded
                        : Icons.gps_not_fixed_rounded,
                    color: capturedCoords != null
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                  label: Text(
                    capturedCoords != null
                        ? 'تم ربط الموقع (${capturedCoords![1].toStringAsFixed(4)}, ${capturedCoords![0].toStringAsFixed(4)})'
                        : 'تحديد الموقع عبر الـ GPS',
                  ),
                ),
                const SizedBox(height: 20),
                ButtonWithIcon(
                  label: addressToEdit != null ? 'حفظ التعديل' : 'إضافة الموقع',
                  icon: Icons.add_location_rounded,
                  onPressed: () {
                    final newAddr = model.Address(
                      label: labelCtrl.text.isEmpty ? 'عنوان' : labelCtrl.text,
                      governorate: govCtrl.text,
                      region: regCtrl.text,
                      city: govCtrl.text,
                      street: streetCtrl.text,
                      details: detailsCtrl.text,
                      location: capturedCoords != null
                          ? model.Location(coordinates: capturedCoords!)
                          : null,
                    );
                    setState(() {
                      if (index != null && index < _savedAddresses.length) {
                        _savedAddresses[index] = newAddr;
                      } else {
                        _savedAddresses.add(newAddr);
                      }
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          addressToEdit != null
                              ? 'تم تعديل الموقع بنجاح'
                              : 'تم إضافة الموقع لحفظ المفضلة',
                        ),
                      ),
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

  void _deleteAddress(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف موقع التوصيل'),
          content: const Text('هل تريد تأكيد الحذف؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _savedAddresses.removeAt(index));
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final fs = _formKey.currentState;
    if (fs == null || !fs.validate()) return;
    await auth.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _savedAddresses.isNotEmpty ? _savedAddresses.first : null,
      addresses: _savedAddresses,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات بنجاح')));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
