import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'arabic.dart';
import 'audio.dart';
import 'quran.dart';
import 'store.dart';

/// مشغّل التلاوة الموحّد للتطبيق كله: بيكمّل في الخلفية والشاشة مقفولة (مع أزرار التحكم في الإشعار)،
/// وبيفضل شغال لو خرجت من المصحف لشاشة تانية.
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._();
  static final QuranPlayer instance = QuranPlayer._();

  final AudioPlayer _player = AudioPlayer();

  /// الآية (الرقم العام) لكل عنصر في قائمة التشغيل
  List<int> _queue = [];
  int? _to;
  bool _nextSurah = true;
  int _repeat = 1;
  bool _started = false;

  /// الآية اللي بتتقري دلوقتي (null = مفيش تلاوة)
  int? current;
  bool playing = false;
  bool loading = false;

  /// رسالة خطأ للواجهة (بتتمسح بعد ما تتعرض)
  final error = ValueNotifier<String?>(null);

  bool get active => current != null;
  String get reciterName => Quran.reciter(AppStore.instance.reciter).name;

  void _init() {
    if (_started) return;
    _started = true;
    _player.currentIndexStream.listen((i) {
      if (i == null || i >= _queue.length) return;
      if (current != _queue[i]) {
        current = _queue[i];
        notifyListeners();
      }
    });
    _player.playerStateStream.listen((s) {
      final changed = playing != s.playing || loading != (s.processingState == ProcessingState.loading);
      playing = s.playing;
      loading = s.processingState == ProcessingState.loading;
      if (s.processingState == ProcessingState.completed) {
        _onComplete();
      } else if (changed) {
        notifyListeners();
      }
    });
  }

  /// تشغيل من آية [from]: لحد [to] لو محدد، وإلا لآخر السورة ثم السور اللي بعدها.
  /// [repeat] عدد مرات تكرار كل آية.
  Future<void> play(int from, {int? to, int repeat = 1, bool nextSurah = true}) async {
    _init();
    final s = Quran.surah(Quran.fromGlobal(from).surah);
    final end = (to == null || to > s.end) ? s.end : to;
    _to = to;
    _nextSurah = nextSurah && to == null;
    _repeat = repeat.clamp(1, 20);
    final reciter = AppStore.instance.reciter;
    final queue = <int>[];
    final sources = <AudioSource>[];
    for (var g = from; g <= end; g++) {
      final p = Quran.fromGlobal(g);
      for (var k = 0; k < _repeat; k++) {
        queue.add(g);
        sources.add(await AudioStore.source(
          reciter,
          p.surah,
          p.ayah,
          tag: MediaItem(
            id: '$reciter/$g/$k',
            title: 'سورة ${Quran.surah(p.surah).name} — آية ${arDigits(p.ayah)}',
            album: reciterName,
            artist: 'مُرتِّل',
          ),
        ));
      }
    }
    _queue = queue;
    current = from;
    loading = true;
    notifyListeners();
    try {
      // ignore: deprecated_member_use
      await _player.setAudioSource(ConcatenatingAudioSource(children: sources), initialIndex: 0);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('player: $e');
      current = null;
      loading = false;
      error.value = 'التلاوة تحتاج اتصالًا بالإنترنت أول مرة، أو نزّل السورة من الإعدادات';
      notifyListeners();
    }
  }

  void _onComplete() {
    final last = _queue.isEmpty ? null : _queue.last;
    if (last != null && _nextSurah && last < Quran.totalAyat) {
      play(last + 1, repeat: _repeat);
      return;
    }
    stop();
  }

  Future<void> toggle() async {
    if (!active) return;
    playing ? await _player.pause() : await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    current = null;
    playing = false;
    loading = false;
    _queue = [];
    _to = null;
    notifyListeners();
  }

  /// الآية التالية/السابقة (بتتخطى تكرارات نفس الآية)
  Future<void> next() async {
    final c = current;
    if (c == null) return;
    final i = _queue.indexWhere((g) => g > c);
    if (i >= 0) {
      await _player.seek(Duration.zero, index: i);
    } else if (_nextSurah && c < Quran.totalAyat) {
      await play(c + 1, repeat: _repeat);
    }
  }

  Future<void> previous() async {
    final c = current;
    if (c == null) return;
    final i = _queue.indexOf(c - 1);
    if (i >= 0) {
      await _player.seek(Duration.zero, index: i);
    } else if (c > 1) {
      await play(c - 1, to: _to, repeat: _repeat, nextSurah: _nextSurah);
    }
  }
}
