import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arabic.dart';
import 'quran.dart';

/// خطة ختمة: من صفحة لصفحة في عدد أيام، والورد بيتوزّع بالتساوي على الأيام.
class KhatmaPlan {
  final DateTime start; // يوم البداية (من غير ساعة)
  final int days;
  final int fromPage;
  final int toPage;
  const KhatmaPlan({required this.start, required this.days, this.fromPage = 1, this.toPage = Quran.totalPages});

  int get total => toPage - fromPage + 1;

  /// متوسط الورد اليومي (بالصفحات)
  double get perDay => total / days;

  /// آخر يوم في الخطة
  DateTime get endDate => DateTime(start.year, start.month, start.day + days - 1);

  /// اليوم رقم كام في الخطة (يوم البداية = ١)
  int dayOf(DateTime now) => daysBetween(start, now) + 1;

  /// آخر صفحة المفروض توصلها في نهاية اليوم رقم [day]
  int targetEnd(int day) {
    if (day <= 0) return fromPage - 1;
    if (day >= days) return toPage;
    return fromPage - 1 + (total * day / days).round();
  }

  /// ورد يوم معيّن (من صفحة لصفحة) حسب الخطة الأصلية
  ({int from, int to}) portionOfDay(int day) => (from: targetEnd(day - 1) + 1, to: targetEnd(day));

  Map<String, dynamic> toJson() => {'s': dayKey(start), 'd': days, 'f': fromPage, 't': toPage};

  static KhatmaPlan fromJson(Map<String, dynamic> j) {
    final p = (j['s'] as String).split('-').map(int.parse).toList();
    return KhatmaPlan(start: DateTime(p[0], p[1], p[2]), days: j['d'] as int, fromPage: j['f'] as int, toPage: j['t'] as int);
  }
}

/// ختمة خلصت (للسجل)
class KhatmaRecord {
  final DateTime start;
  final DateTime end;
  const KhatmaRecord(this.start, this.end);
  int get days => daysBetween(start, end) + 1;
  Map<String, dynamic> toJson() => {'s': start.toIso8601String(), 'e': end.toIso8601String()};
  factory KhatmaRecord.fromJson(Map<String, dynamic> j) => KhatmaRecord(DateTime.parse(j['s'] as String), DateTime.parse(j['e'] as String));
}

enum KhatmaEvent { dayDone, khatmaDone }

/// حالة الختمة الحالية على الجهاز.
///
/// [cursor] = آخر صفحة متصلة اتقرت من أول الخطة. الصفحات اللي اتقرت قدّام (بعد فجوة) بتتحفظ في [_ahead]
/// ولما الفجوة تتقفل الـ cursor بيتقدّم لوحده.
class KhatmaStore extends ChangeNotifier {
  KhatmaStore._();
  static final KhatmaStore instance = KhatmaStore._();

  late SharedPreferences _p;

  /// الخطة الحالية (لو المستخدم غيّر الموعد، الخطة بتبدأ من جديد من النهارده على الصفحات الباقية)
  KhatmaPlan? plan;

  /// بداية الختمة الأصلية وأول صفحة فيها (للتقدم الكلي والسجل)
  DateTime? startedAt;
  int firstPage = 1;
  int cursor = 0;
  final Set<int> _ahead = {};
  List<KhatmaRecord> history = [];

  /// بيتبعت للواجهة لما ورد اليوم أو الختمة كلها تخلص (عشان الاحتفال)
  final events = ValueNotifier<KhatmaEvent?>(null);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    try {
      final raw = _p.getString('khatma');
      plan = raw == null ? null : KhatmaPlan.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      plan = null;
    }
    cursor = _p.getInt('khatma:cursor') ?? (plan == null ? 0 : plan!.fromPage - 1);
    startedAt = DateTime.tryParse(_p.getString('khatma:startedAt') ?? '') ?? plan?.start;
    firstPage = _p.getInt('khatma:first') ?? plan?.fromPage ?? 1;
    _ahead
      ..clear()
      ..addAll((_p.getStringList('khatma:ahead') ?? const []).map(int.parse));
    try {
      history = (jsonDecode(_p.getString('khatma:history') ?? '[]') as List).map((e) => KhatmaRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      history = [];
    }
  }

  Future<void> _save() async {
    if (plan == null) {
      await _p.remove('khatma');
    } else {
      await _p.setString('khatma', jsonEncode(plan!.toJson()));
    }
    await _p.setInt('khatma:cursor', cursor);
    await _p.setInt('khatma:first', firstPage);
    if (startedAt != null) await _p.setString('khatma:startedAt', startedAt!.toIso8601String());
    await _p.setStringList('khatma:ahead', _ahead.map((e) => '$e').toList());
    await _p.setString('khatma:history', jsonEncode(history.map((h) => h.toJson()).toList()));
    notifyListeners();
  }

  // ───── قراءات محسوبة ─────

  bool get active => plan != null;
  bool get finished => plan != null && cursor >= plan!.toPage;

