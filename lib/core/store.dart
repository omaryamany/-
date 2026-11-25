import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arabic.dart';
import 'quran.dart';

/// علامة مرجعية على آية
class Bookmark {
  final int ayah; // رقم الآية العام
  final DateTime at;
  const Bookmark(this.ayah, this.at);
  int get page => Quran.pageOf(ayah);
  Map<String, dynamic> toJson() => {'a': ayah, 't': at.toIso8601String()};
  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(j['a'] as int, DateTime.tryParse((j['t'] ?? '') as String) ?? DateTime.now());
}

/// كل اللي التطبيق بيفتكره على الجهاز (من غير حسابات ولا سيرفر):
/// آخر مكان، العلامات، شكل المصحف، القارئ، وسجل القراءة اليومي.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  late SharedPreferences _p;

  // ───── عام ─────
  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;

  // ───── القراءة ─────
  int lastPage = 1;
  int? lastAyah;
  DateTime? lastAt;
  List<Bookmark> bookmarks = [];

  /// 'paper' ورق، 'sepia' بيج، 'night' ليلي، 'auto' حسب ثيم التطبيق
  String mushafTheme = 'auto';
  double fontScale = 1.0;
  bool keepAwake = true;
  String reciter = Quran.reciters.first.id;

  /// اليوم (yyyy-mm-dd) → الصفحات اللي اتقرت فيه (آخر ٩٠ يوم)
  Map<String, Set<int>> readLog = {};

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(_p.getInt('themeMode') ?? 0).clamp(0, 2)];
    onboarded = _p.getBool('onboarded') ?? false;
    lastPage = (_p.getInt('lastPage') ?? 1).clamp(1, Quran.totalPages);
    lastAyah = _p.getInt('lastAyah');
    lastAt = DateTime.tryParse(_p.getString('lastAt') ?? '');
    mushafTheme = _p.getString('mushafTheme') ?? 'auto';
    fontScale = _p.getDouble('fontScale') ?? 1.0;
    keepAwake = _p.getBool('keepAwake') ?? true;
    final r = _p.getString('reciter');
    reciter = Quran.reciters.any((x) => x.id == r) ? r! : Quran.reciters.first.id;
    try {
      bookmarks = (jsonDecode(_p.getString('bookmarks') ?? '[]') as List).map((e) => Bookmark.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      bookmarks = [];
    }
    try {
      final m = jsonDecode(_p.getString('readLog') ?? '{}') as Map;
      readLog = m.map((k, v) => MapEntry(k.toString(), (v as List).cast<int>().toSet()));
    } catch (_) {
      readLog = {};
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _p.setInt('themeMode', m.index);
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    await _p.setBool('onboarded', true);
    notifyListeners();
  }

  // ───── الموضع والعلامات ─────

  bool get hasHistory => lastAt != null;

  Future<void> savePosition(int page, {int? ayah}) async {
    lastPage = page;
    if (ayah != null) lastAyah = ayah;
    lastAt = DateTime.now();
    await _p.setInt('lastPage', page);
    if (ayah != null) await _p.setInt('lastAyah', ayah);
    await _p.setString('lastAt', lastAt!.toIso8601String());
    notifyListeners();
  }

  bool isBookmarked(int ayah) => bookmarks.any((b) => b.ayah == ayah);
  bool pageHasBookmark(int page) => bookmarks.any((b) => b.page == page);

  Future<void> toggleBookmark(int ayah) async {
    if (isBookmarked(ayah)) {
      bookmarks.removeWhere((b) => b.ayah == ayah);
    } else {
      bookmarks.insert(0, Bookmark(ayah, DateTime.now()));
    }
    await _p.setString('bookmarks', jsonEncode(bookmarks.map((b) => b.toJson()).toList()));
    notifyListeners();
  }

  // ───── شكل المصحف ─────

  Future<void> setMushafTheme(String t) async {
    mushafTheme = t;
    await _p.setString('mushafTheme', t);
    notifyListeners();
  }

  Future<void> setScale(double v) async {
    fontScale = v.clamp(1.0, 1.6);
    await _p.setDouble('fontScale', fontScale);
    notifyListeners();
  }

  Future<void> setKeepAwake(bool v) async {
    keepAwake = v;
    await _p.setBool('keepAwake', v);
    notifyListeners();
  }

  Future<void> setReciter(String id) async {
    reciter = id;
    await _p.setString('reciter', id);
    notifyListeners();
  }

  // ───── سجل القراءة ─────

  int get todayPages => readLog[dayKey(DateTime.now())]?.length ?? 0;

  int get totalDaysRead => readLog.values.where((s) => s.isNotEmpty).length;

  /// أيام متتالية فيها قراءة (لحد النهارده، أو امبارح لو النهارده لسه ماقريتش)
  int get streak {
    var d = DateTime.now();
    if ((readLog[dayKey(d)]?.length ?? 0) == 0) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while ((readLog[dayKey(d)]?.length ?? 0) > 0) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// عدد الصفحات في آخر ٧ أيام (الأقدم الأول) — للرسم البياني الصغير
  List<int> get lastWeek {
    final now = DateTime.now();
    return [for (var i = 6; i >= 0; i--) readLog[dayKey(now.subtract(Duration(days: i)))]?.length ?? 0];
  }

  /// الصفحة اتقرت (القارئ فضل عليها كام ثانية) — بترجع true لو أول مرة النهارده
  Future<bool> logRead(int page) async {
    final set = readLog.putIfAbsent(dayKey(DateTime.now()), () => <int>{});
    if (!set.add(page)) return false;
    if (readLog.length > 90) {
      final keys = readLog.keys.toList()..sort();
      for (final old in keys.take(readLog.length - 90)) {
        readLog.remove(old);
      }
    }
    await _p.setString('readLog', jsonEncode(readLog.map((k, v) => MapEntry(k, v.toList()))));
    notifyListeners();
    return true;
  }
}
