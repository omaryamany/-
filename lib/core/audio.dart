import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'quran.dart';

/// التلاوة آية بآية: كل آية بتتحفظ على الجهاز أول ما تتسمع، فتشتغل بعد كده من غير نت.
/// وفيه تنزيل سورة كاملة مقدمًا.
class AudioStore {
  static Directory? _dir;

  static Future<Directory> _root() async {
    if (_dir != null) return _dir!;
    final d = Directory('${(await getApplicationSupportDirectory()).path}/quran_audio');
    if (!await d.exists()) await d.create(recursive: true);
    return _dir = d;
  }

  static String _name(int surah, int ayah) => '${surah.toString().padLeft(3, '0')}${ayah.toString().padLeft(3, '0')}.mp3';

  static Future<File> fileFor(String reciter, int surah, int ayah) async {
    final d = Directory('${(await _root()).path}/$reciter');
    if (!await d.exists()) await d.create(recursive: true);
    return File('${d.path}/${_name(surah, ayah)}');
  }

  static Future<bool> _has(File f) async => await f.exists() && await f.length() > 1000;

  /// مصدر الصوت: من الملف لو موجود، وإلا من النت مع حفظه على الجهاز
  static Future<AudioSource> source(String reciter, int surah, int ayah, {Object? tag}) async {
    final f = await fileFor(reciter, surah, ayah);
    if (await _has(f)) return AudioSource.file(f.path, tag: tag);
    // ignore: experimental_member_use
    return LockCachingAudioSource(Uri.parse(Quran.audioUrl(surah, ayah, reciter)), cacheFile: f, tag: tag);
  }

  static Future<int> downloadedCount(String reciter, int surah) async {
    final s = Quran.surah(surah);
    var n = 0;
    for (var a = 1; a <= s.ayahCount; a++) {
      if (await _has(await fileFor(reciter, surah, a))) n++;
    }
    return n;
  }

  /// تنزيل سورة كاملة (بيكمّل من مكان ما وقف لو النت قطع)
  static Future<bool> downloadSurah(String reciter, int surah, void Function(int done, int total) onProgress) async {
    final s = Quran.surah(surah);
    final client = http.Client();
    var ok = true;
    try {
      for (var a = 1; a <= s.ayahCount; a++) {
        final f = await fileFor(reciter, surah, a);
        if (!await _has(f)) {
          try {
            final r = await client.get(Uri.parse(Quran.audioUrl(surah, a, reciter))).timeout(const Duration(seconds: 40));
            if (r.statusCode == 200 && r.bodyBytes.length > 1000) {
              await f.writeAsBytes(r.bodyBytes, flush: true);
            } else {
              ok = false;
            }
          } catch (_) {
            ok = false;
          }
        }
        onProgress(a, s.ayahCount);
      }
    } finally {
      client.close();
    }
    return ok;
  }

  /// حجم التلاوات المحفوظة (ميجا)
  static Future<double> sizeMb() async {
    var total = 0;
    final root = await _root();
    await for (final e in root.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total / (1024 * 1024);
  }

  static Future<void> clear() async {
    final d = await _root();
    if (await d.exists()) await d.delete(recursive: true);
    _dir = null;
  }
}
