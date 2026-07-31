// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../models/models.dart' as model;
import '../core/theme.dart';
import '../core/services.dart';

/// تعريف جميع صفحات وصلاحيات الأدمن المتاحة في النظام
class AdminPermissionItem {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const AdminPermissionItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

const List<AdminPermissionItem> allAdminPermissions = [
  AdminPermissionItem(
    key: 'users_management',
    title: 'إدارة المستخدمين',
    description: 'عرض وحظر وتفعيل حسابات العملاء والزبائن',
    icon: Icons.people_alt_rounded,
    color: Colors.blue,
  ),
  AdminPermissionItem(
    key: 'drivers_management',
    title: 'إدارة عمال التوصيل',
    description: 'إدارة الكباتن وسجلات التوصيل والمركبات',
    icon: Icons.directions_bike_rounded,
    color: Colors.teal,
  ),
  AdminPermissionItem(
    key: 'restaurants_management',
    title: 'إدارة المطاعم',
    description: 'إدارة بيانات المطاعم وحالات التشغيل والإغلاق',
    icon: Icons.restaurant_rounded,
    color: Colors.orange,
  ),
  AdminPermissionItem(
    key: 'orders_management',
    title: 'إدارة الطلبات',
    description: 'متابعة الطلبات المباشرة والحالات وتتبع التوصيل',
    icon: Icons.receipt_long_rounded,
    color: Colors.purple,
  ),
  AdminPermissionItem(
    key: 'balances_management',
    title: 'إدارة الرصيد والترصيد',
    description: 'محاسبة الكباتن، ترصيد الكاش وصرف المستحقات',
    icon: Icons.account_balance_wallet_rounded,
    color: Colors.green,
  ),
  AdminPermissionItem(
    key: 'permissions_management',
    title: 'إدارة صلاحيات الأدمنية',
    description: 'تخصيص الصفحات المسموحة لكل أدمن (أيمن، حسام...)',
    icon: Icons.admin_panel_settings_rounded,
    color: Colors.redAccent,
  ),
];

// ============================================================================
// 1. الشاشة الرئيسية لمدير النظام (تظهر الصلاحيات والصفحات المسموحة فقط)
// ============================================================================
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;

