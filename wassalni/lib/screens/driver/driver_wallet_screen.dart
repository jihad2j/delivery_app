// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:graphify/graphify.dart';

import '../../providers/providers.dart';
import '../../core/theme.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// 📜 1️⃣ شاشة سجل الطلبات والتصدير (Driver Orders History Screen)
/// ════════════════════════════════════════════════════════════════════════════
/// تعرض تفاصيل أحدث الطلبات المنجزة للكابتن وحساب إجمالي أرباح التوصيل
/// وتوفر خيارات تصفية سريعة (آخر 20 طلب / جميع الطلبات).
class DriverOrdersHistoryScreen extends StatefulWidget {
  const DriverOrdersHistoryScreen({super.key});

  @override
  State<DriverOrdersHistoryScreen> createState() =>
      _DriverOrdersHistoryScreenState();
}

class _DriverOrdersHistoryScreenState
    extends State<DriverOrdersHistoryScreen> {
  /// تفعيل خيار الفلترة لعرض آخر 20 طلب أو كافة السجلات
  bool _filterLast20 = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final op = context.watch<OrderProvider>();

    // جلب جميع طلبات السائق الحالية وترتيبها حسب الأحدث
    final allOrders = op.orders
        .where((o) => o.driverIdStr == auth.currentUser?.id)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.now())
          .compareTo(a.createdAt ?? DateTime.now()));

    final displayed = _filterLast20 ? allOrders.take(20).toList() : allOrders;
    
    // حساب مجموع أرباح التوصيل للطلبات المعروضة
    final totalEarn =
        displayed.fold(0.0, (sum, item) => sum + item.deliveryFee);

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات والتصدير')),
      body: Column(
        children: [
          // شريط خيارات تصفية الطلبات
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FilterChip(
                  selected: _filterLast20,
                  label: const Text('آخر 20 طلب'),
                  onSelected: (_) => setState(() => _filterLast20 = true),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: !_filterLast20,
                  label: Text('الكل (${allOrders.length})'),
                  onSelected: (_) => setState(() => _filterLast20 = false),
                ),
              ],
            ),
          ),
          
          // قائمة الطلبات المنجزة
          Expanded(
            child: displayed.isEmpty
                ? const Center(child: Text('لا توجد طلبات في السجل'))
                : ListView.builder(
                    itemCount: displayed.length,
                    itemBuilder: (ctx, idx) {
                      final o = displayed[idx];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(
                              'طلب #${o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id}'),
                          subtitle: Text(
                              'أجر التوصيل: ${o.deliveryFee.toStringAsFixed(0)} ل.س'),
                          trailing: Chip(
                            label: Text(
                                o.status == 'delivered' ? 'مكتمل' : o.status,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10)),
                            backgroundColor: o.status == 'delivered'
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // إجمالي الأرباح السفلية
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إجمالي الأرباح (${displayed.length} طلب):',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${totalEarn.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 💳 2️⃣ شاشة المحفظة والرصيد (Driver Wallet & Analytics Screen)
/// ════════════════════════════════════════════════════════════════════════════
/// تعلن هذه الشاشة عن الأرباح المكتسبة، كاش الزبائن المستلم، وتتيح طلب الترصيد،
/// مع رسم بياني تفاعلي (Graphify) يوضح أرباح الأسبوع واليوم للكابتن.
class DriverWalletScreen extends StatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  State<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends State<DriverWalletScreen> {
  bool _isProcessing = false;
  final GraphifyController _earningsChartCtrl = GraphifyController();

  @override
  void dispose() {
    _earningsChartCtrl.dispose();
    super.dispose();
  }

  /// طلب ترصيد المحفظة أو تسديد مبالغ الكاش للإدارة
  Future<void> _requestSettlement(String type, String title) async {
    final auth = context.read<AuthProvider>();
    setState(() => _isProcessing = true);
    try {
      final err =
          await auth.requestDriverSettlement(auth.currentUser?.id ?? '', type);
      if (!mounted) return;
      if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال طلب الترصيد بنجاح')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final earnings = user?.driverEarningsWallet ?? 0.0;
    final cash = user?.customerPaymentsWallet ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة والرصيد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // بطاقات الأرباح الحالية ومحفظة الكاش
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.green.shade800,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('أرباح التوصيل',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('${earnings.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade900,
                              minimumSize: const Size(double.infinity, 32),
                            ),
                            onPressed: _isProcessing || earnings <= 0
                                ? null
                                : () => _requestSettlement(
                                    'earnings', 'قبض الأرباح'),
                            child: const Text('قبض',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    color: Colors.orange.shade900,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('كاش الزبائن',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('${cash.toStringAsFixed(0)} ل.س',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.orange.shade900,
                              minimumSize: const Size(double.infinity, 32),
                            ),
                            onPressed: _isProcessing || cash <= 0
                                ? null
                                : () =>
                                    _requestSettlement('cash', 'تسديد الكاش'),
                            child: const Text('تسديد',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // الرسم البياني لأرباح الأسبوع
            const Text(
              'أرباح آخر 7 أيام',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 180,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: GraphifyView(
                controller: _earningsChartCtrl,
                initialOptions: const {
                  "tooltip": {"trigger": "axis"},
                  "xAxis": {
                    "type": "category",
                    "boundaryGap": false,
                    "data": [
                      "السبت",
                      "الأحد",
                      "الاثنين",
                      "الثلاثاء",
                      "الأربعاء",
                      "الخميس",
                      "الجمعة"
                    ]
                  },
                  "yAxis": {"type": "value"},
                  "series": [
                    {
                      "data": [35000, 42000, 31000, 50000, 48000, 60000, 85000],
                      "type": "line",
                      "smooth": true,
                      "areaStyle": {},
                      "itemStyle": {"color": "#4CAF50"}
                    }
                  ]
                },
              ),
            ),
            const SizedBox(height: 24),
            
            // سجل الرحلات المنجزة ومربعات الإحصائيات
            const Text(
              'سجل الرحلات المنجزة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, orderProv, _) {
                  final driverOrders = orderProv.orders
                      .where((o) =>
                          o.driverIdStr == user?.id && o.status == 'delivered')
                      .toList();

                  final now = DateTime.now();
                  double todayEarnings = 0;
                  double weekEarnings = 0;

                  for (var o in driverOrders) {
                    final date = o.createdAt ?? DateTime.now();
                    if (date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day) {
                      todayEarnings += o.deliveryFee;
                    }
                    if (now.difference(date).inDays <= 7) {
                      weekEarnings += o.deliveryFee;
                    }
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                                title: 'أرباح اليوم', value: todayEarnings),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                                title: 'أرباح الأسبوع', value: weekEarnings),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'آخر عمليات التوصيل',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: driverOrders.isEmpty
                            ? const Center(child: Text('لا يوجد طلبات مكتملة'))
                            : ListView.builder(
                                itemCount: driverOrders.length,
                                itemBuilder: (ctx, i) {
                                  final o = driverOrders[i];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      title: Text(
                                          'طلب #${o.id.substring(o.id.length > 6 ? o.id.length - 6 : 0)}'),
                                      subtitle: Text(o.createdAt != null
                                          ? o.createdAt
                                              .toString()
                                              .substring(0, 16)
                                          : ''),
                                      trailing: Text(
                                          '+${o.deliveryFee.toStringAsFixed(0)} ل.س',
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
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

/// 📊 مربع إحصائي زجاجي لحساب أرباح اليوم أو الأسبوع
class _StatBox extends StatelessWidget {
  final String title;
  final double value;

  const _StatBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(color: AppTheme.primary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(0)} ل.س',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}
