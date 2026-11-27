import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic.dart';
import '../../core/player.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import '../listen/listen_screen.dart';
import '../shell.dart';

void openHifz(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HifzScreen()));

/// المحفوظ: لكل سورة الآيات اللي اتحفظت + آخر مراجعة
class HifzStore extends ChangeNotifier {
  HifzStore._();
  static final HifzStore instance = HifzStore._();

  SharedPreferences? _p;
  final Map<int, Set<int>> done = {};
  final Map<int, String> reviewed = {}; // سورة ← يوم آخر مراجعة

  Future<void> load() async {
    if (_p != null) return;
    final p = _p = await SharedPreferences.getInstance();
    try {
      final m = jsonDecode(p.getString('hifz.v1') ?? '{}') as Map;
      for (final e in ((m['d'] ?? {}) as Map).entries) {
        done[int.parse(e.key as String)] = ((e.value as List).cast<int>()).toSet();
      }
      for (final e in ((m['r'] ?? {}) as Map).entries) {
        reviewed[int.parse(e.key as String)] = e.value as String;
      }
    } catch (_) {}
    notifyListeners();
  }

  void _save() => _p?.setString(
      'hifz.v1',
      jsonEncode({
        'd': {for (final e in done.entries) '${e.key}': e.value.toList()..sort()},
        'r': {for (final e in reviewed.entries) '${e.key}': e.value},
      }));

  int get totalAyat => done.values.fold(0, (a, b) => a + b.length);
  int countOf(int s) => done[s]?.length ?? 0;
  bool complete(int s) => countOf(s) >= Quran.surah(s).ayahCount;
  int get completeSurahs => done.keys.where(complete).length;

  /// أول آية لسه ماتحفظتش في السورة
  int nextAyah(int s) {
    final d = done[s] ?? {};
    for (var a = 1; a <= Quran.surah(s).ayahCount; a++) {
      if (!d.contains(a)) return a;
    }
    return 1;
  }

  void mark(int s, int from, int to, bool v) {
    final d = done.putIfAbsent(s, () => {});
    for (var a = from; a <= to; a++) {
      v ? d.add(a) : d.remove(a);
    }
    if (d.isEmpty) done.remove(s);
    reviewed[s] = dayKey(DateTime.now());
    _save();
    notifyListeners();
  }

  void review(int s) {
    reviewed[s] = dayKey(DateTime.now());
    _save();
    notifyListeners();
  }

  int daysSinceReview(int s) {
    final k = reviewed[s];
    if (k == null) return 999;
    final p = k.split('-').map(int.parse).toList();
    return daysBetween(DateTime(p[0], p[1], p[2]), DateTime.now());
  }
}