    if (currentUser == null || currentUser.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('غير مصرح لك بالدخول لهذه الصفحة')),
      );
    }

    // تصفية الصفحات بناءً على الصلاحيات المخصصة لهذا الأدمن
    final allowedPermissions = allAdminPermissions.where((item) {
      return currentUser.hasAdminPermission(item.key);
    }).toList();

    if (allowedPermissions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة الأدمن')),
        body: const Center(
          child: Text('لا توجد صفحات مخصصة لك حالياً. يرجى مراجعة المسؤول.'),
        ),
      );
    }

    if (_selectedIndex >= allowedPermissions.length) {
      _selectedIndex = 0;
    }

    final currentPerm = allowedPermissions[_selectedIndex];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: AppTheme.primaryGradient().copyWith(
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(currentPerm.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لوحة التحكم — ${currentUser.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentPerm.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      drawer: _buildAdminDrawer(context, auth, currentUser, allowedPermissions),
      body: _buildSelectedScreen(currentPerm.key),
    );
  }

  Widget _buildSelectedScreen(String permKey) {
    switch (permKey) {
      case 'users_management':
        return const AdminUsersScreen();
      case 'drivers_management':
        return const AdminDriversScreen();
      case 'restaurants_management':
        return const AdminRestaurantsScreen();
      case 'orders_management':
        return const AdminOrdersScreen();
      case 'balances_management':
        return const AdminBalancesScreen();
      case 'permissions_management':
        return const AdminPermissionsScreen();
      default:
        return const Center(child: Text('صفحة غير معروفة'));
    }
  }

  Widget _buildAdminDrawer(
    BuildContext context,
    AuthProvider auth,
    model.User currentUser,
    List<AdminPermissionItem> allowedPermissions,
  ) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade900, AppTheme.primary],
              ),
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings_rounded, size: 36, color: AppTheme.primary),
            ),
            accountName: Text(
              currentUser.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              'أدمن (${currentUser.email})',
              style: const TextStyle(fontSize: 12),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الصفحات المتاحة لك (${allowedPermissions.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: allowedPermissions.length,
              itemBuilder: (context, idx) {
                final perm = allowedPermissions[idx];
                final isSelected = _selectedIndex == idx;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? perm.color.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: perm.color, width: 1.2) : null,
                  ),
                  child: ListTile(
                    leading: Icon(perm.icon, color: perm.color),
                    title: Text(
                      perm.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? perm.color : null,
                      ),
                    ),
                    subtitle: Text(
                      perm.description,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedIndex = idx);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. صفحة إدارة صلاحيات الأدمنية (خاصة بمدير النظام/السوبر أدمن)
// ============================================================================
class AdminPermissionsScreen extends StatefulWidget {
  const AdminPermissionsScreen({super.key});

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  List<model.User> _admins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminsList = await auth.fetchAllAdmins();
    if (mounted) {
      setState(() {
        _admins = adminsList;
        _isLoading = false;
      });
    }
  }

  void _editPermissionsDialog(model.User adminUser) {
    final List<String> currentPerms = List<String>.from(adminUser.adminPermissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'صلاحيات: ${adminUser.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'حدد الصفحات المسموح لهذا الأدمن بالدخول إليها:',
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...allAdminPermissions.map((perm) {
                      final isChecked = currentPerms.contains(perm.key);
                      return CheckboxListTile(
                        activeColor: perm.color,
                        secondary: Icon(perm.icon, color: perm.color),
                        title: Text(perm.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(perm.description, style: const TextStyle(fontSize: 10)),
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              if (!currentPerms.contains(perm.key)) currentPerms.add(perm.key);
                            } else {
                              currentPerms.remove(perm.key);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final err = await auth.updateAdminPermissions(adminUser.id, currentPerms);
                  if (mounted) {
                    if (err == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم حفظ وتحديث صلاحيات ${adminUser.name} بنجاح'), backgroundColor: Colors.green),
                      );
                      _loadAdmins();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('حفظ الصلاحيات'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  child: const Row(
                    children: [
                      Icon(Icons.security_rounded, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'نظام تخصيص الصلاحيات للأدمنية: اختر لكل أدمن الصفحات المسموحة له بشكل مستقل.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView.builder(
                    itemCount: _admins.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, idx) {
                      final adminUser = _admins[idx];
                      final perms = adminUser.adminPermissions;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                    child: Text(adminUser.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(adminUser.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text('${adminUser.email} • ${adminUser.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () => _editPermissionsDialog(adminUser),
                                    icon: const Icon(Icons.edit_rounded, size: 16),
                                    label: const Text('تخصيص الصلاحيات', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              const Text('الصفحات المتاحة له حالياً:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: allAdminPermissions.map((item) {
                                  final hasIt = perms.contains(item.key);
                                  return Chip(
                                    avatar: Icon(item.icon, size: 14, color: hasIt ? Colors.white : Colors.grey),
                                    label: Text(item.title, style: TextStyle(fontSize: 10, color: hasIt ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                                    backgroundColor: hasIt ? item.color : Colors.grey.withValues(alpha: 0.2),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================================
// 3. صفحة إدارة المستخدمين والعملاء
// ============================================================================
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final query = _filterRole != 'all' ? '?role=$_filterRole' : '';
      final res = await ApiService.get('/api/admin/users$query');
      if (res.statusCode == 200) {
        setState(() {
          _users = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(String userId, String newStatus) async {
    try {
      final res = await ApiService.put('/api/admin/users/$userId/status', {'status': newStatus});
      if (res.statusCode == 200) {
        _fetchUsers();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                const Text('تصفية حسب الدور:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filterRole,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('جميع المستخدمين')),
                    DropdownMenuItem(value: 'customer', child: Text('العملاء والزبائن')),
                    DropdownMenuItem(value: 'driver', child: Text('عمال التوصيل')),
                    DropdownMenuItem(value: 'restaurant', child: Text('المطاعم')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _filterRole = val;
                      _fetchUsers();
                    }
                  },
                ),
                const Spacer(),
                Text('العدد: ${_users.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _users.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, idx) {
                      final u = _users[idx];
                      final isBlocked = u['status'] == 'blocked';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isBlocked ? Colors.red : Colors.blue,
                            child: Icon(
                              u['role'] == 'driver'
                                  ? Icons.directions_bike
                                  : (u['role'] == 'restaurant' ? Icons.restaurant : Icons.person),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${u['phone'] ?? ''} • ${u['role']}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) => _toggleStatus(u['_id'], val),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'active', child: Text('تفعيل الحساب (Active)')),
                              const PopupMenuItem(value: 'blocked', child: Text('حظر الحساب (Blocked)')),
                            ],
                            child: Chip(
                              label: Text(u['status'] ?? 'active', style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: isBlocked ? Colors.red : Colors.green,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. صفحة إدارة عمال التوصيل (الكباتن)
// ============================================================================
class AdminDriversScreen extends StatefulWidget {
  const AdminDriversScreen({super.key});

  @override
  State<AdminDriversScreen> createState() => _AdminDriversScreenState();
}

class _AdminDriversScreenState extends State<AdminDriversScreen> {
  List<dynamic> _drivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/api/admin/users?role=driver');
      if (res.statusCode == 200) {
        setState(() {
          _drivers = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _drivers.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, idx) {
                final d = _drivers[idx];
                final isAvailable = d['driverInfo']?['availability'] == true;
                final cash = (d['customerPaymentsWallet'] ?? 0).toDouble();
                final earnings = (d['driverEarningsWallet'] ?? 0).toDouble();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(Icons.directions_bike_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(d['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(isAvailable ? 'متصل وجاهز' : 'متوقف', style: const TextStyle(fontSize: 10, color: Colors.white)),
                              backgroundColor: isAvailable ? Colors.green : Colors.grey,
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('كاش الزبائن بيده: ${cash.toStringAsFixed(0)} ل.س', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('أرباح التوصيل: ${earnings.toStringAsFixed(0)} ل.س', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 5. صفحة إدارة المطاعم
// ============================================================================
class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  List<dynamic> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/api/admin/users?role=restaurant');
      if (res.statusCode == 200) {
        setState(() {
          _restaurants = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _restaurants.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, idx) {
                final r = _restaurants[idx];
                final rInfo = r['restaurantInfo'] ?? {};
                final status = rInfo['status'] ?? 'open';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.orange,
                      child: Icon(Icons.restaurant_rounded, color: Colors.white),
                    ),
                    title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${rInfo['cuisineType'] ?? 'مطعم'} • أدنى طلب: ${rInfo['minOrderAmount'] ?? 0} ل.س'),
                    trailing: Chip(
                      label: Text(status == 'open' ? 'مفتوح' : (status == 'closed' ? 'مغلق' : 'مشغول'), style: const TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: status == 'open' ? Colors.green : (status == 'closed' ? Colors.red : Colors.orange),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 6. صفحة إدارة الطلبات المباشرة
// ============================================================================
class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final orders = orderProv.orders;

    return Scaffold(
      body: orders.isEmpty
          ? const Center(child: Text('لا توجد طلبات مسجلة في النظام حالياً'))
          : ListView.builder(
              itemCount: orders.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, idx) {
                final o = orders[idx];
                final idStr = o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.purple,
                      child: Icon(Icons.receipt_long_rounded, color: Colors.white),
                    ),
                    title: Text('طلب #$idStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('المبلغ: ${o.totalAmount.toStringAsFixed(0)} ل.س • التوصيل: ${o.deliveryFee.toStringAsFixed(0)} ل.س'),
                    trailing: Chip(
                      label: Text(o.status, style: const TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: o.status == 'delivered' ? Colors.green : Colors.purple,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 7. صفحة إدارة الحسابات والترصيد للمحاسب
// ============================================================================
class AdminBalancesScreen extends StatefulWidget {
  const AdminBalancesScreen({super.key});

  @override
  State<AdminBalancesScreen> createState() => _AdminBalancesScreenState();
}

class _AdminBalancesScreenState extends State<AdminBalancesScreen> {
  List<dynamic> _drivers = [];
  double _companyTreasury = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBalancesData();
  }

  Future<void> _fetchBalancesData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final treasury = await auth.fetchCompanyTreasury();
      final res = await ApiService.get('/api/admin/users?role=driver');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _companyTreasury = treasury;
          _drivers = jsonDecode(res.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestSettlement(dynamic driver, String settlementType) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final driverName = driver['name'] ?? 'الكابتن';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب ترصيد من السائق'),
        content: Text('سيتم إرسال طلب إشعار وتأكيد لـ ($driverName) لترصيد وتصفير (${settlementType == 'cash' ? 'كاش الزبائن' : 'أرباح التوصيل'}). هل ترغب بمتابعة الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال طلب الترصيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final err = await auth.requestDriverSettlement(driver['_id'], settlementType);
      if (mounted) {
        if (err == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إرسال طلب الترصيد لـ $driverName بنجاح وبانتظار موافقته'), backgroundColor: Colors.green),
          );
          _fetchBalancesData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchBalancesData,
              child: Column(
                children: [
                  // Company Treasury Header Card
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text('خزينة الشركة والسيولة النقدية المجمعة:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_companyTreasury.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(fontFamily: 'Outfit', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'ملاحظة: هذا المبلغ يمثل إجمالي كاش المبيعات المجمع من عمال التوصيل والمحولة لصندوق الشركة.',
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('حسابات ذمم وأرباح عمال التوصيل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _drivers.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemBuilder: (context, idx) {
                        final d = _drivers[idx];
                        final cash = (d['customerPaymentsWallet'] ?? 0).toDouble();
                        final earnings = (d['driverEarningsWallet'] ?? 0).toDouble();
                        final pending = d['pendingSettlement'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade800,
                                      child: Text(d['name']?.substring(0, 1).toUpperCase() ?? 'D', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text(d['phone'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    if (pending != null && pending['requestId'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 14),
                                            SizedBox(width: 4),
                                            Text('بانتظار موافقة الكابتن', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const Divider(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('كاش بيده (ذمة المطلوب)', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text('${cash.toStringAsFixed(0)} ل.س', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.orange.shade900, fontSize: 15)),
                                            const SizedBox(height: 6),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange.shade800,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                onPressed: cash <= 0 ? null : () => _requestSettlement(d, 'cash'),
                                                child: const Text('طلب سحب الكاش', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('أرباح التوصيل (مستحقاته)', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text('${earnings.toStringAsFixed(0)} ل.س', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 15)),
                                            const SizedBox(height: 6),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                  padding: EdgeInsets.zero,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                onPressed: earnings <= 0 ? null : () => _requestSettlement(d, 'earnings'),
                                                child: const Text('طلب صرف الأرباح', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
