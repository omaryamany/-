import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';

/// قائمة السور (مع فلترة بالاسم)
class SurahList extends StatelessWidget {
  final String filter;
  final ValueChanged<int> onPick;
  final ScrollController? controller;
  const SurahList({super.key, this.filter = '', required this.onPick, this.controller});

  @override
  Widget build(BuildContext context) {
    final q = normalizeArabic(filter);
    final list = q.isEmpty
        ? Quran.surahs
        : Quran.surahs.where((s) => normalizeArabic(s.name).contains(q) || '${s.number}' == filter.trim() || arDigits(s.number) == filter.trim()).toList();
    if (list.isEmpty) return const EmptyView(icon: Icons.search_off_rounded, text: 'لا توجد سورة بهذا الاسم');
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 64, color: cs.outlineVariant.withValues(alpha: .4)),
      itemBuilder: (_, i) {
        final s = list[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: StarNumber(s.number, size: 42),
          title: Text('سورة ${s.name}', style: AppTheme.quran(size: 20, height: 1.5, color: cs.onSurface)),
          subtitle: Text('${s.meccan ? 'مكية' : 'مدنية'} · ${arDigits(s.ayahCount)} آية', style: t.bodySmall),
          trailing: Text('ص ${arDigits(s.page)}', style: t.labelLarge?.copyWith(color: cs.primary)),
          onTap: () => onPick(s.start),
        );
      },
    );
  }
}

/// قائمة الأجزاء
class JuzList extends StatelessWidget {
  final ValueChanged<int> onPick;
  final ScrollController? controller;
  const JuzList({super.key, required this.onPick, this.controller});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: Quran.juz.length,
      separatorBuilder: (_, __) => Divider(height: 1, indent: 64, color: cs.outlineVariant.withValues(alpha: .4)),
      itemBuilder: (_, i) {
        final j = Quran.juz[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: StarNumber(j.number, size: 42, color: AppColors.gold),
          title: Text('الجزء ${arDigits(j.number)}', style: t.titleMedium),
          subtitle: Text('يبدأ من ${Quran.formatAyah(j.start)}', style: t.bodySmall),
          trailing: Text('ص ${arDigits(j.page)}', style: t.labelLarge?.copyWith(color: cs.primary)),
          onTap: () => onPick(j.start),
        );
      },
    );
  }
}

/// العلامات + آخر موضع
class BookmarksList extends StatelessWidget {
  final ValueChanged<int> onPick;
  final ScrollController? controller;
  const BookmarksList({super.key, required this.onPick, this.controller});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        return ListView(controller: controller, padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
          if (store.hasHistory)
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0x220F5C4F), child: Icon(Icons.history_rounded, color: AppColors.pine)),
              title: const Text('آخر موضع قراءة'),
              subtitle: Text(
                  '${store.lastAyah != null ? Quran.formatAyah(store.lastAyah!) : 'صفحة ${arDigits(store.lastPage)}'} · ${relativeTime(store.lastAt!)}'),
              onTap: () => onPick(store.lastAyah ?? Quran.pageRange(store.lastPage).start),
            ),
          if (store.bookmarks.isEmpty)
            const EmptyView(icon: Icons.bookmark_border_rounded, text: 'اضغط على أي آية في المصحف واختر «علامة» لتحفظها هنا')
          else ...[
            Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 4), child: Text('العلامات', style: t.titleSmall)),
            for (final b in store.bookmarks)
              Dismissible(
                key: ValueKey('bm${b.ayah}'),
                onDismissed: (_) => store.toggleBookmark(b.ayah),
                background: Container(color: AppColors.rose.withValues(alpha: .15)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0x22D64561), child: Icon(Icons.bookmark_rounded, color: AppColors.rose)),
                  title: Text(Quran.formatAyah(b.ayah)),
                  subtitle: Text('صفحة ${arDigits(b.page)} · ${relativeTime(b.at)}'),
                  trailing: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'حذف', onPressed: () => store.toggleBookmark(b.ayah)),
                  onTap: () => onPick(b.ayah),
                ),
              ),
          ],
        ]);
      },
    );
  }
}

