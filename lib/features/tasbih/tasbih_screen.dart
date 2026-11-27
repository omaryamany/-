import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../mushaf/share_ayah.dart';

void openTasbih(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TasbihScreen()));
}

/// تسبيحة: النص والعدد المقترح
class Tasbiha {
  final String id;
  final String text;
  final int target;
  final String? note;
  final bool custom;
  const Tasbiha(this.id, this.text, this.target, {this.note, this.custom = false});
}

const tasbihat = <Tasbiha>[
  Tasbiha('subhan', 'سُبْحَانَ اللَّهِ', 33, note: 'بعد الصلاة ٣٣ مرة'),
  Tasbiha('hamd', 'الْحَمْدُ لِلَّهِ', 33, note: 'بعد الصلاة ٣٣ مرة'),
  Tasbiha('akbar', 'اللَّهُ أَكْبَرُ', 34, note: 'بعد الصلاة ٣٣ مرة، و٣٤ قبل النوم'),
  Tasbiha('tahlil', 'لَا إِلَهَ إِلَّا اللَّهُ', 100),
  Tasbiha('baqiyat', 'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ', 100, note: 'الباقيات الصالحات'),
  Tasbiha('bihamdih', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ', 100),
  Tasbiha('azim', 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ', 100, note: 'كلمتان خفيفتان على اللسان'),
  Tasbiha('istighfar', 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ', 100),
  Tasbiha('istighfar2', 'أَسْتَغْفِرُ اللَّهَ الْعَظِيمَ', 100),
  Tasbiha('tawwab', 'رَبِّ اغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ', 100),
  Tasbiha('salat', 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ', 100, note: 'الصلاة على النبي ﷺ'),
  Tasbiha('hawqala', 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ', 100, note: 'كنز من كنوز الجنة'),
  Tasbiha('wahdah', 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ', 100),
  Tasbiha('hasbuna', 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ', 100),
  Tasbiha('yunus', 'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ', 100, note: 'دعوة ذي النون'),
  Tasbiha('hayy', 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ', 100),
  Tasbiha('quddus', 'سُبْحَانَ الْمَلِكِ الْقُدُّوسِ', 3, note: 'بعد الوتر'),
];

/// عدّادات المسبحة — محفوظة على الجهاز: النهارده، والإجمالي، والتسبيحات المضافة
class TasbihStore extends ChangeNotifier {
  TasbihStore._();
  static final TasbihStore instance = TasbihStore._();

  SharedPreferences? _p;
  List<Tasbiha> customs = [];
  Map<String, int> total = {};
  Map<String, int> today = {};
  Map<String, int> targets = {};
  String _day = '';
  String selected = tasbihat.first.id;
  bool autoNext = true;
  bool vibrate = true;

  List<Tasbiha> get all => [...tasbihat, ...customs];
  Tasbiha get current => all.firstWhere((t) => t.id == selected, orElse: () => tasbihat.first);
  int targetOf(Tasbiha t) => targets[t.id] ?? t.target;
  int get todayAll => today.values.fold(0, (a, b) => a + b);

  Future<void> load() async {
    if (_p != null) return;
    final p = _p = await SharedPreferences.getInstance();
    try {
      customs = [
        for (final e in jsonDecode(p.getString('tasbih.custom') ?? '[]') as List)
          Tasbiha(e['id'] as String, e['t'] as String, e['n'] as int, custom: true)
      ];
      total = Map<String, int>.from(jsonDecode(p.getString('tasbih.total') ?? '{}') as Map);
      targets = Map<String, int>.from(jsonDecode(p.getString('tasbih.targets') ?? '{}') as Map);
      final t = jsonDecode(p.getString('tasbih.today') ?? '{}') as Map;
      _day = (t['d'] ?? '') as String;
      today = Map<String, int>.from((t['c'] ?? {}) as Map);
    } catch (_) {}
    selected = p.getString('tasbih.sel') ?? selected;
    autoNext = p.getBool('tasbih.auto') ?? true;
    vibrate = p.getBool('tasbih.vib') ?? true;
    _rollDay();
    notifyListeners();
  }

  void _rollDay() {
    final d = dayKey(DateTime.now());
    if (d != _day) {
      _day = d;
      today = {};
    }
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setString('tasbih.total', jsonEncode(total));
    p.setString('tasbih.today', jsonEncode({'d': _day, 'c': today}));
  }

  void count(String id) {
    _rollDay();
    today[id] = (today[id] ?? 0) + 1;
    total[id] = (total[id] ?? 0) + 1;
    _save();
    notifyListeners();
  }

  void select(String id) {
    selected = id;
    _p?.setString('tasbih.sel', id);
    notifyListeners();
  }

  void setTarget(Tasbiha t, int n) {
    targets[t.id] = n;
    _p?.setString('tasbih.targets', jsonEncode(targets));
    notifyListeners();
  }

  void setAuto(bool v) {
    autoNext = v;
    _p?.setBool('tasbih.auto', v);
    notifyListeners();
  }

  void setVibrate(bool v) {
    vibrate = v;
    _p?.setBool('tasbih.vib', v);
    notifyListeners();
  }

  void _saveCustoms() =>
      _p?.setString('tasbih.custom', jsonEncode([for (final c in customs) {'id': c.id, 't': c.text, 'n': c.target}]));

  Tasbiha addCustom(String text, int target) {
    final t = Tasbiha('c${DateTime.now().millisecondsSinceEpoch}', text, target, custom: true);
    customs.add(t);
    _saveCustoms();
    select(t.id);
    return t;
  }

  void removeCustom(Tasbiha t) {
    customs.removeWhere((c) => c.id == t.id);
    if (selected == t.id) selected = tasbihat.first.id;
    _saveCustoms();
    notifyListeners();
  }
}

/// المسبحة: اضغط في أي مكان في الدائرة للعدّ — ولما تكمّل العدد بتنتقل للتسبيحة اللي بعدها (لو مفعّل)
class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});
  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  final _s = TasbihStore.instance;

  /// العدّ في الجلسة دي لكل تسبيحة (الدورة الحالية)
  final Map<String, int> _session = {};
  bool _celebrate = false;

  @override
  void initState() {
    super.initState();
    _s.addListener(_refresh);
    _s.load();
  }

  @override
  void dispose() {
    _s.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => mounted ? setState(() {}) : null;

  void _tap() {
    final t = _s.current;
    final target = _s.targetOf(t);
    final n = (_session[t.id] ?? 0) + 1;
    _session[t.id] = n;
    _s.count(t.id);
    final done = target > 0 && n % target == 0;
    if (_s.vibrate) done ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
    if (!done) return;
    setState(() => _celebrate = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _celebrate = false);
      if (_s.autoNext) _move(1);
    });
  }

  void _move(int d) {
    final list = _s.all;
    final i = list.indexWhere((t) => t.id == _s.selected);
    final next = list[(i + d) % list.length];
    _session[next.id] = 0;
    _s.select(next.id);
  }

  void _reset() {
    setState(() => _session[_s.selected] = 0);
  }

  Future<void> _pickTarget() async {
    final t = _s.current;
    final n = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('عدد التسبيح', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in [3, 7, 10, 33, 34, 99, 100, 500, 1000, 0])
                ChoiceChip(
                  label: Text(v == 0 ? 'بلا حدّ' : arDigits(v)),
                  selected: _s.targetOf(t) == v,
                  onSelected: (_) => Navigator.pop(ctx, v),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (n != null) {
      _s.setTarget(t, n);
      setState(() => _session[t.id] = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cur = _s.current;
    final target = _s.targetOf(cur);
    final n = _session[cur.id] ?? 0;
    final inRound = target > 0 ? (n == 0 ? 0 : ((n - 1) % target) + 1) : n;
    final round = target > 0 && n > 0 ? (n - 1) ~/ target + 1 : 1;
    final progress = target > 0 ? inRound / target : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المسبحة'),
        actions: [
          IconButton(
            tooltip: 'مشاركة صورة',
            onPressed: () => openShareCard(
              context,
              ShareContent(header: 'سَبِّح', text: cur.text, source: cur.note ?? '', caption: cur.text),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(tooltip: 'كل التسبيحات', onPressed: () => _showList(context), icon: const Icon(Icons.format_list_bulleted_rounded)),
          IconButton(tooltip: 'تصفير العدّاد', onPressed: _reset, icon: const Icon(Icons.restart_alt_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          // التسبيحة الحالية + السهمين
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Row(children: [
              IconButton(tooltip: 'السابقة', onPressed: () => _move(-1), icon: const Icon(Icons.chevron_right_rounded, size: 30)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(key: ValueKey(cur.id), mainAxisSize: MainAxisSize.min, children: [
                    Text(cur.text, textAlign: TextAlign.center, style: AppTheme.quran(size: cur.text.length > 40 ? 20 : 26, height: 1.8, color: cs.onSurface)),
                    if (cur.note != null) Text(cur.note!, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
                ),
              ),
              IconButton(tooltip: 'التالية', onPressed: () => _move(1), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
            ]),
          ),
          // الدائرة الكبيرة — الضغط في أي مكان فيها بيعدّ
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tap,
              child: LayoutBuilder(builder: (context, c) {
                final size = math.min(c.maxWidth * .78, c.maxHeight * .86).clamp(160.0, 360.0);
                return Center(
                  child: Semantics(
                    button: true,
                    label: 'سبّح، العدد ${arDigits(inRound)}',
                    child: AnimatedScale(
                      scale: _celebrate ? 1.05 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: CustomPaint(
                          painter: _BeadsPainter(progress: progress, beads: target > 0 && target <= 100 ? target : 33, done: _celebrate, dark: Theme.of(context).brightness == Brightness.dark),
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(arDigits(inRound),
                                  style: TextStyle(fontSize: size * .26, fontWeight: FontWeight.w800, color: _celebrate ? AppColors.amber : cs.onSurface, height: 1.1)),
                              Text(target > 0 ? 'من ${arDigits(target)}' : 'بلا حدّ', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                              if (round > 1) Text('الدورة ${arDigits(round)}', style: t.bodySmall?.copyWith(color: AppColors.turquoise, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Text('اضغط في أي مكان على الدائرة للتسبيح', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          // الإعدادات السريعة والإحصاء
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.flag_rounded, size: 18),
                label: Text(target > 0 ? 'العدد: ${arDigits(target)}' : 'العدد: بلا حدّ'),
                onPressed: _pickTarget,
              ),
              FilterChip(
                avatar: const Icon(Icons.skip_previous_rounded, size: 18),
                label: const Text('انتقال تلقائي'),
                selected: _s.autoNext,
                showCheckmark: false,
                onSelected: _s.setAuto,
              ),
              FilterChip(
                avatar: const Icon(Icons.vibration_rounded, size: 18),
                label: const Text('اهتزاز'),
                selected: _s.vibrate,
                showCheckmark: false,
                onSelected: _s.setVibrate,
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Expanded(child: _stat('هذه التسبيحة اليوم', _s.today[cur.id] ?? 0, t, cs)),
              Expanded(child: _stat('كل التسبيح اليوم', _s.todayAll, t, cs)),
              Expanded(child: _stat('إجمالي هذه التسبيحة', _s.total[cur.id] ?? 0, t, cs)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, int v, TextTheme t, ColorScheme cs) => Column(children: [
        Text(arDigits(v), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.3)),
      ]);

  void _showList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .95,
        builder: (ctx, sc) => ListenableBuilder(
          listenable: _s,
          builder: (ctx, _) {
            final list = _s.all;
            return ListView.builder(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: list.length + 1,
              itemBuilder: (ctx, i) {
                if (i == list.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final added = await _addDialog(ctx);
                        if (added && ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة تسبيحة'),
                    ),
                  );
                }
                final x = list[i];
                final sel = x.id == _s.selected;
                return Card(
                  color: sel ? AppColors.turquoise.withValues(alpha: .14) : null,
                  child: ListTile(
                    title: Text(x.text, style: AppTheme.quran(size: 18, height: 1.7)),
                    subtitle: Text('العدد ${arDigits(_s.targetOf(x))} · اليوم ${arDigits(_s.today[x.id] ?? 0)}'),
                    trailing: x.custom
                        ? IconButton(tooltip: 'حذف', onPressed: () => _s.removeCustom(x), icon: const Icon(Icons.delete_outline_rounded))
                        : (sel ? const Icon(Icons.check_circle_rounded, color: AppColors.turquoise) : null),
                    onTap: () {
                      _session[x.id] = 0;
                      _s.select(x.id);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<bool> _addDialog(BuildContext context) async {
    final text = TextEditingController();
    final count = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسبيحة جديدة'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: text, autofocus: true, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'نص التسبيحة')),
          const SizedBox(height: 8),
          TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العدد')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok != true || text.text.trim().isEmpty) return false;
    final n = int.tryParse(normalizeDigits(count.text.trim())) ?? 100;
    _s.addCustom(text.text.trim(), n.clamp(0, 100000));
    if (context.mounted) toast(context, 'أضيفت التسبيحة');
    return true;
  }
}

/// تحويل الأرقام العربية (٠١٢…) لأرقام عادية
String normalizeDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) {
    final i = ar.indexOf(c);
    return i >= 0 ? '$i' : c;
  }).join();
}

/// حبّات المسبحة حوالين الدائرة: اللي اتسبّح بيها ملوّنة
class _BeadsPainter extends CustomPainter {
  final double progress;
  final int beads;
  final bool done;
  final bool dark;
  _BeadsPainter({required this.progress, required this.beads, required this.done, required this.dark});

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    // خلفية الدائرة
    canvas.drawCircle(
      c,
      r * .78,
      Paint()
        ..shader = RadialGradient(colors: dark ? [const Color(0xFF1B2A45), const Color(0xFF121C30)] : [Colors.white, const Color(0xFFEFF3F8)])
            .createShader(Rect.fromCircle(center: c, radius: r * .78)),
    );
    canvas.drawCircle(c, r * .78, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = AppColors.turquoise.withValues(alpha: .35));
    // الحبّات
    final lit = (progress * beads).round();
    final beadR = math.min(r * .055, (2 * math.pi * r * .9) / beads / 2.4);
    for (var i = 0; i < beads; i++) {
      final a = -math.pi / 2 - i * 2 * math.pi / beads; // من فوق، عكس عقارب الساعة (من اليمين)
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * .9);
      final on = i < lit;
      canvas.drawCircle(
        p,
        beadR,
        Paint()..color = on ? (done ? AppColors.amber : AppColors.turquoise) : (dark ? Colors.white.withValues(alpha: .14) : const Color(0xFF1E3A6E).withValues(alpha: .12)),
      );
    }
    // الشاهد (فوق)
    final top = c + Offset(0, -r * .9);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy - beadR * 2.6)
        ..lineTo(top.dx + beadR * 1.2, top.dy - beadR * .6)
        ..lineTo(top.dx - beadR * 1.2, top.dy - beadR * .6)
        ..close(),
      Paint()..color = AppColors.amber,
    );
  }

  @override
  bool shouldRepaint(covariant _BeadsPainter o) => o.progress != progress || o.beads != beads || o.done != done || o.dark != dark;
}
