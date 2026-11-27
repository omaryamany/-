import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'arabic.dart';

/// بيانات المصحف كلها محلية جوه التطبيق (نص Tanzil العثماني + حدود صفحات مصحف المدينة).
/// الآيات مترقّمة ترقيم عام من ١ لـ ٦٢٣٦.
class Surah {
  final int number;
  final String name;
  final String nameLatin;
  final int ayahCount;
  final bool meccan;
  final int start;
  const Surah(this.number, this.name, this.nameLatin, this.ayahCount, this.meccan, this.start);
  int get end => start + ayahCount - 1;
  int get page => Quran.pageOf(start);
}

class Juz {
  final int number;
  final int start;
  final int end;
  const Juz(this.number, this.start, this.end);
  int get page => Quran.pageOf(start);
}

class AyahRange {
  final int start;
  final int end;
  const AyahRange(this.start, this.end);
}

class PageAyah {
  final int global;
  final int surah;
  final int ayah;
  final String text;
  const PageAyah(this.global, this.surah, this.ayah, this.text);
}

class Reciter {
  final String id;
  final String name;
  const Reciter(this.id, this.name);
}

class Quran {
  static const totalAyat = 6236;
  static const totalPages = 604;
  static const basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  /// التلاوات من everyayah.com (آية بآية) — بتتحفظ على الجهاز أول ما تتسمع.
  /// أسماء الفولدرات متراجعة على صفحة everyayah.com/recitations_ayat.html (كلها كاملة من غير ملفات ناقصة).
  static const reciters = [
    Reciter('Husary_128kbps', 'محمود خليل الحصري'),
    Reciter('Husary_128kbps_Mujawwad', 'الحصري (مجوّد)'),
    Reciter('Husary_Muallim_128kbps', 'الحصري (المصحف المعلّم)'),
    Reciter('Minshawy_Murattal_128kbps', 'محمد صديق المنشاوي'),
    Reciter('Minshawy_Mujawwad_192kbps', 'المنشاوي (مجوّد)'),
    Reciter('Abdul_Basit_Murattal_192kbps', 'عبد الباسط عبد الصمد'),
    Reciter('Abdul_Basit_Mujawwad_128kbps', 'عبد الباسط (مجوّد)'),
    Reciter('Mohammad_al_Tablaway_128kbps', 'محمد محمود الطبلاوي'),
    Reciter('mahmoud_ali_al_banna_32kbps', 'محمود علي البنا'),
    Reciter('Alafasy_128kbps', 'مشاري راشد العفاسي'),
    Reciter('MaherAlMuaiqly128kbps', 'ماهر المعيقلي'),
    Reciter('Abdurrahmaan_As-Sudais_192kbps', 'عبد الرحمن السديس'),
    Reciter('Saood_ash-Shuraym_128kbps', 'سعود الشريم'),
    Reciter('Yasser_Ad-Dussary_128kbps', 'ياسر الدوسري'),
    Reciter('Ahmed_ibn_Ali_al-Ajamy_128kbps_ketaballah.net', 'أحمد بن علي العجمي'),
    Reciter('Abu_Bakr_Ash-Shaatree_128kbps', 'أبو بكر الشاطري'),
    Reciter('Hudhaify_128kbps', 'علي الحذيفي'),
    Reciter('Ghamadi_40kbps', 'سعد الغامدي'),
    Reciter('Nasser_Alqatami_128kbps', 'ناصر القطامي'),
    Reciter('Hani_Rifai_192kbps', 'هاني الرفاعي'),
    Reciter('Muhammad_Ayyoub_128kbps', 'محمد أيوب'),
    Reciter('Muhammad_Jibreel_128kbps', 'محمد جبريل'),
    Reciter('Abdullah_Basfar_192kbps', 'عبد الله بصفر'),
    Reciter('Salah_Al_Budair_128kbps', 'صلاح البدير'),
    Reciter('Ali_Jaber_64kbps', 'علي جابر'),
    Reciter('Fares_Abbad_64kbps', 'فارس عباد'),
    Reciter('Khaalid_Abdullaah_al-Qahtaanee_192kbps', 'خالد القحطاني'),
  ];

  static Reciter reciter(String id) => reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

