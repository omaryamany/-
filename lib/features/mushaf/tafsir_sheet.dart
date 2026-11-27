import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'share_ayah.dart';

/// تفسير الآية (الميسّر، السعدي، ابن كثير) مع التنقّل للآية السابقة والتالية
void showTafsir(BuildContext context, int ayah) {
  showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _TafsirSheet(ayah: ayah));
}

class _TafsirSheet extends StatefulWidget {
  final int ayah;
  const _TafsirSheet({required this.ayah});
  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  late int _g = widget.ayah;
  static TafsirKind? _last;
  TafsirKind _kind = _last ?? TafsirKind.muyassar;

  @override
  void initState() {
    super.initState();
    if (_last == null) {
      SharedPreferences.getInstance().then((p) {
        final k = TafsirKind.values.firstWhere((x) => x.name == p.getString('tafsir.kind'), orElse: () => TafsirKind.muyassar);
        _last = k;
        if (mounted && k != _kind) setState(() => _kind = k);
      });
    }
  }

  void _setKind(TafsirKind k) {
    _last = k;
    SharedPreferences.getInstance().then((p) => p.setString('tafsir.kind', k.name));
    setState(() => _kind = k);
  }

  /// النص اللي بيتعرض: كل آيات المجموعة لو التفسير جامع لأكتر من آية
  Future<(String, TafsirEntry)> _load(int g, TafsirKind k) async {
    final e = await Tafsir.entry(g, k);
    final p = Quran.fromGlobal(g);
    final first = g - (p.ayah - e.from);
    final parts = <String>[];
    for (var x = first; x <= first + (e.to - e.from); x++) {
      parts.add('${await Quran.ayahText(x)} ﴿${arDigits(Quran.fromGlobal(x).ayah)}﴾');
    }
    return (parts.join(' '), e);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, sc) => FutureBuilder<(String, TafsirEntry)>(
        key: ValueKey('$_g:${_kind.name}'),
        future: _load(_g, _kind),
        builder: (context, snap) {
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Row(children: [
                IconButton(
                  tooltip: 'الآية السابقة',
                  onPressed: _g > 1 ? () => setState(() => _g--) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                Expanded(
                  child: Column(children: [
                    Text('تفسير ${Tafsir.name(_kind)}', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    Text(Quran.formatAyah(_g), style: t.titleMedium),
                  ]),
                ),
                IconButton(
                  tooltip: 'الآية التالية',
                  onPressed: _g < Quran.totalAyat ? () => setState(() => _g++) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<TafsirKind>(
                showSelectedIcon: false,
                segments: [for (final k in TafsirKind.values) ButtonSegment(value: k, label: Text(Tafsir.name(k)))],
                selected: {_kind},
                onSelectionChanged: (v) => _setKind(v.first),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: snap.hasError
                  ? EmptyView(
                      icon: Icons.wifi_off_rounded,
                      text: 'تفسير ${Tafsir.name(_kind)} محتاج نت أول مرة: بيتحمّل سورة سورة ويتحفظ على الموبايل، وبعدها يشتغل من غير نت.',
                      action: FilledButton(onPressed: () => setState(() {}), child: const Text('حاول تاني')),
                    )
                  : !snap.hasData
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        if (Tafsir.online(_kind)) ...[
                          const SizedBox(height: 12),
                          Text('جاري تحميل تفسير السورة…', style: t.bodySmall),
                        ],
                      ]),
                    )
                  : ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
                        ),
                        child: Text('﴿${snap.data!.$1}﴾',
                            textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: AppTheme.quran(size: 21, height: 2.1, color: cs.onSurface)),
                      ),
                      const SizedBox(height: 16),
                      if (snap.data!.$2.to > snap.data!.$2.from)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Pill('تفسير الآيات ${arDigits(snap.data!.$2.from)}–${arDigits(snap.data!.$2.to)} معًا', color: AppColors.turquoise),
                        ),
                      SelectableText(snap.data!.$2.text.isEmpty ? 'لا يوجد تفسير لهذه الآية في هذا الكتاب.' : snap.data!.$2.text, textAlign: TextAlign.justify, style: t.bodyLarge?.copyWith(height: 1.9)),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: '﴿${snap.data!.$1}﴾ [${Quran.formatAyah(_g)}]\n\nتفسير ${Tafsir.name(_kind)}: ${snap.data!.$2.text}'));
                              if (context.mounted) toast(context, 'تم نسخ الآية وتفسيرها');
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('نسخ'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => openShareAyah(context, _g),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('صورة للمشاركة'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text('المصدر: ${Tafsir.source(_kind)}', textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      Text('سورة ${Quran.surah(Quran.fromGlobal(_g).surah).name} · صفحة ${arDigits(Quran.pageOf(_g))}',
                          textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}
