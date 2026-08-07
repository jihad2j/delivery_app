import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/services.dart';
import '../core/theme.dart';

class AdminSystemSettingsScreen extends StatefulWidget {
  const AdminSystemSettingsScreen({super.key});

  @override
  State<AdminSystemSettingsScreen> createState() => _AdminSystemSettingsScreenState();
}

class _AdminSystemSettingsScreenState extends State<AdminSystemSettingsScreen> {
  bool _isLoading = true;
  final TextEditingController _deliveryFeeCtrl = TextEditingController();
  final TextEditingController _commissionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await ApiService.get('/api/admin/settings');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        for (var item in data) {
          if (item['key'] == 'deliveryFee') {
            _deliveryFeeCtrl.text = item['value'];
          } else if (item['key'] == 'platformCommission') {
            _commissionCtrl.text = item['value'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSetting(String key, String value) async {
    try {
      final res = await ApiService.put('/api/admin/settings', {'key': key, 'value': value});
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(res.body)['message'] ?? 'خطأ')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النظام')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSettingCard(
                  'رسوم التوصيل الافتراضية (ل.س)',
                  'تحدد رسوم التوصيل لجميع الطلبات',
                  _deliveryFeeCtrl,
                  () => _saveSetting('deliveryFee', _deliveryFeeCtrl.text.trim()),
                ),
                _buildSettingCard(
                  'عمولة التطبيق من المطاعم (%)',
                  'النسبة المئوية المقتطعة من أرباح المطعم',
                  _commissionCtrl,
                  () => _saveSetting('platformCommission', _commissionCtrl.text.trim()),
                ),
              ],
            ),
    );
  }

  Widget _buildSettingCard(String title, String desc, TextEditingController controller, VoidCallback onSave) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: onSave,
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendBroadcast() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      final res = await ApiService.post('/api/admin/broadcast', {'message': _msgCtrl.text.trim()});
      if (!mounted) return;
      if (res.statusCode == 200) {
        _msgCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الإرسال بنجاح!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(res.body)['message'] ?? 'خطأ')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إشعارات للجميع')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('محتوى الإشعار:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'اكتب نص الإشعار هنا ليرسل لجميع التطبيقات المتصلة حالياً',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendBroadcast,
                icon: const Icon(Icons.send_rounded),
                label: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال الإشعار'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPromoScreen extends StatefulWidget {
  const AdminPromoScreen({super.key});

  @override
  State<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _AdminPromoScreenState extends State<AdminPromoScreen> {
  bool _isLoading = true;
  List _promos = [];

  @override
  void initState() {
    super.initState();
    _fetchPromos();
  }

  Future<void> _fetchPromos() async {
    try {
      final res = await ApiService.get('/api/promos');
      if (res.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _promos = jsonDecode(res.body)['promos'] ?? [];
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deletePromo(String id) async {
    try {
      final res = await ApiService.delete('/api/promos/$id');
      if (res.statusCode == 200) {
        _fetchPromos();
      }
    } catch (_) {}
  }

  void _showAddPromoDialog() {
    final _codeCtrl = TextEditingController();
    final _valCtrl = TextEditingController();
    String _type = 'percentage';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('كود خصم جديد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: 'الكود (مثال: FREE20)'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'percentage', child: Text('نسبة مئوية (%)')),
                      DropdownMenuItem(value: 'fixed', child: Text('مبلغ ثابت (ل.س)')),
                    ],
                    onChanged: (v) => setDialogState(() => _type = v!),
                    decoration: const InputDecoration(labelText: 'نوع الخصم'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _valCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'قيمة الخصم'),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () async {
                    if (_codeCtrl.text.isEmpty || _valCtrl.text.isEmpty) return;
                    Navigator.pop(ctx);
                    await ApiService.post('/api/promos', {
                      'code': _codeCtrl.text.trim(),
                      'discountType': _type,
                      'discountValue': num.tryParse(_valCtrl.text.trim()) ?? 0,
                    });
                    _fetchPromos();
                  },
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة أكواد الخصم')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPromoDialog,
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? const Center(child: Text('لا يوجد أكواد خصم'))
              : ListView.builder(
                  itemCount: _promos.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (ctx, idx) {
                    final promo = _promos[idx];
                    return Card(
                      child: ListTile(
                        title: Text(promo['code'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          promo['discountType'] == 'percentage'
                              ? 'خصم ${promo['discountValue']}%'
                              : 'خصم ${promo['discountValue']} ل.س',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.red),
                          onPressed: () => _deletePromo(promo['_id']),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
