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
  int _activeDrivers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrderProvider>().loadOrders();
    });
    _fetchActiveDrivers();
  }

  Future<void> _fetchActiveDrivers() async {
    try {
      final res = await ApiService.get('/api/admin/users?role=driver');
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        int count = 0;
        for (final d in list) {
          if (d['driverInfo']?['availability'] == true) count++;
        }
        if (mounted) setState(() => _activeDrivers = count);
      }
    } catch (_) {}
  }

  void _openModule(BuildContext context, AdminPermissionItem perm) {
    final Widget screen;
    switch (perm.key) {
      case 'users_management':
        screen = const AdminUsersScreen();
        break;
      case 'drivers_management':
        screen = const AdminDriversScreen();
        break;
      case 'restaurants_management':
        screen = const AdminRestaurantsScreen();
        break;
      case 'orders_management':
        screen = const AdminOrdersScreen();
        break;
      case 'balances_management':
        screen = const AdminBalancesScreen();
        break;
      default:
        screen = const AdminPermissionsScreen();
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentUser = auth.currentUser;

    if (currentUser == null || currentUser.role != 'admin') {
      return const Scaffold(
        body: Center(child: Text('غير مصرح لك بالدخول لهذه الصفحة')),
      );
    }

    final allowedPermissions = allAdminPermissions.where((item) {
      return currentUser.hasAdminPermission(item.key);
    }).toList();

    final orderProv = Provider.of<OrderProvider>(context);
    final allOrders = orderProv.orders;
    final currentOrders = allOrders
        .where((o) => const {
              'pending',
              'restaurant_accepted',
              'preparing',
              'ready',
              'delivery_accepted',
              'onTheWay',
              'delivered_pending',
            }.contains(o.status))
        .length;
    final ongoingOrders = allOrders
        .where((o) => const {'delivery_accepted', 'onTheWay', 'delivered_pending'}.contains(o.status))
        .length;
    final completedOrders = allOrders
        .where((o) => const {'delivered', 'completed'}.contains(o.status))
        .length;

    if (allowedPermissions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.primaryGradient().copyWith(
            borderRadius: BorderRadius.zero,
            boxShadow: const [],
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 44),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'لا توجد صفحات مخصصة لك حالياً',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يرجى مراجعة مدير النظام لتحديد صلاحياتك',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryDark,
                      ),
                      onPressed: () async {
                        await auth.logout();
                        if (!mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('تسجيل الخروج'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Hero header with admin identity
          SliverAppBar(
            expandedHeight: 208,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryDark,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                tooltip: 'تسجيل الخروج',
                onPressed: () async {
                  await auth.logout();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Container(
                decoration: AppTheme.primaryGradient().copyWith(
                  borderRadius: BorderRadius.zero,
                  boxShadow: const [],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 2),
                              ),
                              child: Text(
                                currentUser.name.isNotEmpty
                                    ? currentUser.name.substring(0, 1).toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً، ${currentUser.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'أدمن النظام — ${currentUser.email}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'لديك ${allowedPermissions.length} وحدات إدارة متاحة',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
          ),

          // 2. Dashboard overview stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insights_rounded, color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'نظرة عامة',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _DashboardStats(
                    currentOrders: currentOrders,
                    completedOrders: completedOrders,
                    ongoingOrders: ongoingOrders,
                    activeDrivers: _activeDrivers,
                  ),
                ],
              ),
            ),
          ),

          // 3. Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dashboard_customize_rounded, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'مركز التحكم',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'تحديث البيانات',
                    onPressed: () {
                      context.read<OrderProvider>().loadOrders();
                      _fetchActiveDrivers();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
          ),

          // 4. Modules grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 180,
              ),
              delegate: SliverChildBuilderDelegate((context, idx) {
                final perm = allowedPermissions[idx];
                return _AdminModuleCard(
                  item: perm,
                  onTap: () => _openModule(context, perm),
                );
              }, childCount: allowedPermissions.length),
            ),
          ),
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
      appBar: _AdminModuleAppBar(
        title: 'إدارة صلاحيات الأدمنية',
        icon: Icons.admin_panel_settings_rounded,
        color: Colors.redAccent,
        trailing: IconButton(
          onPressed: _loadAdmins,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
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

  String _roleLabel(String? role) {
    switch (role) {
      case 'driver':
        return 'كابتن توصيل';
      case 'restaurant':
        return 'مطعم';
      case 'customer':
        return 'عميل';
      default:
        return role ?? 'غير محدد';
    }
  }

  Widget _buildRoleChip(String value, String label, IconData icon) {
    final selected = _filterRole == value;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 15, color: selected ? Colors.white : Colors.blue),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: selected ? Colors.white : null,
        ),
      ),
      selectedColor: Colors.blue,
      backgroundColor: Theme.of(context).cardColor,
      showCheckmark: false,
      onSelected: (_) {
        if (_filterRole != value) {
          _filterRole = value;
          _fetchUsers();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _AdminModuleAppBar(
        title: 'إدارة المستخدمين',
        icon: Icons.people_alt_rounded,
        color: Colors.blue,
        trailing: IconButton(
          onPressed: _fetchUsers,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleChip('all', 'الجميع', Icons.group_rounded),
                        const SizedBox(width: 8),
                        _buildRoleChip('customer', 'العملاء', Icons.person_rounded),
                        const SizedBox(width: 8),
                        _buildRoleChip('driver', 'الكباتن', Icons.directions_bike_rounded),
                        const SizedBox(width: 8),
                        _buildRoleChip('restaurant', 'المطاعم', Icons.restaurant_rounded),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_users.length}',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text(
                              'لا يوجد مستخدمون',
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        itemBuilder: (context, idx) {
                          final u = _users[idx];
                          final isBlocked = u['status'] == 'blocked';
                          final role = u['role'] as String?;
                          final roleColor = role == 'driver'
                              ? Colors.teal
                              : (role == 'restaurant' ? Colors.orange : Colors.blue);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isBlocked
                                    ? Colors.red.withValues(alpha: 0.3)
                                    : Colors.grey.withValues(alpha: 0.15),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _toggleStatus(u['_id'], isBlocked ? 'active' : 'blocked'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isBlocked ? Colors.red.withValues(alpha: 0.15) : roleColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        role == 'driver'
                                            ? Icons.directions_bike_rounded
                                            : (role == 'restaurant' ? Icons.restaurant_rounded : Icons.person_rounded),
                                        color: isBlocked ? Colors.red : roleColor,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            u['name'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${u['phone'] ?? ''} • ${_roleLabel(role)}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (isBlocked ? Colors.red : Colors.green).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isBlocked ? Icons.block_rounded : Icons.verified_user_rounded,
                                            size: 14,
                                            color: isBlocked ? Colors.red : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isBlocked ? 'محظور' : 'مفعّل',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isBlocked ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
      appBar: _AdminModuleAppBar(
        title: 'إدارة عمال التوصيل',
        icon: Icons.directions_bike_rounded,
        color: Colors.teal,
        trailing: IconButton(
          onPressed: _fetchDrivers,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
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
      appBar: _AdminModuleAppBar(
        title: 'إدارة المطاعم',
        icon: Icons.restaurant_rounded,
        color: Colors.orange,
        trailing: IconButton(
          onPressed: _fetchRestaurants,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
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

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'restaurant_accepted':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready':
        return Colors.teal;
      case 'delivery_accepted':
        return Colors.indigo;
      case 'onTheWay':
        return Colors.lightBlue;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'جديد';
      case 'restaurant_accepted':
        return 'في المطعم';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'جاهز للتوصيل';
      case 'delivery_accepted':
        return 'مع الكابتن';
      case 'onTheWay':
        return 'في الطريق';
      case 'delivered':
        return 'تم التوصيل';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProv = Provider.of<OrderProvider>(context);
    final orders = orderProv.orders;

    return Scaffold(
      appBar: _AdminModuleAppBar(
        title: 'إدارة الطلبات',
        icon: Icons.receipt_long_rounded,
        color: Colors.purple,
        trailing: IconButton(
          onPressed: () => orderProv.loadOrders(),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
      body: orders.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                    'لا توجد طلبات مسجلة في النظام حالياً',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => orderProv.loadOrders(),
              child: ListView.builder(
                itemCount: orders.length,
                padding: const EdgeInsets.all(12),
                itemBuilder: (context, idx) {
                  final o = orders[idx];
                  final idStr = o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id;
                  final statusColor = _statusColor(o.status);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: statusColor.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, color: statusColor, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'طلب #$idStr',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel(o.status),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          child: Row(
                            children: [
                              _miniStat(
                                Icons.payments_rounded,
                                'إجمالي المبلغ',
                                '${o.totalAmount.toStringAsFixed(0)} ل.س',
                                Colors.green,
                              ),
                              _miniStat(
                                Icons.delivery_dining_rounded,
                                'أجر التوصيل',
                                '${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                Colors.blue,
                              ),
                              _miniStat(
                                Icons.shopping_bag_rounded,
                                'الأصناف',
                                '${o.items.length}',
                                Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
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
      appBar: _AdminModuleAppBar(
        title: 'إدارة الرصيد والترصيد',
        icon: Icons.account_balance_wallet_rounded,
        color: Colors.green,
        trailing: IconButton(
          onPressed: _fetchBalancesData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
      ),
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
                        final cash = (d['customerPaymentsWallet'] is num)
                            ? (d['customerPaymentsWallet'] as num).toDouble()
                            : (double.tryParse(d['customerPaymentsWallet']?.toString() ?? '') ?? 0.0);
                        final earnings = (d['driverEarningsWallet'] is num)
                            ? (d['driverEarningsWallet'] as num).toDouble()
                            : (double.tryParse(d['driverEarningsWallet']?.toString() ?? '') ?? 0.0);
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

// ============================================================================
// عناصر مساعدة مشتركة للشكل الجديد
// ============================================================================

/// شريط علوي متدرج موحد لكل وحدات الإدارة
class _AdminModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget? trailing;

  const _AdminModuleAppBar({
    required this.title,
    required this.icon,
    required this.color,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.82), AppTheme.primary],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (canPop)
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة إحصائيات نظرة عامة أعلى مركز التحكم
class _DashboardStats extends StatelessWidget {
  final int currentOrders;
  final int completedOrders;
  final int ongoingOrders;
  final int activeDrivers;

  const _DashboardStats({
    required this.currentOrders,
    required this.completedOrders,
    required this.ongoingOrders,
    required this.activeDrivers,
  });

  Widget _tile(BuildContext context, IconData icon, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _tile(context, Icons.receipt_long_rounded, 'الطلبات الحالية', '$currentOrders', Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile(context, Icons.check_circle_rounded, 'الطلبات المكتملة', '$completedOrders', Colors.blue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _tile(context, Icons.delivery_dining_rounded, 'طلبات جارية الآن', '$ongoingOrders', Colors.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tile(context, Icons.directions_bike_rounded, 'كباتن نشطون', '$activeDrivers', Colors.teal),
            ),
          ],
        ),
      ],
    );
  }
}

/// بطاقة وحدة إدارة في شبكة مركز التحكم
class _AdminModuleCard extends StatelessWidget {
  final AdminPermissionItem item;
  final VoidCallback onTap;

  const _AdminModuleCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.color.withValues(alpha: isDark ? 0.22 : 0.16),
                item.color.withValues(alpha: isDark ? 0.06 : 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: item.color.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_forward_rounded, size: 15, color: item.color),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
