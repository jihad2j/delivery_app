// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/providers.dart';
import '../../models/models.dart' as model;
import '../../core/theme.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// 1️⃣ زر تفعيل الجاهزية والاستعداد (Online Toggle Chip)
/// ════════════════════════════════════════════════════════════════════════════
/// يعرض هذا الويدجت زر التبديل السريع بين حالة (جاهز لاستقبال الطلبات / متوقف)،
/// ويقوم بالتحقق من الحالات النشطة لمنع إيقاف التشغيل عند وجود طلب جاري.
class OnlineToggleChip extends StatelessWidget {
  final bool isOnline;
  final bool isBusy;
  final bool hasActiveOrder;
  final VoidCallback onToggle;

  const OnlineToggleChip({
    super.key,
    required this.isOnline,
    required this.isBusy,
    required this.hasActiveOrder,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // تحديد لون الزر حسب حالة الاتصال ووجود طلب نشط
    final color = hasActiveOrder
        ? (isOnline ? Colors.green.shade800 : Colors.grey.shade700)
        : (isOnline ? Colors.green.shade600 : Colors.red.shade700);

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: color,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: hasActiveOrder ? null : onToggle,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  isOnline
                      ? Icons.wifi_tethering_rounded
                      : Icons.power_settings_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              const SizedBox(width: 4),
              Text(
                isBusy ? 'جاري..' : (isOnline ? 'جاهز' : 'متوقف'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 2️⃣ شاشة فحص التشخيص المباشر (Diagnostic Panel Overlay)
/// ════════════════════════════════════════════════════════════════════════════
/// تعرض سجلات التشخيص الحية ومتابعة خطوات تواصل السيرفر والـ GPS لمساعدة
/// الكابتن في تتبع الأخطاء والتأكد من استقرار الاتصال.
class DiagnosticPanel extends StatelessWidget {
  final List<String> logs;
  final bool isBusy;
  final VoidCallback onClose;
  final VoidCallback onForceUnlock;

  const DiagnosticPanel({
    super.key,
    required this.logs,
    required this.isBusy,
    required this.onClose,
    required this.onForceUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.black.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bug_report_rounded,
                        color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'فحص التشخيص المباشر',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isBusy)
                      InkWell(
                        onTap: onForceUnlock,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'فك القفل الآن',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white70, size: 18),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: SingleChildScrollView(
                reverse: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: logs
                      .map((log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              log,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 3️⃣ بطاقات التسوية المالية المعلقة (Pending Settlement Card)
/// ════════════════════════════════════════════════════════════════════════════
/// تُظهر هذه البطاقة تفاصيل المبالغ المالية الواجب تسويتها وإيداعها في الحساب.
class PendingSettlementCard extends StatelessWidget {
  final AuthProvider auth;
  final model.User user;
  final void Function(String msg, bool isOk) onResult;

  const PendingSettlementCard({
    super.key,
    required this.auth,
    required this.user,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final ps = user.pendingSettlement;
    if (ps == null) return const SizedBox.shrink();

    final amt = (ps['amount'] is num) ? (ps['amount'] as num).toDouble() : 0.0;
    final reason = ps['reason'] ?? ps['requestedByName'] ?? 'تسوية حساب السائق';

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.amber.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 6),
                const Text(
                  'تسوية مالية معلقة مطلوب تأكيدها',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${amt.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'السبب: $reason',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final res = await auth.respondDriverSettlement(false);
                    onResult(
                      res ?? 'تم رفض التسوية',
                      res == null,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  child: const Text('اعتراض / رفض'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final res = await auth.respondDriverSettlement(true);
                    onResult(
                      res ?? 'تم تأكيد استلام الرصيد والتسوية بنجاح!',
                      res == null,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber.shade900,
                  ),
                  child: const Text('تأكيد الاستلام',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 4️⃣ قائمة الطلبات المتاحة للقبول (Available Orders Sheet)
/// ════════════════════════════════════════════════════════════════════════════
/// تعلن هذه البطاقة السفلية للسائق عن وجود طلبات جارية متاحة في منطقته
/// وتتيح له إمكانية القبول السريع وتخصيص المسار أو التجاهل.
class AvailableOrdersSheet extends StatefulWidget {
  final List<model.Order> availableOrders;
  final void Function(String, {Color color, IconData icon, int sec}) onNotify;

  const AvailableOrdersSheet({
    super.key,
    required this.availableOrders,
    required this.onNotify,
  });

  @override
  State<AvailableOrdersSheet> createState() => _AvailableOrdersSheetState();
}

class _AvailableOrdersSheetState extends State<AvailableOrdersSheet> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    if (widget.availableOrders.isEmpty) return const SizedBox.shrink();
    final order = widget.availableOrders.first;
    final restProv = context.watch<RestaurantProvider>();

    String restName = 'مطعم ماك';
    if (order.restaurantId is Map) {
      restName = (order.restaurantId as Map)['name'] ?? restName;
    } else {
      final match = restProv.restaurants
          .where((r) => r.id == order.restaurantIdStr)
          .toList();
      if (match.isNotEmpty) restName = match.first.name;
    }

    final feeText = '${order.deliveryFee.toStringAsFixed(0)} ل.س';
    final totalText = '${order.totalAmount.toStringAsFixed(0)} ل.س';
    final street = order.deliveryAddress.street;
    final streetText = (street != null && street.isNotEmpty)
        ? street
        : 'عنوان العميل (انظر الخريطة)';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.new_releases_rounded,
                          color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'طلب جديد متاح!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'أجرة التوصيل: $feeText',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.restaurant_rounded,
                    color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    restName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'العنوان: $streetText',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'المجموع: $totalText',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  'الدفع: ${order.paymentMethod == 'cash' ? 'نقداً عند التسليم' : 'إلكتروني'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            final op = context.read<OrderProvider>();
                            await op.rejectOrder(order.id);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('تجاهل',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            try {
                              final op = context.read<OrderProvider>();
                              final err = await op.acceptOrder(order.id);
                              if (!mounted) return;
                              if (err == null) {
                                widget.onNotify(
                                    'تم قبول الطلب بنجاح! جاري التوجيه إلى المطعم...',
                                    color: Colors.green,
                                    icon: Icons.check_circle);
                                await op.loadOrders();
                              } else {
                                widget.onNotify(err,
                                    color: Colors.red, icon: Icons.error);
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isProcessing = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('قبول الطلب 🚴‍♂️',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 5️⃣ بطاقة انتظار الطلبات (Waiting For Orders Card)
/// ════════════════════════════════════════════════════════════════════════════
/// تظهر عند تفعيل حالة "جاهز" وعدم وجود طلبات نشطة حالياً مع أنيميشن النبض الحية.
class WaitingForOrdersCard extends StatelessWidget {
  final bool isOnline;
  final AnimationController pulseAnim;

  const WaitingForOrdersCard({
    super.key,
    required this.isOnline,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(18),
      color: Theme.of(context).cardColor.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (isOnline)
              AnimatedBuilder(
                animation: pulseAnim,
                builder: (_, __) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green
                          .withValues(alpha: 0.15 + pulseAnim.value * 0.15),
                    ),
                    child: const Icon(Icons.radar_rounded,
                        color: Colors.green, size: 24),
                  );
                },
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Colors.orange, size: 24),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'بانتظار طلب جديد...' : 'أنت غير متصل حالياً',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOnline
                        ? 'أنت جاهز ومستعد لاستقبال أحدث طلبات التوصيل'
                        : 'انقر على مفتاح التشغيل أعلى الشاشة لبدء استقبال الطلبات',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 6️⃣ بطاقة متابعة وتوصيل الطلب النشط (Active Order Card Sheet)
/// ════════════════════════════════════════════════════════════════════════════
/// تعرض تفاصيل ومراحل الطلب المأخوذ حالياً بواسطة الكابتن وتسمح له بتغيير الحالة
/// إلى "في الطريق" أو رفع صورة إثبات الاستلام لإكمال التوصيل وتلقي الرصيد.
class ActiveOrderCardSheet extends StatefulWidget {
  final model.Order order;
  final double distKm;
  final void Function(String, {Color color, IconData icon, int sec}) onNotify;

  const ActiveOrderCardSheet({
    super.key,
    required this.order,
    required this.distKm,
    required this.onNotify,
  });

  @override
  State<ActiveOrderCardSheet> createState() => _ActiveOrderCardSheetState();
}

class _ActiveOrderCardSheetState extends State<ActiveOrderCardSheet> {
  bool _isUpdating = false;

  /// تحديث حالة الطلب إلى حالة جديدة (مثل: في الطريق)
  Future<void> _updateStatus(String nextStatus, String successMsg) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    try {
      final op = context.read<OrderProvider>();
      final err = await op
          .updateStatus(widget.order.id, nextStatus)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (err == null) {
        widget.onNotify(successMsg,
            color: Colors.green, icon: Icons.check_circle);
        await op.loadOrders();
      } else {
        widget.onNotify(err, color: Colors.red, icon: Icons.error);
      }
    } catch (e) {
      if (mounted) widget.onNotify('فشل تحديث الحالة: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// تأكيد تسليم الطلب وإلتقاط صورة الكاميرا لإثبات الاستلام
  Future<void> _confirmDelivery() async {
    if (_isUpdating) return;

    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (pickedFile == null) {
      if (mounted) {
        widget.onNotify('يجب التقاط صورة لإثبات التسليم', color: Colors.red);
      }
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final op = context.read<OrderProvider>();
      final err = await op
          .updateStatus(widget.order.id, 'delivered_pending',
              receivedPicture: base64Image)
          .timeout(const Duration(seconds: 12));

      if (!mounted) return;
      if (err == null) {
        widget.onNotify('تم تأكيد التسليم مع إرفاق الصورة',
            color: Colors.green, icon: Icons.check_circle);
        await op.loadOrders();
      } else {
        widget.onNotify(err, color: Colors.red);
      }
    } catch (e) {
      if (mounted) widget.onNotify('خطأ: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // رأس البطاقة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark]),
            ),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining_rounded,
                    color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(
                        'أجر التوصيل: ${order.deliveryFee.toStringAsFixed(0)} ل.س | الإجمالي: ${order.totalAmount.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // تفاصيل العنوان
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'العنوان: ${order.deliveryAddress.city ?? ''} - ${order.deliveryAddress.street ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // منطقة زر الإجراء المستهدف
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildActionButton(order),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(model.Order order) {
    if ([
      'pending',
      'restaurant_accepted',
      'preparing',
      'ready',
      'delivery_accepted'
    ].contains(order.status)) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUpdating
              ? null
              : () =>
                  _updateStatus('onTheWay', 'تم استلام الطلب وبدء التوصيل!'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdating)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else ...[
                const Icon(Icons.directions_bike_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('استلام الطلب والتحرك في الطريق 🚴‍♂️',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ],
          ),
        ),
      );
    }

    if (order.status == 'onTheWay') {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isUpdating ? null : _confirmDelivery,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isUpdating)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else ...[
                const Icon(Icons.camera_alt_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('تأكيد التسليم (مع إرفاق صورة) 📸',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      child: const Text(
        'بانتظار تأكيد استلام العميل وتسوية الرصيد...',
        style: TextStyle(
            color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

/// ════════════════════════════════════════════════════════════════════════════
/// 7️⃣ العناصر المساعدة والخلفيات المضيئة (Utility Widgets)
/// ════════════════════════════════════════════════════════════════════════════

/// زر زجاجي شبه شفاف لعناصر التحكم بالخريطة
class IconButtonGlass extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const IconButtonGlass({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, color: color ?? AppTheme.primary, size: 22),
        ),
      ),
    );
  }
}

/// لوحة زجاجية مضببة (Glass Panel)
class GlassPanel extends StatelessWidget {
  final Widget child;
  const GlassPanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.9),
      child: child,
    );
  }
}

/// دبوس العلامة المخصص على الخريطة
class MapMarkerPin extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;

  const MapMarkerPin({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 48,
        height: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(6)),
              child: Text(
                name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(icon, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