  static late final List<Surah> surahs;
  static late final List<Juz> juz;
  static late final List<int> pageStarts;
  static final Map<int, List<String>> _text = {};
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    final s = jsonDecode(await rootBundle.loadString('assets/quran/surahs.json')) as List;
    surahs = s
        .map((e) => Surah(e['number'] as int, e['name'] as String, (e['nameLatin'] ?? '') as String, e['ayahCount'] as int,
            e['type'] == 'meccan', e['start'] as int))
        .toList();
    final j = jsonDecode(await rootBundle.loadString('assets/quran/juz.json')) as List;
    juz = j.map((e) => Juz(e['number'] as int, e['start'] as int, e['end'] as int)).toList();
    pageStarts = (jsonDecode(await rootBundle.loadString('assets/quran/pages.json')) as List).cast<int>();
    _ready = true;
  }

  static Surah surah(int n) => surahs[n - 1];

  static int toGlobal(int surah, int ayah) => Quran.surah(surah).start + ayah - 1;

  static ({int surah, int ayah}) fromGlobal(int g) {
    var lo = 0, hi = surahs.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (surahs[mid].start <= g) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return (surah: surahs[lo].number, ayah: g - surahs[lo].start + 1);
  }

  /// «البقرة ٢٥٥»
  static String formatAyah(int g) {
    final p = fromGlobal(g);
    return '${surah(p.surah).name} ${arDigits(p.ayah)}';
  }

  static int juzOf(int g) => juz.lastWhere((j) => j.start <= g).number;

  static int juzOfPage(int page) => juzOf(pageStarts[page - 1]);

  /// رقم الصفحة اللي فيها الآية
  static int pageOf(int g) {
    var lo = 0, hi = pageStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (pageStarts[mid] <= g) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  static AyahRange pageRange(int page) {
    final start = pageStarts[page - 1];
    final end = page == totalPages ? totalAyat : pageStarts[page] - 1;
    return AyahRange(start, end);
  }

  /// اسم السورة اللي الصفحة بتبدأ بيها (للترويسة والإشعارات)
  static Surah surahOfPage(int page) => surah(fromGlobal(pageStarts[page - 1]).surah);

  /// «من البقرة ١٤٢ إلى البقرة ١٧٦» لمدى صفحات
  static String pagesSpan(int from, int to) {
    final a = pageRange(from).start;
    final b = pageRange(to).end;
    return 'من ${formatAyah(a)} إلى ${formatAyah(b)}';
  }

  static Future<List<String>> surahAyat(int n) async {
    final cached = _text[n];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/quran/text/${n.toString().padLeft(3, '0')}.json');
    final ayat = ((jsonDecode(raw) as Map)['ayat'] as List).cast<String>();
    _text[n] = ayat;
    return ayat;
  }

  static Future<String> ayahText(int g) async {
    final p = fromGlobal(g);
    return (await surahAyat(p.surah))[p.ayah - 1];
  }

  /// آيات صفحة (للعرض الاحتياطي لو خط الصفحة ماتحمّلش) — البسملة بتتعرض كعنوان
  static Future<List<PageAyah>> loadPage(int page) async {
    final r = pageRange(page);
    final out = <PageAyah>[];
    for (var g = r.start; g <= r.end; g++) {
      final p = fromGlobal(g);
      var t = (await surahAyat(p.surah))[p.ayah - 1];
      if (p.ayah == 1 && p.surah != 1 && p.surah != 9) {
        // نص Tanzil بيبدأ أول آية في كل سورة بالبسملة (٤ كلمات) — بتتشال وتتعرض كعنوان
        final parts = t.split(' ');
        if (parts.length > 4 && parts[0].endsWith('سْمِ')) t = parts.skip(4).join(' ');
      }
      out.add(PageAyah(g, p.surah, p.ayah, t));
    }
    return out;
  }

  static String audioUrl(int surah, int ayah, String reciter) {
    String pad(int x) => x.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciter/${pad(surah)}${pad(ayah)}.mp3';
  }
}

/// بحث في القرآن كله من غير نت ومن غير تشكيل (الفهرس بيتبني مرة واحدة)
class QuranSearch {
  static List<(int, String, String)>? _index;

  static Future<void> _build() async {
    if (_index != null) return;
    final out = <(int, String, String)>[];
    for (final s in Quran.surahs) {
      final ayat = await Quran.surahAyat(s.number);
      for (var a = 1; a <= ayat.length; a++) {
        final t = ayat[a - 1];
        out.add((s.start + a - 1, t, normalizeArabic(t)));
      }
    }
    _index = out;
  }

  static Future<List<(int, String)>> search(String q, {int limit = 200}) async {
    final n = normalizeArabic(q);
    if (n.length < 2) return [];
    await _build();
    final res = <(int, String)>[];
    for (final (g, t, norm) in _index!) {
      if (norm.contains(n)) {
        res.add((g, t));
        if (res.length >= limit) break;
      }
    }
    return res;
  }
}

/// التفسير الميسّر (مجمع الملك فهد) — ملف لكل سورة، بيتحمّل وقت الحاجة
enum TafsirKind { muyassar, saadi, ibnKathir }

/// تفسير آية (أو مجموعة آيات اتفسّرت مع بعض): النص ومن آية لآية
class TafsirEntry {
  final String text;
  final int from, to; // أرقام الآيات داخل السورة
  const TafsirEntry(this.text, this.from, this.to);
}

/// التفاسير: الميسّر والسعدي جوه التطبيق (من غير نت)، وابن كثير بيتحمّل سورة سورة أول مرة ويتحفظ
class Tafsir {
  static final Map<String, List<String>> _cache = {};

  static String name(TafsirKind k) => switch (k) {
        TafsirKind.muyassar => 'الميسّر',
        TafsirKind.saadi => 'السعدي',
        TafsirKind.ibnKathir => 'ابن كثير',
      };

