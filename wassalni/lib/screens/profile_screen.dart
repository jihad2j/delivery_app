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

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: auth.currentUser?.name);
    _phoneController = TextEditingController(text: auth.currentUser?.phone);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primary.withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // Balance Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'رصيدك الحالي:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${auth.currentUser?.balance.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
              ),
              if (auth.currentUser?.role == 'restaurant') ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'موقع المطعم الجغرافي:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        auth.currentUser?.address?.location?.coordinates !=
                                    null &&
                                auth
                                        .currentUser!
                                        .address!
                                        .location!
                                        .coordinates
                                        .length >=
                                    2
                            ? 'خط الطول: ${auth.currentUser!.address!.location!.coordinates[0].toStringAsFixed(6)}\nخط العرض: ${auth.currentUser!.address!.location!.coordinates[1].toStringAsFixed(6)}'
                            : 'لم يتم تحديد موقع المطعم بدقة بعد',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _updateLocation(auth),
                  icon: const Icon(Icons.my_location),
                  label: const Text('تحديث موقع المطعم الحالي (GPS)'),
                ),
              ],
              const SizedBox(height: 40),

              auth.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () => _save(auth),
                      child: const Text('حفظ التغييرات'),
                    ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateLocation(AuthProvider auth) async {
    final err = await LocationHelper.checkAndRequestPermissions();
    if (err != null) {
      String msg = 'حدث خطأ في صلاحية الموقع';
      if (err == 'GPS_DISABLED') {
        msg = 'الرجاء تفعيل خدمة تحديد الموقع (GPS)';
      } else if (err == 'GPS_DENIED') {
        msg = 'تم رفض صلاحية تحديد موقع المطعم';
      } else if (err == 'GPS_DENIED_FOREVER') {
        msg = 'صلاحية الموقع مرفوضة دائماً، الرجاء تفعيلها من الإعدادات';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    // Show dialog loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري قراءة موقع المطعم الحالي...'),
          ],
        ),
      ),
    );

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: $e')));
      return;
    }

    Navigator.pop(context); // Close loader

    final updatedAddress = model.Address(
      street: 'موقع المطعم المحدث بالـ GPS',
      city: 'دمشق',
      zipCode: '00000',
      location: model.Location(coordinates: [pos.longitude, pos.latitude]),
    );

    await auth.updateProfile(address: updatedAddress);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث موقع المطعم بالـ GPS بنجاح')),
    );
  }

  Future<void> _save(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    await auth.updateProfile(
      name: _nameController.text,
      phone: _phoneController.text,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الملف الشخصي بنجاح')),
    );
  }
}
