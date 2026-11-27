import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arabic.dart';

/// تاريخ هجري بسيط
class HDate {
  final int year, month, day, monthLength;
  const HDate(this.year, this.month, this.day, this.monthLength);
  String get monthName => Hijri.months[month - 1];
  String get label => '${arDigits(day)} $monthName ${arDigits(year)} هـ';
}

/// مناسبة من المناسبات الإسلامية (بالتاريخ الميلادي المقابل)
class Occasion {
  final DateTime date;
  final String title;
  final String hint;

  /// صيام مستحب (عشان التذكير بالليلة اللي قبلها)
  final bool fast;
  const Occasion(this.date, this.title, this.hint, {this.fast = false});
}

/// التقويم الهجري (أم القرى) مع تعديل يوم أو يومين حسب رؤية الهلال في البلد
class Hijri {
  static int offset = 0;
  static const months = [
    'محرّم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة', //
    'رجب', 'شعبان', 'رمضان', 'شوّال', 'ذو القعدة', 'ذو الحجة',
  ];

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    offset = (p.getInt('hijri.offset') ?? 0).clamp(-2, 2);
  }

  static Future<void> setOffset(int v) async {
    offset = v.clamp(-2, 2);
    final p = await SharedPreferences.getInstance();
    await p.setInt('hijri.offset', offset);
  }

  static HDate of(DateTime d) {
    final x = dateOnly(d).add(Duration(days: offset));
    final h = HijriCalendar.fromDate(x);
    return HDate(h.hYear, h.hMonth, h.hDay, h.lengthOfMonth);
  }

  static HDate get today => of(DateTime.now());

  /// تحويل تاريخ هجري لميلادي (مع التعديل)
  static DateTime toGregorian(int y, int m, int d) {
    // ترحيل الشهر لو برّه ١..١٢
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    final g = HijriCalendar().hijriToGregorian(y, m, 1);
    return dateOnly(g).add(Duration(days: d - 1 - offset));
  }

  static int monthLength(int y, int m) {
    final a = toGregorian(y, m, 1), b = toGregorian(y, m + 1, 1);
    return daysBetween(a, b);
  }

  /// المناسبات من النهارده لمدة [days] يوم
  static List<Occasion> upcoming({int days = 400}) {
    final now = dateOnly(DateTime.now());
    final end = now.add(Duration(days: days));
    final h = today;
    final out = <Occasion>[];
    void add(int y, int m, int d, String title, String hint, {bool fast = false}) {
      final g = toGregorian(y, m, d);
      if (!g.isBefore(now) && g.isBefore(end)) out.add(Occasion(g, title, hint, fast: fast));
    }

    for (var y = h.year; y <= h.year + 1; y++) {
      add(y, 1, 1, 'رأس السنة الهجرية ${arDigits(y)}', 'بداية عام هجري جديد');
      add(y, 1, 9, 'تاسوعاء', 'يُستحب صيامه مع عاشوراء', fast: true);
      add(y, 1, 10, 'يوم عاشوراء', 'صيامه يكفّر السنة التي قبله', fast: true);
      add(y, 9, 1, 'أول رمضان', 'رمضان مبارك', fast: true);
      add(y, 9, 21, 'العشر الأواخر من رمضان', 'تحرَّوا ليلة القدر في الوتر من العشر الأواخر');
      add(y, 10, 1, 'عيد الفطر', 'تقبّل الله منا ومنكم');
      add(y, 10, 2, 'صيام ستة من شوال', 'من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر', fast: true);
      add(y, 12, 1, 'العشر الأوائل من ذي الحجة', 'أفضل أيام الدنيا — أكثروا فيها من الذكر والعمل الصالح');
      add(y, 12, 9, 'يوم عرفة', 'صيامه يكفّر السنة الماضية والباقية', fast: true);
      add(y, 12, 10, 'عيد الأضحى', 'تقبّل الله منا ومنكم');
      add(y, 12, 11, 'أيام التشريق', '١١ و١٢ و١٣ ذي الحجة — أيام أكل وشرب وذكر لله');
      for (var m = 1; m <= 12; m++) {
        if (m == 12) continue; // ١٣ ذي الحجة من أيام التشريق
        add(y, m, 13, 'الأيام البيض', 'صيام ١٣ و١٤ و١٥ من ${months[m - 1]}', fast: true);
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// أيام الشهر الهجري اللي ليها علامة (للتقويم)
  static String? markOf(int m, int d) {
    if (m == 9) return 'رمضان';
    if (m == 1 && (d == 9 || d == 10)) return d == 10 ? 'عاشوراء' : 'تاسوعاء';
    if (m == 10 && d == 1) return 'عيد الفطر';
    if (m == 12 && d == 9) return 'عرفة';
    if (m == 12 && d == 10) return 'عيد الأضحى';
    if (m == 12 && d >= 11 && d <= 13) return 'التشريق';
    if (m == 12 && d < 9) return 'العشر';
    if (d >= 13 && d <= 15) return 'البيض';
    return null;
  }
}
