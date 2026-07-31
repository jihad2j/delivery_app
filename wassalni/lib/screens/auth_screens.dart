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
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

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
        decoration: AppTheme.primaryGradient(),
        child: Center(
          child: ScaleTransition(
            scale: _animation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_bike_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'وصلني',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'توصيل سريع وأمان كامل',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
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
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _rememberMe = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primary.withValues(alpha: 0.08),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeIn,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (kDebugMode)
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 20),
                          onPressed: _showSettingsDialog,
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Logo area
                    Container(
                      width: 80,
                      height: 80,
                      decoration: AppTheme.primaryGradient(borderRadius: BorderRadius.circular(22)),
                      child: const Icon(Icons.directions_bike_rounded, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text('وصلني', style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('توصيل سريع وأمان كامل', style: textTheme.bodyMedium),
                    const SizedBox(height: 32),
                    // Form card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: AppTheme.glassCard(cardColor: Theme.of(context).cardColor),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (v) => v!.isEmpty ? 'يرجى إدخال البريد الإلكتروني' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (val) => setState(() => _rememberMe = val ?? true),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Text('تذكرني', style: textTheme.bodyMedium),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _showForgotPassword(),
                                child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: auth.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : DecoratedBox(
                              decoration: AppTheme.primaryGradient(borderRadius: BorderRadius.circular(16)),
                              child: ElevatedButton.icon(
                                onPressed: () => _submit(auth),
                                icon: const Icon(Icons.login_rounded, size: 20),
                                label: const Text('تسجيل الدخول'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('ليس لديك حساب؟', style: textTheme.bodyMedium),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/register'),
                          child: const Text('سجل الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
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
          decoration: const InputDecoration(hintText: 'http://192.168.1.x:3000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () async {
              await ApiService.setBaseUrl(ipController.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث عنوان السيرفر بنجاح')));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('يرجى التواصل مع الدعم الفني لإعادة تعيين كلمة المرور')),
    );
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final err = await auth.login(_emailController.text, _passwordController.text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.redAccent));
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

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

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
    'دمشق', 'ريف دمشق', 'حلب', 'حمص', 'حماة', 'اللاذقية', 'طرطوس',
    'إدلب', 'دير الزور', 'الرقة', 'الحسكة', 'درعا', 'السويداء', 'القنيطرة',
  ];

  String _selectedRole = 'customer';
  String _selectedCuisine = 'مشاوي';
  bool _obscureText = true;

  final List<String> _cuisineTypes = ['مشروبات', 'حلويات', 'مشاوي', 'شاورما فروج'];

  int _passwordStrength = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _regionTextController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String v) {
    int score = 0;
    if (v.length >= 6) score++;
    if (v.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(v) || RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v)) score++;
    setState(() => _passwordStrength = score);
  }

  Color _strengthColor() {
    if (_passwordStrength <= 1) return Colors.redAccent;
    if (_passwordStrength <= 2) return Colors.orange;
    if (_passwordStrength <= 3) return Colors.amber;
    return AppTheme.primary;
  }

  String _strengthLabel() {
    if (_passwordStrength <= 1) return 'ضعيفة';
    if (_passwordStrength <= 2) return 'متوسطة';
    if (_passwordStrength <= 3) return 'جيدة';
    return 'قوية';
  }

  Future<void> _determineGPSPosition() async {
    final permissionError = await LocationHelper.checkAndRequestPermissions();
    if (permissionError != null) {
      String msg = 'حدث خطأ في صلاحية الموقع';
      if (permissionError == 'GPS_DISABLED') { msg = 'الرجاء تفعيل خدمة تحديد الموقع (GPS)'; }
      else if (permissionError == 'GPS_DENIED') { msg = 'تم رفض صلاحية تحديد موقعك الجغرافي'; }
      else if (permissionError == 'GPS_DENIED_FOREVER') { msg = 'صلاحية الموقع مرفوضة دائماً، الرجاء تفعيلها من الإعدادات'; }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('جاري تحديد موقعك الجغرافي...')]),
      ),
    );

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
      if (!mounted) return;
      Navigator.pop(context);
      setState(() { _detectedPosition = pos; _gpsDetermined = true; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تثبيت موقع GPS بنجاح')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل تحديد الموقع: $e')));
    }
  }

  Future<void> _onGovernorateChanged(String? val, AuthProvider auth) async {
    if (val == null) return;
    setState(() { _selectedGovernorate = val; _selectedRegion = null; _isManualRegion = false; _loadingRegions = true; _availableRegions = []; });
    final regions = await auth.fetchRegions(val);
    setState(() { _availableRegions = regions; _loadingRegions = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب جديد'),
        flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.primary.withValues(alpha: 0.06), Colors.transparent],
        ))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: FadeTransition(
            opacity: _fadeIn,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('انضم إلينا اليوم', style: textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('سجل حساباً جديداً لبدء استخدام تطبيق وصلني', style: textTheme.bodyMedium),
                  const SizedBox(height: 22),

                  // Personal Info section
                  _sectionHeader('المعلومات الشخصية', Icons.person_outline),
                  const SizedBox(height: 10),
                  _glassCard(
                    context,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline, size: 20)),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined, size: 20)),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال البريد الإلكتروني' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined, size: 20)),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال رقم الهاتف' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        onChanged: _updatePasswordStrength,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                        ),
                        validator: (v) => v!.length < 6 ? 'كلمة المرور يجب أن تكون 6 خانات فأكثر' : null,
                      ),
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _passwordStrength / 5,
                            backgroundColor: Colors.grey.withValues(alpha: 0.15),
                            color: _strengthColor(),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('قوة كلمة المرور: ${_strengthLabel()}', style: TextStyle(color: _strengthColor(), fontSize: 12, fontFamily: 'Outfit')),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Role section
                  _sectionHeader('نوع الحساب', Icons.category_outlined),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildRoleOption('customer', 'عميل', Icons.shopping_bag_outlined),
                      const SizedBox(width: 8),
                      _buildRoleOption('driver', 'كابتن', Icons.directions_bike_outlined),
                      const SizedBox(width: 8),
                      _buildRoleOption('restaurant', 'مطعم', Icons.restaurant_outlined),
                    ],
                  ),

                  if (_selectedRole == 'restaurant') ...[
                    const SizedBox(height: 20),
                    _glassCard(
                      context,
                      children: [
                        Text('نوع المطعم (التصنيف)', style: textTheme.titleMedium),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedCuisine,
                          decoration: const InputDecoration(prefixIcon: Icon(Icons.restaurant_menu_outlined, size: 20)),
                          items: _cuisineTypes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _selectedCuisine = val); },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Location section
                  _sectionHeader('العنوان وتحديد الموقع', Icons.location_on_outlined),
                  const SizedBox(height: 10),
                  _glassCard(
                    context,
                    children: [
                      // GPS
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: _gpsDetermined
                                  ? [AppColors.primaryLight, AppTheme.primary, AppTheme.primaryDark]
                                  : [AppTheme.primary, AppTheme.primaryDark],
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _determineGPSPosition,
                            icon: Icon(_gpsDetermined ? Icons.check_circle_rounded : Icons.gps_fixed_rounded, size: 20),
                            label: Text(_gpsDetermined ? 'تم تحديد موقع GPS بنجاح' : 'تحديد موقعي الحالي'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ),
                      if (!_gpsDetermined) ...[
                        const SizedBox(height: 6),
                        Text('* يجب تحديد موقع GPS للتسجيل', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontFamily: 'Outfit')),
                      ],
                      const SizedBox(height: 18),

                      // Governorate
                      DropdownButtonFormField<String>(
                        value: _selectedGovernorate,
                        decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.map_outlined, size: 20)),
                        items: _governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => _onGovernorateChanged(val, auth),
                        validator: (v) => v == null ? 'يرجى اختيار المحافظة' : null,
                      ),
                      const SizedBox(height: 16),

                      // Region
                      if (_selectedGovernorate != null)
                        _loadingRegions
                            ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 3)))
                            : DropdownButtonFormField<String>(
                                value: _selectedRegion,
                                decoration: const InputDecoration(labelText: 'المنطقة', prefixIcon: Icon(Icons.location_city_outlined, size: 20)),
                                items: [
                                  ..._availableRegions.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                                  const DropdownMenuItem(value: 'manual_entry', child: Text('+ منطقة أخرى (كتابة يدوية)')),
                                ],
                                onChanged: (val) { setState(() { if (val == 'manual_entry') { _isManualRegion = true; _selectedRegion = null; } else { _isManualRegion = false; _selectedRegion = val; } }); },
                                validator: (v) => (v == null && !_isManualRegion) ? 'يرجى اختيار المنطقة' : null,
                              ),
                      if (_isManualRegion) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _regionTextController,
                          decoration: const InputDecoration(labelText: 'اكتب اسم منطقتك', prefixIcon: Icon(Icons.edit_location_alt_outlined, size: 20)),
                          validator: (v) => (_isManualRegion && (v == null || v.isEmpty)) ? 'يرجى إدخال اسم المنطقة' : null,
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Address details
                      TextFormField(
                        controller: _detailsController,
                        decoration: const InputDecoration(labelText: 'العنوان التفصيلي', hintText: 'مثال: الحارة - الشارع - بناء', prefixIcon: Icon(Icons.home_outlined, size: 20)),
                        validator: (v) => v!.isEmpty ? 'يرجى إدخال تفاصيل العنوان' : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: auth.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : DecoratedBox(
                            decoration: AppTheme.primaryGradient(borderRadius: BorderRadius.circular(16)),
                            child: ElevatedButton.icon(
                              onPressed: () => _submit(auth),
                              icon: const Icon(Icons.person_add_rounded, size: 20),
                              label: const Text('إنشاء الحساب'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('لديك حساب بالفعل؟', style: textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _glassCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(cardColor: Theme.of(context).cardColor),
      child: Column(children: children),
    );
  }

  Widget _buildRoleOption(String role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color, size: 26),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(
                fontFamily: 'Outfit', fontSize: 13,
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_gpsDetermined || _detectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد موقع GPS أولاً'), backgroundColor: Colors.redAccent));
      return;
    }

    final finalRegion = _isManualRegion ? _regionTextController.text.trim() : _selectedRegion;
    if (finalRegion == null || finalRegion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار أو كتابة اسم المنطقة'), backgroundColor: Colors.redAccent));
      return;
    }

    final userAddress = model.Address(
      governorate: _selectedGovernorate,
      region: finalRegion,
      details: _detailsController.text.trim(),
      street: _detailsController.text.trim(),
      city: _selectedGovernorate,
      location: model.Location(coordinates: [_detectedPosition!.longitude, _detectedPosition!.latitude]),
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
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.redAccent));
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
