import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arabic.dart';
import '../../core/player.dart';
import '../../core/theme.dart';
import '../../core/ui.dart';
import 'listen_screen.dart';

void openRadio(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RadioScreen()));

class RadioStation {
  final String name, url, group;
  final bool featured;
  const RadioStation(this.name, this.url, this.group, this.featured);
}

/// إذاعات القرآن: إذاعة القاهرة والسعودية + إذاعات القراء والتفسير (بث مباشر، بيكمّل في الخلفية)
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});
  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  List<RadioStation> _all = [];
  String _q = '';
  final _player = QuranPlayer.instance;

  static const _egypt = ['الحصري', 'المنشاوي', 'عبدالباسط', 'البنا', 'الطبلاوي', 'مصطفى إسماعيل'];

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/library/radios.json').then((s) {
      final list = (jsonDecode(s) as List).cast<Map>();
      setState(() {
        _all = [
          for (final m in list)
            RadioStation(m['name'] as String, m['url'] as String, m['group'] as String,
                m['featured'] == true || _egypt.any((e) => (m['name'] as String).contains(e)))
        ];
      });
    });
    _player.error.addListener(_onError);
  }

  @override
  void dispose() {
    _player.error.removeListener(_onError);
    super.dispose();
  }

  void _onError() {
    final e = _player.error.value;
    if (e != null && mounted) {
      toast(context, e);
      _player.error.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = normalizeArabic(_q);
    final shown = q.isEmpty ? _all : _all.where((r) => normalizeArabic(r.name).contains(q)).toList();
    final featured = q.isEmpty ? shown.where((r) => r.featured).toList() : <RadioStation>[];
    final groups = <String, List<RadioStation>>{};
    for (final r in shown) {
      if (featured.contains(r)) continue;
      groups.putIfAbsent(r.group, () => []).add(r);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إذاعات القرآن')),
      bottomNavigationBar: const MiniPlayer(),
      body: ListenableBuilder(
        listenable: _player,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(hintText: 'ابحث عن إذاعة أو قارئ', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          if (featured.isNotEmpty) ...[
            const SectionTitle('مختارة'),
            const SizedBox(height: 6),
            for (final r in featured) _tile(r, t, big: r.group == 'رسمية'),
            const SizedBox(height: 8),
          ],
          for (final g in groups.entries) ...[
            SectionTitle(g.key == 'القراء' ? 'إذاعات القراء (${arDigits(g.value.length)})' : 'إذاعات ${g.key}'),
            const SizedBox(height: 6),
            for (final r in g.value) _tile(r, t),
            const SizedBox(height: 8),
          ],
          if (_all.isNotEmpty)
            Text('البث من إذاعة القرآن الكريم بالقاهرة والسعودية ومن إذاعات موقع mp3quran.net — محتاج إنترنت.',
                textAlign: TextAlign.center, style: t.labelSmall),
        ]),
      ),
    );
  }

  Widget _tile(RadioStation r, TextTheme t, {bool big = false}) {
    final on = _player.radio == r.name;
    final playing = on && _player.playing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        onTap: () => on ? _player.toggle() : _player.playRadio(r.url, r.name),
        padding: EdgeInsets.fromLTRB(12, big ? 14 : 8, 8, big ? 14 : 8),
        child: Row(children: [
          Container(
            width: big ? 50 : 40,
            height: big ? 50 : 40,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: on ? AppColors.tealGradient : AppColors.heroGradient),
            child: Icon(r.group == 'رسمية' ? Icons.cell_tower_rounded : Icons.radio_rounded, color: Colors.white, size: big ? 26 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: (big ? t.titleMedium : t.bodyLarge)?.copyWith(fontWeight: FontWeight.w700)),
              if (on) Text(_player.loading ? 'جاري الاتصال…' : (playing ? 'يُذاع الآن' : 'متوقف مؤقتًا'), style: t.bodySmall?.copyWith(color: AppColors.turquoise)),
            ]),
          ),
          Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: on ? AppColors.turquoise : AppColors.pine, size: 34),
        ]),
      ),
    );
  }
}
