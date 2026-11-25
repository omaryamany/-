import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'share_ayah.dart';

/// التفسير الميسّر للآية، مع التنقّل للآية السابقة والتالية
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

  Future<(String, String)> _load(int g) async => (await Quran.ayahText(g), await Tafsir.of(g));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      minChildSize: .4,
      maxChildSize: .95,
      builder: (context, sc) => FutureBuilder<(String, String)>(
        key: ValueKey(_g),
        future: _load(_g),
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
                    Text('التفسير الميسّر', style: t.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
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
            const Divider(height: 1),
            Expanded(
              child: !snap.hasData
                  ? const Center(child: CircularProgressIndicator())
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
                      SelectableText(snap.data!.$2, textAlign: TextAlign.justify, style: t.bodyLarge?.copyWith(height: 1.9)),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: '﴿${snap.data!.$1}﴾ [${Quran.formatAyah(_g)}]\n\nالتفسير الميسر: ${snap.data!.$2}'));
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
                      Text('المصدر: التفسير الميسّر — مجمع الملك فهد لطباعة المصحف الشريف', textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
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
