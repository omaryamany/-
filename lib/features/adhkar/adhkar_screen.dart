import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/adhkar_data.dart';
import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../mushaf/share_ayah.dart';

export '../../core/adhkar_data.dart' show AdhkarKind;

void openAdhkar(BuildContext context, AdhkarKind kind) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdhkarScreen(kind: kind)));
}

/// العدّاد بيتحفظ لحد آخر اليوم (لو خرجت ورجعت تكمّل من مكانك)
final Map<String, List<int>> _progress = {};

/// تقدّم النهارده في قسم: (اللي خلص، الإجمالي)
(int, int) adhkarProgress(AdhkarKind k) {
  final items = adhkarOf(k);
  final left = _progress['${k.name}:${dayKey(DateTime.now())}'];
  if (left == null) return (0, items.length);
  return (left.where((x) => x == 0).length, items.length);
}

/// الأذكار ذكر ذكر: اضغط على الذكر لعدّه، ولما يخلص عدده بينتقل لوحده للذكر اللي بعده
class AdhkarScreen extends StatefulWidget {
  final AdhkarKind kind;
  const AdhkarScreen({super.key, required this.kind});
  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen> {
  late final List<Dhikr> _items = adhkarOf(widget.kind);
  late final String _key = '${widget.kind.name}:${dayKey(DateTime.now())}';
  late List<int> _left = _progress[_key] ?? [for (final d in _items) d.count];
  final Map<int, String> _quranText = {};
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _progress[_key] = _left;
    // نبدأ من أول ذكر لسه ماخلصش
    final first = _left.indexWhere((x) => x > 0);
    _index = first < 0 ? _items.length : first;
    _pc = PageController(initialPage: _index);
    _loadQuran();
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _loadQuran() async {
    for (var i = 0; i < _items.length; i++) {
      final d = _items[i];
      if (d.quran.isEmpty) continue;
      final parts = <String>[];
      for (final (s, from, to) in d.quran) {
        final ayat = await Quran.surahAyat(s);
        final seg = [for (var a = from; a <= to; a++) '${ayat[a - 1]} ﴿${arDigits(a)}﴾'].join(' ');
        parts.add(d.quran.length > 1 ? '﴿سورة ${Quran.surah(s).name}﴾\n$seg' : seg);
      }
      _quranText[i] = parts.join('\n\n');
    }
    if (mounted) setState(() {});
  }

  void _go(int i) {
    if (i < 0 || i > _items.length) return;
    _pc.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  void _tap(int i) {
    if (_left[i] <= 0) return _go(i + 1);
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      HapticFeedback.mediumImpact();
      // انتقال تلقائي للذكر التالي
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _index == i) _go(i + 1);
      });
    } else {
      HapticFeedback.selectionClick();
    }
  }

  int get _done => _left.where((x) => x == 0).length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total = _items.length;
    final atEnd = _index >= total;
    return Scaffold(
      appBar: AppBar(
        title: Text(adhkarTitle(widget.kind)),
        actions: [
          Center(
            child: Text(atEnd ? 'تمّت' : '${arDigits(_index + 1)} / ${arDigits(total)}',
                style: t.titleSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          if (!atEnd)
            IconButton(
              tooltip: 'مشاركة صورة',
              onPressed: () {
                final d = _items[_index];
                final quran = d.quran.isNotEmpty;
                final txt = d.text ?? _quranText[_index] ?? '';
                final src = [if (d.note != null) d.note!, if (d.count > 1) countLabel(d.count, 'مرة', 'مرتين', 'مرات')].join(' · ');
                openShareCard(
                  context,
                  ShareContent(
                    header: quran ? 'قال الله تعالى' : adhkarTitle(widget.kind),
                    text: txt,
                    source: src,
                    caption: '$txt${src.isEmpty ? '' : '\n($src)'}',
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
          IconButton(
            tooltip: 'البدء من جديد',
            onPressed: () {
              setState(() {
                _left = [for (final d in _items) d.count];
                _progress[_key] = _left;
              });
              _pc.jumpToPage(0);
            },
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: _done / total, minHeight: 4, color: AppColors.turquoise, backgroundColor: Colors.transparent),
        ),
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pc,
          itemCount: total + 1,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            if (i == total) return _finished(t, cs);
            return _DhikrPage(
              dhikr: _items[i],
              text: _items[i].text ?? _quranText[i] ?? '…',
              left: _left[i],
              onTap: () => _tap(i),
              onPrev: i > 0 ? () => _go(i - 1) : null,
              onNext: () => _go(i + 1),
            );
          },
        ),
      ),
    );
  }

  Widget _finished(TextTheme t, ColorScheme cs) {
    final all = _done == _items.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(all ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 72, color: all ? AppColors.turquoise : AppColors.amber)
              .animate()
              .scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(all ? 'أتممت ${adhkarTitle(widget.kind)}' : 'باقي ${arDigits(_items.length - _done)} من الأذكار لم تكتمل',
              textAlign: TextAlign.center, style: t.titleLarge),
          const SizedBox(height: 6),
          Text(all ? 'تقبّل الله منك' : 'ارجع للأذكار اللي ماخلصتش', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (!all)
            FilledButton(onPressed: () => _go(_left.indexWhere((x) => x > 0)), child: const Text('أكمل الأذكار'))
          else
            FilledButton(onPressed: () => Navigator.maybePop(context), child: const Text('رجوع')),
        ]),
      ),
    );
  }
}

class _DhikrPage extends StatelessWidget {
  final Dhikr dhikr;
  final String text;
  final int left;
  final VoidCallback onTap;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  const _DhikrPage({required this.dhikr, required this.text, required this.left, required this.onTap, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final done = left == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(children: [
        // الذكر نفسه — الضغط في أي مكان عليه بيعدّ
        Expanded(
          child: SoftCard(
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (dhikr.note != null) ...[
                Align(alignment: AlignmentDirectional.centerStart, child: Pill(dhikr.note!, color: AppColors.amber)),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(text, textAlign: TextAlign.center, style: AppTheme.quran(size: text.length > 380 ? 19 : 22, height: 2, color: cs.onSurface)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(dhikr.count == 1 ? 'مرة واحدة' : 'يُقال ${countLabel(dhikr.count, 'مرة', 'مرتين', 'مرات')}',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          IconButton.filledTonal(tooltip: 'السابق', onPressed: onPrev, icon: const Icon(Icons.chevron_right_rounded)),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: done ? null : AppColors.heroGradient,
                color: done ? AppColors.turquoise : null,
                boxShadow: [BoxShadow(color: AppColors.pine.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 42)
                    : Text(arDigits(left), style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ).animate(target: done ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 200.ms),
          ),
          const Spacer(),
          IconButton.filledTonal(tooltip: 'التالي', onPressed: onNext, icon: const Icon(Icons.chevron_left_rounded)),
        ]),
        const SizedBox(height: 6),
        Text('اضغط على الذكر أو الدائرة للعدّ', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
