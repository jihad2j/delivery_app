// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/providers.dart';
import '../../core/theme.dart';
import 'driver_wallet_screen.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// 🚪 القائمة الجانبية لسائق التوصيل (Driver App Drawer)
/// ════════════════════════════════════════════════════════════════════════════
/// تحتوي هذه القائمة على ملف السائق، عرض الرصيد المحفظي، التوجه إلى سجل الطلبات،
/// وتسجيل الخروج الآمن.
class DriverAppDrawer extends StatelessWidget {
  const DriverAppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Drawer(
      child: Column(
        children: [
          // 👤 ترويسة ملف الكابتن الشخصي
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.name.isNotEmpty == true
                    ? user!.name.substring(0, 1).toUpperCase()
                    : 'D',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
            accountName: Text(
              user?.name ?? 'الكابتن',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(user?.phone ?? ''),
          ),

          // 📊 سجل الطلبات والتصدير
          ListTile(
            leading: const Icon(Icons.table_chart_rounded, color: Colors.blue),
            title: const Text('سجل الطلبات والتصدير'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverOrdersHistoryScreen(),
                ),
              );
            },
          ),

          // 💰 المحفظة والأرباح المكتسبة
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded,
                color: Colors.green),
            title: const Text('المحفظة والرصيد'),
            trailing: Chip(
              label: Text(
                '${user?.balance.toStringAsFixed(0)} ل.س',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              backgroundColor: Colors.green,
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverWalletScreen(),
                ),
              );
            },
          ),

          const Spacer(),
          const Divider(),

          // 🚪 تسجيل الخروج الآمن
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
