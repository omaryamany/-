import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// سطر في مصحف المدينة: كلمات بخط الصفحة أو عنوان سورة (h) أو بسملة (b)
class MadinahLine {
  final int n;
  final String k;

  /// كل عنصر = كلمة (رمز أو أكتر: الكلمة + علامة الوقف) أو علامة نهاية آية
  final List<String> words;

  /// رقم الآية العام لكل كلمة
  final List<int> ayat;

  /// ١ لو الكلمة دي علامة نهاية الآية (الدائرة برقمها)
  final List<int> ends;
  final int surah;
  const MadinahLine(this.n, this.k, this.words, this.ayat, this.ends, this.surah);
  bool get isText => k == 't';
}

/// بيقسّم رموز السطر لكلمات حسب عدد رموز كل كلمة (w)
List<String> _splitWords(String c, List<int> w) {
  final runes = c.runes.toList();
  final out = <String>[];
  var i = 0;
  for (final n in w) {
    out.add(String.fromCharCodes(runes.sublist(i, i + n)));
    i += n;
  }
  return out;
}

/// مصحف المدينة (خطوط مجمع الملك فهد QCF V1): ١٥ سطر في الصفحة بنفس تقسيم المطبوع.
/// التخطيط والخطوط (٦٠٤ خط) جوه التطبيق نفسه — بيشتغل من أول فتحة ومن غير نت.
class MushafPack {
  MushafPack._();

  /// رموز البسملة في خط الصفحة الأولى
  static const basmala = [0xFB51, 0xFB52, 0xFB53, 0xFB54];

  static List<List<MadinahLine>>? _layout;
  static Future<void>? _loadingLayout;
  static final Map<int, Future<bool>> _fonts = {};

  static String family(int page) => 'qcf$page';

  static Future<void> _loadLayout() async {
    final raw = jsonDecode(await rootBundle.loadString('assets/quran/mushaf-v1.json')) as Map;
    _layout = (raw['pages'] as List).map((pg) {
      return ((pg as Map)['l'] as List).map((l) {
        final m = l as Map;
        final k = m['k'] as String;
        if (k == 't') {
          final words = _splitWords(m['c'] as String, (m['w'] as List).cast<int>());
          return MadinahLine(m['n'] as int, k, words, (m['a'] as List).cast<int>(), (m['e'] as List).cast<int>(), 0);
        }
        return MadinahLine(m['n'] as int, k, const [], const [], const [], (m['s'] ?? 0) as int);
      }).toList();
    }).toList();
  }

  static Future<List<MadinahLine>> page(int p) async {
    if (_layout == null) {
      _loadingLayout ??= _loadLayout();
      await _loadingLayout;
    }
    return _layout![p - 1];
  }

  /// تحميل خط الصفحة في محرّك الخطوط (مرة واحدة لكل صفحة)
  static Future<bool> loadFont(int p) {
    return _fonts.putIfAbsent(p, () async {
      try {
        final loader = FontLoader(family(p))..addFont(rootBundle.load('assets/qcf/p$p.ttf'));
        await loader.load();
        return true;
      } catch (e) {
        debugPrint('mushaf font p$p: $e');
        _fonts.remove(p);
        return false;
      }
    });
  }

  /// تجهيز الصفحة: التخطيط + خطها + خط الصفحة الأولى (للبسملة)
  static Future<(List<MadinahLine>, bool)> prepare(int p) async {
    final lines = await page(p);
    final ok = await loadFont(p) && await loadFont(1);
    return (lines, ok);
  }

  /// تحميل مسبق للصفحات اللي جنب الصفحة الحالية — التقليب يبقى فوري
  static void warmAround(int p) {
    for (final x in [p - 1, p + 1, p + 2]) {
      if (x >= 1 && x <= 604) loadFont(x);
    }
  }
}