  static String source(TafsirKind k) => switch (k) {
        TafsirKind.muyassar => 'التفسير الميسّر — مجمع الملك فهد لطباعة المصحف الشريف',
        TafsirKind.saadi => 'تيسير الكريم الرحمن في تفسير كلام المنان — عبد الرحمن بن ناصر السعدي',
        TafsirKind.ibnKathir => 'تفسير القرآن العظيم — الحافظ ابن كثير',
      };

  static bool online(TafsirKind k) => k == TafsirKind.ibnKathir;

  /// التفسير الميسّر للآية (للاستخدامات القديمة)
  static Future<String> of(int g) async => (await entry(g, TafsirKind.muyassar)).text;

  static Future<TafsirEntry> entry(int g, TafsirKind k) async {
    final p = Quran.fromGlobal(g);
    final list = await _surah(p.surah, k);
    final i = p.ayah - 1;
    if (i >= list.length) return TafsirEntry('', p.ayah, p.ayah);
    // بداية المجموعة: أقرب آية قبلها ليها نص مختلف
    var from = i;
    while (from > 0 && (list[from].isEmpty || list[from] == list[from - 1])) {
      from--;
    }
    var to = i;
    while (to + 1 < list.length && (list[to + 1].isEmpty || list[to + 1] == list[from])) {
      to++;
    }
    return TafsirEntry(list[from], from + 1, to + 1);
  }

  static String _file(int s) => s.toString().padLeft(3, '0');

  static Future<List<String>> _surah(int s, TafsirKind k) async {
    final key = '${k.name}:$s';
    final hit = _cache[key];
    if (hit != null) return hit;
    late List<String> list;
    switch (k) {
      case TafsirKind.muyassar:
        list = ((jsonDecode(await rootBundle.loadString('assets/quran/tafsir/${_file(s)}.json')) as Map)['ayat'] as List).cast<String>();
      case TafsirKind.saadi:
        list = ((jsonDecode(await rootBundle.loadString('assets/quran/tafsir_saadi/${_file(s)}.json')) as Map)['ayat'] as List).cast<String>();
      case TafsirKind.ibnKathir:
        list = await _ibnKathir(s);
    }
    return _cache[key] = list;
  }

  static Future<File> _ikFile(int s) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/tafsir_ibn_kathir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/${_file(s)}.json');
  }

  static Future<bool> ibnKathirReady(int s) async => (await _ikFile(s)).exists();

  static Future<List<String>> _ibnKathir(int s) async {
    final f = await _ikFile(s);
    if (await f.exists()) {
      return (jsonDecode(await f.readAsString()) as List).cast<String>();
    }
    Object? err;
    for (final base in [
      'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/ar-tafsir-ibn-kathir',
      'https://raw.githubusercontent.com/spa5k/tafsir_api/main/tafsir/ar-tafsir-ibn-kathir',
    ]) {
      try {
        final r = await http.get(Uri.parse('$base/$s.json')).timeout(const Duration(seconds: 40));
        if (r.statusCode != 200) continue;
        final raw = (jsonDecode(utf8.decode(r.bodyBytes)) as List).cast<Map>();
        final n = Quran.surah(s).ayahCount;
        final out = List<String>.filled(n, '');
        for (final x in raw) {
          final a = (x['ayah'] as num).toInt();
          if (a >= 1 && a <= n) out[a - 1] = _cleanIk(x['text'] as String? ?? '');
        }
        await f.writeAsString(jsonEncode(out));
        return out;
      } catch (e) {
        err = e;
      }
    }
    throw Exception('تعذّر تحميل تفسير ابن كثير: $err');
  }

  /// شيل حواشي فروق النسخ [[...]] والمسافات الزايدة
  static String _cleanIk(String t) => t
      .replaceAll(RegExp(r'\[\[[^\]]*\]\]'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// أرباع الأحزاب (٢٤٠ ربع) وآيات السجدة
class Hizb {
  static late final List<int> quarters;
  static late final Set<int> sajdas;

  static Future<void> init() async {
    quarters = (jsonDecode(await rootBundle.loadString('assets/quran/quarters.json')) as List).cast<int>();
    sajdas = (jsonDecode(await rootBundle.loadString('assets/quran/sajdas.json')) as List).cast<int>().toSet();
  }

  /// رقم الربع (٠..٢٣٩) اللي فيه الآية
  static int quarterOf(int g) {
    var lo = 0, hi = quarters.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (quarters[mid] <= g) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// «الحزب ٥» أو «¼ الحزب ٥» / «½» / «¾»
  static String label(int quarter) {
    final h = quarter ~/ 4 + 1;
    const parts = ['', '¼ ', '½ ', '¾ '];
    return '${parts[quarter % 4]}الحزب ${arDigits(h)}';
  }

  /// ربع بيبدأ في الصفحة دي؟ (للعلامة في ترويسة المصحف)
  static int? quarterStartingOn(int page) {
    final r = Quran.pageRange(page);
    for (var q = 0; q < quarters.length; q++) {
      if (quarters[q] >= r.start && quarters[q] <= r.end) return q;
    }
    return null;
  }

  static bool pageHasSajda(int page) {
    final r = Quran.pageRange(page);
    return sajdas.any((g) => g >= r.start && g <= r.end);
  }
}