  /// رقم اليوم الحالي في الخطة
  int get today => plan == null ? 0 : plan!.dayOf(DateTime.now());

  /// آخر صفحة المفروض توصلها النهارده
  int get todayTarget => plan == null ? 0 : plan!.targetEnd(today);

  /// المفروض كنت وصلت فين لحد امبارح
  int get yesterdayTarget => plan == null ? 0 : plan!.targetEnd(today - 1);

  bool get todayDone => plan != null && cursor >= todayTarget;

  /// الصفحات المطلوبة النهارده (ورد اليوم + المتأخر لو فيه)
  int get remainingToday => plan == null ? 0 : math.max(0, todayTarget - cursor);

  /// صفحات متأخرة من الأيام اللي فاتت
  int get behind => plan == null ? 0 : math.max(0, yesterdayTarget - cursor);

  /// الصفحات اللي قريتها زيادة عن المطلوب لحد النهارده
  int get ahead => plan == null ? 0 : math.max(0, cursor - todayTarget);

  /// أول صفحة في ورد النهارده
  int get nextPage => plan == null ? 1 : math.min(cursor + 1, plan!.toPage);

  /// إجمالي صفحات الختمة كلها
  int get totalPages => plan == null ? 0 : plan!.toPage - firstPage + 1;

  double get progress => plan == null ? 0 : (pagesDone / totalPages).clamp(0, 1).toDouble();

  int get pagesDone => plan == null ? 0 : math.max(0, cursor - firstPage + 1);

  /// الأيام الباقية في الخطة (من النهارده)
  int get daysLeft => plan == null ? 0 : math.max(0, plan!.days - today + 1);

  /// ورد اليوم الأصلي حسب الخطة (من غير المتأخر)
  ({int from, int to})? get todayPortion => plan == null || today > plan!.days ? null : plan!.portionOfDay(today);

  // ───── أوامر ─────

  /// بداية ختمة جديدة. [fromPage] > ١ لو المستخدم كان قرأ جزء قبل كده:
  /// الورد بيتوزّع على الصفحات الباقية، والتقدّم الكلي بيتحسب من أول المصحف.
  Future<void> start({required int days, int fromPage = 1, int toPage = Quran.totalPages}) async {
    plan = KhatmaPlan(start: dateOnly(DateTime.now()), days: days.clamp(1, 3650), fromPage: fromPage, toPage: toPage);
    startedAt = DateTime.now();
    firstPage = 1;
    cursor = fromPage - 1;
    _ahead.clear();
    events.value = null;
    await _save();
  }

  /// الصفحة اتقرت (من المصحف بعد ما القارئ يفضل عليها شوية)
  Future<void> markPage(int page) async {
    final p = plan;
    if (p == null || finished || page < p.fromPage || page > p.toPage || page <= cursor) return;
    final wasDayDone = todayDone;
    _ahead.add(page);
    while (_ahead.remove(cursor + 1)) {
      cursor++;
    }
    await _after(wasDayDone);
  }

  /// «خلّصت ورد النهارده» — بيعلّم كل صفحات الورد إنها اتقرت
  Future<void> completeToday() async {
    if (plan == null || todayDone) return;
    final wasDayDone = todayDone;
    cursor = todayTarget;
    _ahead.removeWhere((x) => x <= cursor);
    while (_ahead.remove(cursor + 1)) {
      cursor++;
    }
    await _after(wasDayDone);
  }

  /// تعديل الموضع يدويًا: «أنا خلّصت لحد صفحة كذا»
  Future<void> setReached(int page) async {
    final p = plan;
    if (p == null) return;
    final wasDayDone = todayDone;
    final wasFinished = finished;
    cursor = page.clamp(p.fromPage - 1, p.toPage);
    _ahead.removeWhere((x) => x <= cursor);
    await _after(wasDayDone, wasFinished: wasFinished);
  }

  Future<void> _after(bool wasDayDone, {bool wasFinished = false}) async {
    final p = plan!;
    if (cursor >= p.toPage) {
      if (wasFinished) return _save();
      history.insert(0, KhatmaRecord(startedAt ?? p.start, DateTime.now()));
      events.value = KhatmaEvent.khatmaDone;
    } else if (!wasDayDone && todayDone) {
      events.value = KhatmaEvent.dayDone;
    }
    await _save();
  }

  /// تغيير موعد الختم: الصفحات الباقية بتتوزّع من النهارده على [days] يوم (والتقدم الكلي محفوظ)
  Future<void> rescheduleFromToday(int days) async {
    final p = plan;
    if (p == null || cursor >= p.toPage) return;
    plan = KhatmaPlan(start: dateOnly(DateTime.now()), days: days.clamp(1, 3650), fromPage: cursor + 1, toPage: p.toPage);
    _ahead.removeWhere((x) => x <= cursor);
    events.value = null;
    await _save();
  }

  Future<void> cancel() async {
    plan = null;
    cursor = 0;
    _ahead.clear();
    await _save();
  }

  /// عدد الختمات اللي خلصت
  int get completedCount => history.length;
}
