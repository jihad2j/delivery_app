// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/providers.dart';
import '../core/theme.dart';
import '../core/services.dart';
import '../models/models.dart' as model;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  // ignore: duplicate_ignore
  // ignore: library_private_types_in_public_api
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.tryAutoLogin();

    await Future.delayed(const Duration(milliseconds: 500));

    if (auth.isAuthenticated) {
      _routeUser(auth.currentUser!.role);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _routeUser(String role) {
    if (role == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer-home');
    } else if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver-home');
    } else if (role == 'restaurant') {
      Navigator.pushReplacementNamed(context, '/restaurant-home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.premiumGradientDeco(),
        child: Center(
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bike_rounded,
                    size: 96,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'وصلني',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'توصيل سريع وأمان كامل',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: duplicate_ignore
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (kDebugMode)
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: _showSettingsDialog,
                      ),
                    ),
                  const SizedBox(height: 40),
                  const Text(
                    'مرحباً بك مجدداً! 👋',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قم بتسجيل الدخول للمتابعة في تطبيق وصلني',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassmorphismDeco(
                      cardColor: cardColor,
                    ),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) => v!.isEmpty
                              ? 'يرجى إدخال البريد الإلكتروني'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  auth.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _submit(auth),
                          child: const Text('تسجيل الدخول'),
                        ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ليس لديك حساب؟ ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text(
                          'سجل الآن',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
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
    );
  }

  void _showSettingsDialog() {
    final ipController = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعدادات الاتصال بالسيرفر'),
        content: TextField(
          controller: ipController,
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.x:3000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () async {
              await ApiService.setBaseUrl(ipController.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث عنوان السيرفر بنجاح')),
              );
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final err = await auth.login(
      _emailController.text,
      _passwordController.text,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
    } else {
      _routeUser(auth.currentUser!.role);
    }
  }

  void _routeUser(String role) {
    if (role == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer-home');
    } else if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver-home');
    } else if (role == 'restaurant') {
      Navigator.pushReplacementNamed(context, '/restaurant-home');
    }
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Location and address details fields
  String? _selectedGovernorate;
  String? _selectedRegion;
  final _regionTextController = TextEditingController();
  final _detailsController = TextEditingController();
  List<String> _availableRegions = [];
  bool _loadingRegions = false;
  bool _isManualRegion = false;
  Position? _detectedPosition;
  bool _gpsDetermined = false;

  final List<String> _governorates = [
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'دير الزور',
    'الرقة',
    'الحسكة',
    'درعا',
    'السويداء',
    'القنيطرة',
  ];

  String _selectedRole = 'customer';
  String _selectedCuisine = 'مشاوي'; // default cuisine type for restaurant
  bool _obscureText = true;

  final List<String> _cuisineTypes = [
    'مشروبات',
    'حلويات',
    'مشاوي',
    'شاورما فروج',
  ];

  Future<void> _determineGPSPosition() async {
    final permissionError = await LocationHelper.checkAndRequestPermissions();
    if (permissionError != null) {
      String msg = 'حدث خطأ في صلاحية الموقع';
      if (permissionError == 'GPS_DISABLED') {
        msg = 'الرجاء تفعيل خدمة تحديد الموقع (GPS)';
      } else if (permissionError == 'GPS_DENIED') {
        msg = 'تم رفض صلاحية تحديد موقعك الجغرافي';
      } else if (permissionError == 'GPS_DENIED_FOREVER') {
        msg =
            'صلاحية الموقع مرفوضة دائماً، الرجاء تفعيلها من الإعدادات لمتابعة التسجيل';
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
      Navigator.pop(context); // Close loader
      setState(() {
        _detectedPosition = pos;
        _gpsDetermined = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تثبيت موقع الـ GPS بنجاح!')),
      );
    } catch (e) {
      Navigator.pop(context); // Close loader
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: $e')));
    }
  }

  Future<void> _onGovernorateChanged(String? val, AuthProvider auth) async {
    if (val == null) return;
    setState(() {
      _selectedGovernorate = val;
      _selectedRegion = null;
      _isManualRegion = false;
      _loadingRegions = true;
      _availableRegions = [];
    });

    final regions = await auth.fetchRegions(val);
    setState(() {
      _availableRegions = regions;
      _loadingRegions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'انضم إلينا اليوم! 🚀',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سجل حساباً جديداً لبدء استخدام تطبيق وصلني',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassmorphismDeco(cardColor: cardColor),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'الاسم الكامل',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال البريد الإلكتروني' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscureText = !_obscureText),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) => v!.length < 6
                            ? 'كلمة المرور يجب أن تكون 6 خانات فأكثر'
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'اختر نوع الحساب:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRoleOption(
                      'customer',
                      'عميل',
                      Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildRoleOption(
                      'driver',
                      'سائق',
                      Icons.directions_bike_outlined,
                    ),
                    const SizedBox(width: 8),
                    _buildRoleOption(
                      'restaurant',
                      'مطعم',
                      Icons.restaurant_outlined,
                    ),
                  ],
                ),

                if (_selectedRole == 'restaurant') ...[
                  const SizedBox(height: 24),
                  Text(
                    'نوع المطعم (التصنيف):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCuisine,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: _cuisineTypes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCuisine = val);
                      }
                    },
                  ),
                ],

                const SizedBox(height: 24),
                Text(
                  'العنوان وتحديد الموقع (إجباري):',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.glassmorphismDeco(cardColor: cardColor),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // GPS Location Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gpsDetermined
                              ? Colors.green
                              : AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _determineGPSPosition,
                        icon: Icon(
                          _gpsDetermined ? Icons.check_circle : Icons.gps_fixed,
                        ),
                        label: Text(
                          _gpsDetermined
                              ? 'تم تحديد موقع GPS بنجاح'
                              : 'تحديد موقعي الحالي بالـ GPS (إجباري)',
                        ),
                      ),
                      if (!_gpsDetermined) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '* يرجى النقر أعلاه لتثبيت إحداثيات موقعك الجغرافي',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Governorate Dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedGovernorate,
                        decoration: InputDecoration(
                          labelText: 'المحافظة',
                          prefixIcon: const Icon(Icons.map_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: _governorates
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (val) => _onGovernorateChanged(val, auth),
                        validator: (v) =>
                            v == null ? 'يرجى اختيار المحافظة' : null,
                      ),
                      const SizedBox(height: 16),

                      // Region Dropdown / Input
                      if (_selectedGovernorate != null) ...[
                        if (_loadingRegions)
                          const Center(child: CircularProgressIndicator())
                        else ...[
                          DropdownButtonFormField<String>(
                            value: _selectedRegion,
                            decoration: InputDecoration(
                              labelText: 'المنطقة',
                              prefixIcon: const Icon(
                                Icons.location_city_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: [
                              ..._availableRegions.map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              ),
                              const DropdownMenuItem(
                                value: 'manual_entry',
                                child: Text('+ منطقة أخرى (كتابة يدوية)'),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                if (val == 'manual_entry') {
                                  _isManualRegion = true;
                                  _selectedRegion = null;
                                } else {
                                  _isManualRegion = false;
                                  _selectedRegion = val;
                                }
                              });
                            },
                            validator: (v) => (v == null && !_isManualRegion)
                                ? 'يرجى اختيار المنطقة'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // Manual Region Field
                      if (_isManualRegion) ...[
                        TextFormField(
                          controller: _regionTextController,
                          decoration: InputDecoration(
                            labelText: 'اكتب اسم منطقتك',
                            prefixIcon: const Icon(
                              Icons.edit_location_alt_outlined,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (v) =>
                              (_isManualRegion && (v == null || v.isEmpty))
                              ? 'يرجى إدخال اسم المنطقة'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Detailed Address
                      TextFormField(
                        controller: _detailsController,
                        decoration: InputDecoration(
                          labelText:
                              'العنوان التفصيلي (مثال: الحارة - الشارع - بيت أبوخليل)',
                          prefixIcon: const Icon(Icons.home_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v!.isEmpty ? 'يرجى إدخال تفاصيل العنوان' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                auth.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _submit(auth),
                        child: const Text('تسجيل الحساب'),
                      ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.grey.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  color: isSelected
                      ? Colors.white
                      : Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_gpsDetermined || _detectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'الرجاء النقر على زر "تحديد موقعي الحالي بالـ GPS" أولاً لتأكيد إحداثيات موقعك الجغرافي',
          ),
        ),
      );
      return;
    }

    final finalRegion = _isManualRegion
        ? _regionTextController.text.trim()
        : _selectedRegion;
    if (finalRegion == null || finalRegion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار أو كتابة اسم المنطقة')),
      );
      return;
    }

    final userAddress = model.Address(
      governorate: _selectedGovernorate,
      region: finalRegion,
      details: _detailsController.text.trim(),
      street: _detailsController.text.trim(), // compatible field
      city: _selectedGovernorate, // compatible field
      location: model.Location(
        coordinates: [
          _detectedPosition!.longitude,
          _detectedPosition!.latitude,
        ],
      ),
    );

    final err = await auth.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      role: _selectedRole,
      cuisineType: _selectedRole == 'restaurant' ? _selectedCuisine : null,
      address: userAddress,
    );

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.redAccent),
      );
    } else {
      _routeUser(auth.currentUser!.role);
    }
  }

  void _routeUser(String role) {
    if (role == 'customer') {
      Navigator.pushReplacementNamed(context, '/customer-home');
    } else if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/driver-home');
    } else if (role == 'restaurant') {
      Navigator.pushReplacementNamed(context, '/restaurant-home');
    }
  }
}
