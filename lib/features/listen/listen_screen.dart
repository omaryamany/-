import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/player.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'now_playing.dart';

void openListen(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ListenScreen()));
}

/// الاستماع للقرآن: اختيار القارئ وتشغيل أي سورة (بتكمّل في الخلفية)
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});
  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([player, store]),
      builder: (context, _) {
        final t = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        final playingSurah = player.active ? Quran.fromGlobal(player.current!).surah : null;
        final q = normalizeArabic(_q);
        final list = q.isEmpty ? Quran.surahs : Quran.surahs.where((s) => normalizeArabic(s.name).contains(q)).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('الاستماع')),
          bottomNavigationBar: MiniPlayer(onOpen: (_) => openNowPlaying(context)),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: HeroCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                onTap: () => showReciterSheet(context),
                child: Row(children: [
                  const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.record_voice_over_rounded, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('القارئ', style: t.bodySmall?.copyWith(color: Colors.white70)),
                      Text(Quran.reciter(store.reciter).name, style: t.titleLarge?.copyWith(color: Colors.white)),
                    ]),
                  ),
                  Text('تغيير (${arDigits(Quran.reciters.length)})', style: t.labelLarge?.copyWith(color: AppColors.goldLight)),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(hintText: 'ابحث عن سورة', prefixIcon: Icon(Icons.search_rounded), isDense: true),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  final now = playingSurah == s.number;
                  return ListTile(
                    leading: StarNumber(s.number, size: 40),
                    title: Text('سورة ${s.name}', style: AppTheme.quran(size: 19, height: 1.5, color: now ? cs.primary : cs.onSurface)),
                    subtitle: Text('${arDigits(s.ayahCount)} آية${now ? ' · الآية ${arDigits(Quran.fromGlobal(player.current!).ayah)}' : ''}', style: t.bodySmall),
                    trailing: IconButton.filledTonal(
                      onPressed: () => now ? player.toggle() : player.play(s.start),
                      icon: Icon(now && player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    ),
                    onTap: () => now ? player.toggle() : player.play(s.start),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// قائمة القرّاء
Future<void> showReciterSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) {
      final store = AppStore.instance;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .95,
        builder: (c, sc) => ListenableBuilder(
          listenable: store,
          builder: (c, _) => ListView(controller: sc, padding: const EdgeInsets.only(bottom: 24), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('اختر القارئ', style: Theme.of(c).textTheme.titleLarge),
            ),
            for (final r in Quran.reciters)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: store.reciter == r.id ? AppColors.pine : AppColors.gold.withValues(alpha: .15),
                  child: Icon(store.reciter == r.id ? Icons.check_rounded : Icons.person_outline_rounded,
                      color: store.reciter == r.id ? Colors.white : AppColors.gold),
                ),
                title: Text(r.name, style: TextStyle(fontWeight: store.reciter == r.id ? FontWeight.w700 : FontWeight.w500)),
                onTap: () async {
                  await store.setReciter(r.id);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
          ]),
        ),
      );
    },
  );
}

/// شريط التشغيل الصغير — بيظهر في أي شاشة طول ما التلاوة شغالة
class MiniPlayer extends StatelessWidget {
  final ValueChanged<int>? onOpen;

  /// false لما يكون فوق شريط التنقل (الشريط نفسه بياخد مسافة أسفل الشاشة)
  final bool safeBottom;
  const MiniPlayer({super.key, this.onOpen, this.safeBottom = true});

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        if (!player.active) return const SizedBox.shrink();
        final g = player.current!;
        final p = Quran.fromGlobal(g);
        final t = Theme.of(context).textTheme;
        return SafeArea(
          top: false,
          bottom: safeBottom,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.pine.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onOpen == null ? null : () => onOpen!(g),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  child: Row(children: [
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.goldLight),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('سورة ${Quran.surah(p.surah).name} · آية ${arDigits(p.ayah)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: Colors.white)),
                        Text(player.reciterName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: Colors.white70)),
                      ]),
                    ),
                    IconButton(onPressed: player.previous, icon: const Icon(Icons.skip_next_rounded, color: Colors.white), tooltip: 'الآية السابقة'),
                    player.loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          )
                        : IconButton(
                            onPressed: player.toggle,
                            icon: Icon(player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                          ),
                    IconButton(onPressed: player.next, icon: const Icon(Icons.skip_previous_rounded, color: Colors.white), tooltip: 'الآية التالية'),
                    IconButton(onPressed: player.stop, icon: const Icon(Icons.close_rounded, color: Colors.white70), tooltip: 'إيقاف'),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
