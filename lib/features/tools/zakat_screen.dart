import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

void openZakat(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ZakatScreen()));

/// حاسبة زكاة المال: النقود، الذهب، الفضة، عروض التجارة، الديون — بنصاب الذهب أو الفضة
class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  static const _fields = ['goldPrice', 'silverPrice', 'cash', 'g24', 'g21', 'g18', 'silver', 'trade', 'receivable', 'debts'];
  final Map<String, TextEditingController> _c = {for (final f in _fields) f: TextEditingController()};
  bool _silverNisab = false;
  SharedPreferences? _p;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      _p = p;
      try {
        final m = jsonDecode(p.getString('zakat.v1') ?? '{}') as Map;
        for (final f in _fields) {
          final v = m[f];
          if (v is String) _c[f]!.text = v;
        }
        _silverNisab = m['silverNisab'] == true;
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _p?.setString('zakat.v1', jsonEncode({for (final f in _fields) f: _c[f]!.text, 'silverNisab': _silverNisab}));
  }

  double _v(String f) => double.tryParse(_latin(_c[f]!.text).replaceAll(',', '').trim()) ?? 0;

  static String _latin(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    return s.split('').map((c) {
      final i = ar.indexOf(c);
      if (i >= 0) return '$i';
      if (c == '٫') return '.';
      if (c == '٬') return ',';
      return c;
    }).join();
  }

  String _money(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('٬');
      b.write(s[i]);
    }
    return '${arDigits(b.toString())} جنيه';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final gp = _v('goldPrice'), sp = _v('silverPrice');
    final gold24 = _v('g24') + _v('g21') * 21 / 24 + _v('g18') * 18 / 24;
    final goldValue = gold24 * gp;
    final silverValue = _v('silver') * sp;
    final cash = _v('cash'), trade = _v('trade'), recv = _v('receivable'), debts = _v('debts');
    final total = (cash + goldValue + silverValue + trade + recv - debts).clamp(0, double.infinity).toDouble();
    final nisab = _silverNisab ? 595 * sp : 85 * gp;
    final priceMissing = _silverNisab ? sp <= 0 : gp <= 0;
    final reached = !priceMissing && total >= nisab && total > 0;
    final zakat = reached ? total * .025 : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('حاسبة الزكاة')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        // النتيجة
        HeroCard(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('الزكاة الواجبة', style: t.titleSmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(_money(zakat), style: t.headlineMedium?.copyWith(color: AppColors.goldLight, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              priceMissing
                  ? 'اكتب سعر جرام ${_silverNisab ? 'الفضة' : 'الذهب عيار ٢٤'} عشان نحسب النصاب'
                  : reached
                      ? 'المال الزكوي ${_money(total)} وصل النصاب (${_money(nisab)}) — الزكاة ربع العُشر ٢٫٥٪'
                      : 'المال الزكوي ${_money(total)} أقل من النصاب (${_money(nisab)}) — لا زكاة عليه',
              style: t.bodyMedium?.copyWith(color: Colors.white, height: 1.6),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        const SectionTitle('الأسعار اليوم'),
        _row('سعر جرام الذهب عيار ٢٤', 'goldPrice', 'جنيه'),
        _row('سعر جرام الفضة', 'silverPrice', 'جنيه'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _silverNisab,
          onChanged: (v) {
            setState(() => _silverNisab = v);
            _save();
          },
          title: const Text('حساب النصاب بالفضة (٥٩٥ جرام)'),
          subtitle: const Text('الافتراضي بالذهب: ٨٥ جرام عيار ٢٤'),
        ),
        const SizedBox(height: 8),
        const SectionTitle('أموالك'),
        _row('النقود في البيت والبنك', 'cash', 'جنيه'),
        _row('ذهب عيار ٢٤', 'g24', 'جرام'),
        _row('ذهب عيار ٢١', 'g21', 'جرام'),
        _row('ذهب عيار ١٨', 'g18', 'جرام'),
        _row('فضة', 'silver', 'جرام'),
        _row('بضاعة التجارة (بسعر البيع اليوم)', 'trade', 'جنيه'),
        _row('ديون لك عند ناس وهتتردّ', 'receivable', 'جنيه'),
        const SizedBox(height: 8),
        const SectionTitle('عليك'),
        _row('ديون عليك مستحقة الآن', 'debts', 'جنيه'),
        const SizedBox(height: 12),
        if (gold24 > 0 || silverValue > 0 || cash > 0)
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('التفاصيل', style: t.titleSmall),
              const SizedBox(height: 6),
              if (cash > 0) _line('النقود', cash),
              if (gold24 > 0) _line('الذهب (${arDigits(gold24.toStringAsFixed(1)).replaceAll('.', '٫')} جرام عيار ٢٤)', goldValue),
              if (silverValue > 0) _line('الفضة', silverValue),
              if (trade > 0) _line('عروض التجارة', trade),
              if (recv > 0) _line('ديون مرجوّة', recv),
              if (debts > 0) _line('ناقص الديون', -debts),
              const Divider(),
              _line('الإجمالي', total, bold: true),
            ]),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
          child: Text(
            '• الزكاة تجب لما يبلغ المال النصاب ويمرّ عليه عام هجري كامل.\n'
            '• ذهب الزينة الملبوس فيه خلاف بين العلماء: لو بتزكّيه احسبه، ولو لا سيبه فاضي.\n'
            '• الحاسبة للتقريب، ولأي حالة خاصة (شركة، أرض، أسهم) اسأل دار الإفتاء أو أهل العلم.',
            style: t.bodySmall?.copyWith(height: 1.8, color: cs.onSurface),
          ),
        ),
      ]),
    );
  }

  Widget _line(String label, double v, {bool bold = false}) {
    final st = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w800 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: st)), Text(v < 0 ? '− ${_money(-v)}' : _money(v), style: st)]),
    );
  }

  Widget _row(String label, String f, String unit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _c[f],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫٬]'))],
        onChanged: (_) {
          setState(() {});
          _save();
        },
        decoration: InputDecoration(labelText: label, suffixText: unit, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }
}