/// وضع الحفظ: تختار مقطع، القارئ يكرّره، وتخفي الآيات وتسمّع لنفسك، وتعلّم اللي حفظته وتراجعه
class HifzScreen extends StatefulWidget {
  const HifzScreen({super.key});
  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> {
  final _h = HifzStore.instance;
  final _player = QuranPlayer.instance;
  int _surah = 114, _from = 1, _to = 6;
  int _ayahRepeat = 3, _rangeRepeat = 3;
  bool _hide = false;
  final Set<int> _revealed = {};

  @override
  void initState() {
    super.initState();
    _h.load().then((_) {
      // نبدأ من آخر سورة اتشغل عليها، وإلا جزء عمّ من الآخر
      final started = _h.done.keys.where((s) => !_h.complete(s)).toList()..sort((a, b) => b.compareTo(a));
      _setSurah(started.isNotEmpty ? started.first : 114);
    });
  }

  void _setSurah(int s) {
    final n = Quran.surah(s).ayahCount;
    final from = _h.nextAyah(s);
    setState(() {
      _surah = s;
      _from = from;
      _to = (from + 4).clamp(from, n);
      _revealed.clear();
    });
  }

  bool _inRange(int? g) {
    if (g == null) return false;
    final p = Quran.fromGlobal(g);
    return p.surah == _surah && p.ayah >= _from && p.ayah <= _to;
  }

  Future<void> _start() async {
    final s = Quran.surah(_surah);
    await _player.play(s.start + _from - 1, to: s.start + _to - 1, repeat: _ayahRepeat, nextSurah: false, range: _rangeRepeat);
  }

  Future<void> _pickSurah() async {
    final s = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (c, sc) => ListView.builder(
          controller: sc,
          itemCount: 114,
          itemBuilder: (c, i) {
            final n = 114 - i; // من جزء عمّ للأول
            final x = Quran.surah(n);
            final cnt = _h.countOf(n);
            return ListTile(
              leading: StarNumber(n, size: 36),
              title: Text('سورة ${x.name}'),
              subtitle: Text(cnt == 0 ? '${arDigits(x.ayahCount)} آية' : 'محفوظ ${arDigits(cnt)} من ${arDigits(x.ayahCount)}'),
              trailing: _h.complete(n) ? const Icon(Icons.verified_rounded, color: AppColors.turquoise) : null,
              onTap: () => Navigator.pop(c, n),
            );
          },
        ),
      ),
    );
    if (s != null) _setSurah(s);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الحفظ والمراجعة')),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: Listenable.merge([_h, _player]),
        builder: (context, _) {
          final s = Quran.surah(_surah);
          final total = _h.totalAyat;
          final playingHere = _player.active && _inRange(_player.current);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
            HeroCard(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                ProgressRing(value: total / Quran.totalAyat, size: 70, stroke: 7, center: Text('${arDigits((total * 100 / Quran.totalAyat).toStringAsFixed(1)).replaceAll('.', '٫')}٪', style: t.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('محفوظك', style: t.labelLarge?.copyWith(color: Colors.white70)),
                    Text('${arDigits(total)} آية', style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    Text('${arDigits(_h.completeSurahs)} سورة كاملة', style: t.bodyMedium?.copyWith(color: AppColors.goldLight)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const SectionTitle('جلسة حفظ'),
            const SizedBox(height: 8),
            SoftCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                OutlinedButton.icon(
                  onPressed: _pickSurah,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text('سورة ${s.name}  ·  ${arDigits(s.ayahCount)} آية'),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _stepper('من آية', _from, 1, s.ayahCount, (v) => setState(() {
                        _from = v;
                        if (_to < v) _to = v;
                      }))),
                  const SizedBox(width: 10),
                  Expanded(child: _stepper('إلى آية', _to, _from, s.ayahCount, (v) => setState(() => _to = v))),
                ]),
                const SizedBox(height: 10),
                _choice('تكرار كل آية', _ayahRepeat, const [1, 3, 5, 7, 10, 20], (v) => setState(() => _ayahRepeat = v)),
                _choice('تكرار المقطع كله', _rangeRepeat, const [1, 3, 5, 10, 0], (v) => setState(() => _rangeRepeat = v)),
                const SizedBox(height: 6),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.record_voice_over_rounded, color: AppColors.turquoise),
                  title: Text(_player.reciterName),
                  subtitle: const Text('للحفظ: الحصري المعلّم بيقرا ببطء وبيسيب وقت للترديد'),
                  trailing: TextButton(onPressed: () async {
                    await showReciterSheet(context);
                    if (mounted) setState(() {});
                  }, child: const Text('تغيير')),
                ),
                FilledButton.icon(
                  onPressed: playingHere ? _player.stop : _start,
                  icon: Icon(playingHere ? Icons.stop_rounded : Icons.repeat_rounded),
                  label: Text(playingHere ? 'إيقاف التكرار' : 'ابدأ التكرار'),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: SectionTitle('الآيات (${arDigits(_from)}–${arDigits(_to)})')),
              FilterChip(
                label: const Text('اختبر نفسك'),
                avatar: Icon(_hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                selected: _hide,
                showCheckmark: false,
                onSelected: (v) => setState(() {
                  _hide = v;
                  _revealed.clear();
                }),
              ),
            ]),
            if (_hide) Text('الآيات مخفية: سمّع لنفسك، واضغط على الآية عشان تتأكد.', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            FutureBuilder<List<String>>(
              future: Quran.surahAyat(_surah),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                final ayat = snap.data!;
                return Column(children: [
                  for (var a = _from; a <= _to && a <= ayat.length; a++)
                    Builder(builder: (context) {
                      final g = s.start + a - 1;
                      final now = _player.current == g;
                      final hidden = _hide && !_revealed.contains(a);
                      final memo = (_h.done[_surah] ?? {}).contains(a);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          onTap: () => setState(() => _revealed.contains(a) ? _revealed.remove(a) : _revealed.add(a)),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: now ? AppColors.turquoise : (memo ? AppColors.amber : Colors.transparent), width: 4)),
                            ),
                            padding: const EdgeInsets.only(right: 10),
                            child: hidden
                                ? Row(children: [
                                    Text('${ayat[a - 1].split(' ').first} …', style: AppTheme.quran(size: 21, height: 2, color: cs.onSurface)),
                                    const Spacer(),
                                    Text('﴿${arDigits(a)}﴾', style: AppTheme.quran(size: 18, color: AppColors.turquoise)),
                                  ])
                                : Text('${ayat[a - 1]} ﴿${arDigits(a)}﴾',
                                    style: AppTheme.quran(size: 21, height: 2.05, color: now ? AppColors.turquoise : cs.onSurface)),
                          ),
                        ),
                      );
                    }),
                ]);
              },
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    _h.mark(_surah, _from, _to, true);
                    toast(context, 'تمام، علّمنا الآيات ${arDigits(_from)}–${arDigits(_to)} محفوظة');
                    final n = s.ayahCount;
                    if (_to < n) {
                      setState(() {
                        _from = _to + 1;
                        _to = (_from + 4).clamp(_from, n);
                        _revealed.clear();
                      });
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('حفظت المقطع ده'),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            const SectionTitle('المراجعة'),
            const SizedBox(height: 6),
            if (_h.done.isEmpty)
              Text('لما تعلّم آيات إنها محفوظة هتظهر هنا، والأقدم مراجعةً فوق.', style: t.bodyMedium)
            else
              for (final n in (_h.done.keys.toList()..sort((a, b) => _h.daysSinceReview(b).compareTo(_h.daysSinceReview(a)))))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    child: Row(children: [
                      StarNumber(n, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('سورة ${Quran.surah(n).name}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          Text(
                            '${_h.complete(n) ? 'كاملة' : '${arDigits(_h.countOf(n))} من ${arDigits(Quran.surah(n).ayahCount)} آية'} · '
                            '${_h.daysSinceReview(n) == 0 ? 'روجعت النهارده' : _h.daysSinceReview(n) >= 999 ? 'لم تُراجع' : 'آخر مراجعة من ${daysLabel(_h.daysSinceReview(n))}'}',
                            style: t.bodySmall?.copyWith(color: _h.daysSinceReview(n) > 7 ? AppColors.rose : null),
                          ),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'اقرأ في المصحف',
                        onPressed: () => openMushaf(context, ayah: Quran.surah(n).start),
                        icon: const Icon(Icons.auto_stories_rounded),
                      ),
                      IconButton(
                        tooltip: 'راجعتها',
                        onPressed: () {
                          _h.review(n);
                          toast(context, 'بارك الله فيك');
                        },
                        icon: const Icon(Icons.task_alt_rounded, color: AppColors.turquoise),
                      ),
                    ]),
                  ),
                ),
          ]);
        },
      ),
    );
  }

  Widget _stepper(String label, int v, int min, int max, ValueChanged<int> on) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Text(label, style: t.labelSmall),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(visualDensity: VisualDensity.compact, onPressed: v > min ? () => on(v - 1) : null, icon: const Icon(Icons.remove_rounded)),
          Text(arDigits(v), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          IconButton(visualDensity: VisualDensity.compact, onPressed: v < max ? () => on(v + 1) : null, icon: const Icon(Icons.add_rounded)),
        ]),
      ]),
    );
  }

  Widget _choice(String label, int v, List<int> opts, ValueChanged<int> on) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Wrap(spacing: 4, children: [
          for (final o in opts)
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              label: Text(o == 0 ? '∞' : arDigits(o)),
              selected: v == o,
              onSelected: (_) => on(o),
            ),
        ]),
      ]),
    );
  }
}
