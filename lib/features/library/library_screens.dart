import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

void openAsma(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AsmaScreen()));
void openNawawi(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NawawiScreen()));

Future<List<Map<String, dynamic>>> _loadList(String path) async =>
    (jsonDecode(await rootBundle.loadString(path)) as List).cast<Map<String, dynamic>>();

/// أسماء الله الحسنى (رواية الترمذي) مع معنى مختصر لكل اسم
class AsmaScreen extends StatelessWidget {
  const AsmaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('أسماء الله الحسنى')),
      body: FutureBuilder(
        future: _loadList('assets/library/asma.json'),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HeroCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      Text('﴿وَلِلَّهِ ٱلْأَسْمَآءُ ٱلْحُسْنَىٰ فَٱدْعُوهُ بِهَا﴾',
                          textAlign: TextAlign.center, style: AppTheme.quran(size: 21, height: 1.9, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text('«إِنَّ لِلَّهِ تِسْعَةً وَتِسْعِينَ اسْمًا، مِائَةً إِلَّا وَاحِدًا، مَنْ أَحْصَاهَا دَخَلَ الْجَنَّةَ» — متفق عليه',
                          textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: Colors.white70, height: 1.7)),
                    ]),
                  ),
                );
              }
              final x = list[i - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                  child: Row(children: [
                    StarNumber(i),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x['name'] as String, style: AppTheme.quran(size: 24, height: 1.5, color: AppColors.turquoise)),
                        Text(x['meaning'] as String, style: t.bodyMedium?.copyWith(height: 1.6)),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('الأسماء على رواية الترمذي المشهورة، والمعاني مختصرة. للعلماء كلام في تعيين الأسماء، فراجع أهل العلم للتفصيل.',
              textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}

/// الأربعون النووية (٤٢ حديثًا)
class NawawiScreen extends StatelessWidget {
  const NawawiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الأربعون النووية')),
      body: FutureBuilder(
        future: _loadList('assets/library/nawawi.json'),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final x = list[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _HadithPager(list: list, start: i))),
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  child: Row(children: [
                    StarNumber(i + 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x['title'] as String, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text('الحديث ${ordinalAr(i + 1)}', style: t.bodySmall),
                      ]),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HadithPager extends StatefulWidget {
  final List<Map<String, dynamic>> list;
  final int start;
  const _HadithPager({required this.list, required this.start});
  @override
  State<_HadithPager> createState() => _HadithPagerState();
}

class _HadithPagerState extends State<_HadithPager> {
  late final _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final x = widget.list[_i];
    return Scaffold(
      appBar: AppBar(
        title: Text('الحديث ${ordinalAr(_i + 1)}'),
        actions: [
          IconButton(
            tooltip: 'نسخ',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${x['title']}\n\n${x['text']}\n\n(الأربعون النووية — ${arDigits(_i + 1)})'));
              if (context.mounted) toast(context, 'تم نسخ الحديث');
            },
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.list.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (context, i) {
          final h = widget.list[i];
          return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 32), children: [
            Text(h['title'] as String, textAlign: TextAlign.center, style: t.titleLarge?.copyWith(color: AppColors.turquoise, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            SoftCard(
              padding: const EdgeInsets.all(18),
              child: SelectableText(h['text'] as String, textAlign: TextAlign.justify, style: AppTheme.quran(size: 20, height: 2.05, color: cs.onSurface)),
            ),
            const SizedBox(height: 12),
            Text('اسحب يمين أو شمال للحديث التالي', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]);
        },
      ),
    );
  }
}

/// «الأول، الثاني… » لحد ٤٢
String ordinalAr(int n) {
  const ones = ['', 'الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];
  const units = ['', 'الحادي', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع'];
  if (n <= 10) return ones[n];
  if (n < 20) return '${units[n - 10]} عشر';
  const tens = {2: 'العشرون', 3: 'الثلاثون', 4: 'الأربعون'};
  final u = n % 10, d = n ~/ 10;
  if (u == 0) return tens[d] ?? arDigits(n);
  return '${units[u]} و${tens[d] ?? ''}';
}
