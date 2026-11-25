import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/adhkar_data.dart';
import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

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

  @override
  void initState() {
    super.initState();
    _progress[_key] = _left;
    _loadQuran();
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

  void _tap(int i) {
    if (_left[i] <= 0) return;
    setState(() => _left[i]--);
    if (_left[i] == 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  int get _done => [for (var i = 0; i < _items.length; i++) if (_left[i] == 0) i].length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final all = _done == _items.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(adhkarTitle(widget.kind)),
        actions: [
          IconButton(
            tooltip: 'البدء من جديد',
            onPressed: () => setState(() {
              _left = [for (final d in _items) d.count];
              _progress[_key] = _left;
            }),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(value: _done / _items.length, minHeight: 4, color: AppColors.gold, backgroundColor: Colors.transparent),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return all
                ? EmptyView(icon: Icons.check_circle_rounded, text: 'أتممت ${adhkarTitle(widget.kind)} — تقبّل الله')
                : Center(child: Text('اضغط على الذكر لعدّه', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)));
          }
          final d = _items[i];
          final left = _left[i];
          final done = left == 0;
          final text = d.text ?? _quranText[i] ?? '…';
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: done ? .55 : 1,
            child: SoftCard(
              onTap: () => _tap(i),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (d.note != null)
                  Align(alignment: AlignmentDirectional.centerStart, child: Pill(d.note!, color: AppColors.gold)),
                const SizedBox(height: 6),
                Text(text, textAlign: TextAlign.justify, style: AppTheme.quran(size: 20, height: 2, color: cs.onSurface)),
                const SizedBox(height: 10),
                Row(children: [
                  Text(d.count == 1 ? 'مرة واحدة' : 'التكرار: ${arDigits(d.count)}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: done ? null : AppColors.heroGradient,
                      color: done ? AppColors.gold : null,
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                          : Text(arDigits(left), style: t.titleLarge?.copyWith(color: Colors.white)),
                    ),
                  ).animate(target: done ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 200.ms),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