/// الفهرس كـ bottom sheet (من جوه المصحف)
void showIndexSheet(BuildContext context, {required ValueChanged<int> onPick}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      void pick(int g) {
        Navigator.pop(c);
        onPick(g);
      }

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (c, sc) => DefaultTabController(
          length: 3,
          child: Column(children: [
            const TabBar(tabs: [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'العلامات')]),
            Expanded(
              child: TabBarView(children: [
                SurahList(onPick: pick, controller: sc),
                JuzList(onPick: pick),
                BookmarksList(onPick: pick),
              ]),
            ),
          ]),
        ),
      );
    },
  );
}

/// البحث في القرآن كله
void showSearchSheet(BuildContext context, {required ValueChanged<int> onPick}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: _SearchSheet(onPick: (g) {
        Navigator.pop(c);
        onPick(g);
      }),
    ),
  );
}

class _SearchSheet extends StatefulWidget {
  final ValueChanged<int> onPick;
  const _SearchSheet({required this.onPick});
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  Timer? _deb;
  List<(int, String)> _res = [];
  bool _busy = false;
  String _q = '';

  void _onChange(String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        _busy = true;
        _q = v;
      });
      final r = await QuranSearch.search(v);
      if (mounted && _q == v) {
        setState(() {
          _res = r;
          _busy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: _onChange,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(hintText: 'ابحث بكلمة من الآية (بدون تشكيل)', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (!_busy && _q.trim().length >= 2)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(_res.length >= 200 ? 'أكثر من ٢٠٠ نتيجة — حدّد كلمات أكثر' : 'عدد النتائج: ${arDigits(_res.length)}', style: t.bodySmall),
          ),
        Expanded(
          child: _res.isEmpty && !_busy
              ? SingleChildScrollView(
                  child: EmptyView(
                    icon: Icons.manage_search_rounded,
                    text: _q.trim().length >= 2 ? 'لا توجد نتائج' : 'ابحث بأي كلمة — مثلًا: الصبر، يوسف، الجنة',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: _res.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: .4)),
                  itemBuilder: (_, i) {
                    final (g, text) = _res[i];
                    return ListTile(
                      onTap: () => widget.onPick(g),
                      title: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: AppTheme.quran(size: 18, height: 1.9, color: cs.onSurface)),
                      subtitle: Text('${Quran.formatAyah(g)} · صفحة ${arDigits(Quran.pageOf(g))}', style: t.bodySmall?.copyWith(color: cs.primary)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// الأحزاب وأرباعها (٦٠ حزب × ٤ أرباع) مع أول كلمات كل ربع
class HizbList extends StatelessWidget {
  final ValueChanged<int> onPick;
  const HizbList({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const parts = ['الحزب', 'ربع', 'نصف', 'ثلاثة أرباع'];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: Hizb.quarters.length,
      itemBuilder: (_, q) {
        final g = Hizb.quarters[q];
        final first = q % 4 == 0;
        final tile = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: SizedBox(
            width: 42,
            child: Center(
              child: first
                  ? StarNumber(q ~/ 4 + 1, size: 40, color: AppColors.gold)
                  : Text(['', '¼', '½', '¾'][q % 4], style: t.titleLarge?.copyWith(color: cs.primary)),
            ),
          ),
          title: FutureBuilder<String>(
            future: Quran.ayahText(g),
            builder: (context, snap) => Text(
              snap.hasData ? _opening(g, snap.data!) : '…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.quran(size: 18, height: 1.7, color: cs.onSurface),
            ),
          ),
          subtitle: Text('${first ? parts[0] : parts[q % 4]} ${first ? arDigits(q ~/ 4 + 1) : ''} · ${Quran.formatAyah(g)}', style: t.bodySmall),
          trailing: Text('ص ${arDigits(Quran.pageOf(g))}', style: t.labelLarge?.copyWith(color: cs.primary)),
          onTap: () => onPick(g),
        );
        if (q % 8 != 0) return tile;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
            child: Text('الجزء ${arDigits(q ~/ 8 + 1)}', style: t.titleSmall?.copyWith(color: AppColors.gold)),
          ),
          tile,
        ]);
      },
    );
  }
}

/// أول ٦ كلمات من الآية (من غير البسملة وعلامة الحزب)
String _opening(int g, String text) {
  var words = text.split(' ').where((w) => w != '۞').toList();
  final p = Quran.fromGlobal(g);
  if (p.ayah == 1 && p.surah != 1 && words.length > 4 && words.first.endsWith('سْمِ')) words = words.sublist(4);
  return words.take(6).join(' ');
}
