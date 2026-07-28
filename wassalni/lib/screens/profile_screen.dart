// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/providers.dart';
import '../core/theme.dart';
import '../core/services.dart';
import '../models/models.dart' as model;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  List<model.Address> _savedAddresses = [];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
    _savedAddresses = List<model.Address>.from(user?.addresses ?? []);

    // If main address exists and not in savedAddresses, sync it
    if (user?.address != null && _savedAddresses.isEmpty) {
      _savedAddresses.add(user!.address!);
    }
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'customer':
        return 'زبون';
      case 'driver':
        return 'كابتن توصيل';
      case 'restaurant':
        return 'صاحب مطعم';
      case 'admin':
        return 'مدير النظام';
      default:
        return role ?? 'مستخدم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.premiumGradientDeco().copyWith(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 43,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 48,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'مستخدم',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getRoleLabel(user?.role),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Balance Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.green,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'رصيد الحساب الحالي',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${user?.balance.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          auth.tryAutoLogin();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث الرصيد الحسابي')),
                          );
                        },
                        child: const Text('تحديث'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Customer Info Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.badge_outlined, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                            'المعلومات الشخصية',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: user?.email ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني (غير قابل للتعديل)',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Saved Locations / Addresses Section (مواقع التوصيل المحفوظة)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'مواقع التوصيل المحفوظة',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _openAddressFormDialog(),
                            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                            label: const Text('إضافة موقع'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_savedAddresses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.location_off_outlined, color: Colors.orange, size: 36),
                              SizedBox(height: 8),
                              Text(
                                'لا توجد مواقع توصيل محفوظة حتى الآن',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'اضغط على "إضافة موقع" لتخزين عنوان بيتك أو عملك لسرعة الطلب',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _savedAddresses.length,
                          itemBuilder: (ctx, idx) {
                            final addr = _savedAddresses[idx];
                            final isMain = user?.address?.street == addr.street &&
                                user?.address?.city == addr.city;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMain
                                      ? AppTheme.primary
                                      : Colors.grey.withValues(alpha: 0.2),
                                  width: isMain ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (isMain ? AppTheme.primary : AppTheme.secondary)
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getLabelIcon(addr.label),
                                          color: isMain ? AppTheme.primary : AppTheme.secondary,
                                          size: 20,
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
                                                    fontFamily: 'Outfit',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (isMain) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary,
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Text(
                                                      'الرئيسي',
                                                      style: TextStyle(
                                                        fontFamily: 'Outfit',
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${addr.governorate ?? addr.city ?? "دمشق"} - ${addr.region ?? addr.street ?? "المنطقة"}',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                        onPressed: () => _openAddressFormDialog(addressToEdit: addr, index: idx),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                                        onPressed: () => _deleteAddress(idx),
                                      ),
                                    ],
                                  ),
                                  if (addr.details != null && addr.details!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'التفاصيل: ${addr.details}',
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                  if (!isMain) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: () => _setDefaultAddress(addr),
                                        child: const Text(
                                          'تعيين كعنوان رئيسي',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Restaurant section if restaurant role
              if (user?.role == 'restaurant') ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'موقع المطعم الجغرافي (GPS)',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user?.address?.location?.coordinates != null &&
                                        user!.address!.location!.coordinates.length >= 2
                                    ? 'خط الطول: ${user.address!.location!.coordinates[0].toStringAsFixed(6)}\nخط العرض: ${user.address!.location!.coordinates[1].toStringAsFixed(6)}'
                                    : 'لم يتم تحديد موقع المطعم بدقة بعد',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () => _updateRestaurantGpsLocation(auth),
                          icon: const Icon(Icons.my_location),
                          label: const Text('تحديث موقع المطعم الجغرافي (GPS)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: () => _saveProfile(auth),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('حفظ التغييرات'),
                    ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () async {
                  await auth.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'تسجيل الخروج من الحساب',
                  style: TextStyle(color: Colors.redAccent, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getLabelIcon(String? label) {
    if (label == null) return Icons.location_on_rounded;
    if (label.contains('المنزل') || label.contains('بيتي') || label.contains('منزل')) {
      return Icons.home_rounded;
    }
    if (label.contains('العمل') || label.contains('مكتب') || label.contains('شرك')) {
      return Icons.work_rounded;
    }
    return Icons.place_rounded;
  }

  void _openAddressFormDialog({model.Address? addressToEdit, int? index}) {
    final labelCtrl = TextEditingController(text: addressToEdit?.label ?? 'المنزل 🏠');
    final govCtrl = TextEditingController(text: addressToEdit?.governorate ?? 'دمشق');
    final regCtrl = TextEditingController(text: addressToEdit?.region ?? addressToEdit?.city ?? '');
    final streetCtrl = TextEditingController(text: addressToEdit?.street ?? '');
    final detailsCtrl = TextEditingController(text: addressToEdit?.details ?? '');
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
                      addressToEdit != null ? 'تعديل موقع التوصيل' : 'إضافة موقع توصيل جديد',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
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
                    labelText: 'اسم الموقع (مثال: المنزل، العمل)',
                    prefixIcon: Icon(Icons.label_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'اللاذقية', 'طرطوس', 'حماة'].contains(govCtrl.text)
                      ? govCtrl.text
                      : 'دمشق',
                  decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: ['دمشق', 'ريف دمشق', 'حلب', 'حمص', 'اللاذقية', 'طرطوس', 'حماة']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) govCtrl.text = v;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: regCtrl,
                  decoration: const InputDecoration(
                    labelText: 'المنطقة / الحي (مثال: المزة، المالكي)',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: streetCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الشارع / اسم البناء',
                    prefixIcon: Icon(Icons.add_road_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل دقيقة (رقم الطابق، أمانة البناء...)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                // GPS Location Capture Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final err = await LocationHelper.checkAndRequestPermissions();
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء تفعيل الـ GPS في جهازك')),
                      );
                      return;
                    }
                    try {
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                        timeLimit: const Duration(seconds: 8),
                      );
                      setBottomSheetState(() {
                        capturedCoords = [pos.longitude, pos.latitude];
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم التقاط الإحداثيات عبر الـ GPS بنجاح! 🎯')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تعذر تحديد الموقع الجغرافي: $e')),
                      );
                    }
                  },
                  icon: Icon(
                    capturedCoords != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                    color: capturedCoords != null ? Colors.green : AppTheme.primary,
                  ),
                  label: Text(
                    capturedCoords != null
                        ? 'تم ربط الموقع بالـ GPS (${capturedCoords![1].toStringAsFixed(4)}, ${capturedCoords![0].toStringAsFixed(4)})'
                        : 'تحديد الموقع الدقيق عبر الـ GPS',
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
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
                              : 'تم إضافة الموقع الجديد لقائمة مواقك المحفوظة',
                        ),
                      ),
                    );
                  },
                  child: Text(addressToEdit != null ? 'تعديل الموقع' : 'إضافة الموقع'),
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
      builder: (ctx) => AlertDialog(
        title: const Text('حذف موقع التوصيل'),
        content: const Text('هل أنت تأكد من رغبتك في حذف هذا الموقع من قائمة مواقك المحفوظة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _savedAddresses.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الموقع بنجاح')),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDefaultAddress(model.Address addr) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.updateProfile(address: addr);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تعيين هذا الموقع كعنوان رئيسي للتوصيل')),
    );
  }

  Future<void> _updateRestaurantGpsLocation(AuthProvider auth) async {
    final err = await LocationHelper.checkAndRequestPermissions();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تفعيل الـ GPS لتحديد موقع المطعم')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      final updatedAddress = model.Address(
        street: 'موقع المطعم المحدد بالـ GPS',
        city: 'دمشق',
        zipCode: '00000',
        location: model.Location(coordinates: [pos.longitude, pos.latitude]),
      );
      await auth.updateProfile(address: updatedAddress);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث موقع المطعم بالـ GPS بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل قراءة الـ GPS: $e')),
      );
    }
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    await auth.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
      address: _savedAddresses.isNotEmpty ? _savedAddresses.first : null,
      addresses: _savedAddresses,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ معلومات الحساب والمواقع المحفوظة بنجاح')),
    );
  }
}

