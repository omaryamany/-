import 'dart:math' as math;

/// حساب مواقيت الصلاة فلكيًا على الجهاز (من غير نت) — نفس خوارزمية PrayTimes.org.
/// اتراجعت على جدول الهيئة المصرية العامة للمساحة للقاهرة (فرق دقيقة بالكتير).
class CalcMethod {
  final String id;
  final String name;
  final double fajr;

  /// زاوية العشاء، أو null لو العشاء بعد المغرب بعدد دقائق ثابت ([ishaMinutes])
  final double? isha;
  final int ishaMinutes;
  const CalcMethod(this.id, this.name, this.fajr, this.isha, [this.ishaMinutes = 0]);

  static const all = [
    CalcMethod('egypt', 'الهيئة المصرية العامة للمساحة', 19.5, 17.5),
    CalcMethod('makkah', 'أم القرى (مكة المكرمة)', 18.5, null, 90),
    CalcMethod('mwl', 'رابطة العالم الإسلامي', 18, 17),
    CalcMethod('karachi', 'جامعة العلوم الإسلامية بكراتشي', 18, 18),
    CalcMethod('isna', 'أمريكا الشمالية (ISNA)', 15, 15),
  ];

  static CalcMethod byId(String id) => all.firstWhere((m) => m.id == id, orElse: () => all.first);
}

enum Prayer { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerName on Prayer {
  String get ar => switch (this) {
        Prayer.fajr => 'الفجر',
        Prayer.sunrise => 'الشروق',
        Prayer.dhuhr => 'الظهر',
        Prayer.asr => 'العصر',
        Prayer.maghrib => 'المغرب',
        Prayer.isha => 'العشاء',
      };

  /// الظهر يوم الجمعة = الجمعة
  String arOn(DateTime day) => this == Prayer.dhuhr && day.weekday == DateTime.friday ? 'الجمعة' : ar;
}

/// مواقيت يوم واحد (بتوقيت الجهاز)
class PrayerDay {
  final DateTime date;
  final Map<Prayer, DateTime> times;
  const PrayerDay(this.date, this.times);
  DateTime operator [](Prayer p) => times[p]!;
}

class PrayerCalc {
  static double _d2r(double d) => d * math.pi / 180;
  static double _r2d(double r) => r * 180 / math.pi;
  static double _sin(double d) => math.sin(_d2r(d));
  static double _cos(double d) => math.cos(_d2r(d));
  static double _tan(double d) => math.tan(_d2r(d));
  static double _asin(double x) => _r2d(math.asin(x.clamp(-1.0, 1.0)));
  static double _acos(double x) => _r2d(math.acos(x.clamp(-1.0, 1.0)));
  static double _atan2(double y, double x) => _r2d(math.atan2(y, x));
  static double _acot(double x) => _r2d(math.atan(1 / x));

  static double _fix(double a, double b) {
    a = a - b * (a / b).floorToDouble();
    return a < 0 ? a + b : a;
  }

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + a ~/ 4;
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (m + 1)).floorToDouble() + d + b - 1524.5;
  }

  /// (الميل، معادلة الزمن)
  static (double, double) _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_atan2(_cos(e) * _sin(l), _cos(l)) / 15, 24);
    final eqt = q / 15 - ra;
    final decl = _asin(_sin(e) * _sin(l));
    return (decl, eqt);
  }

  /// مواقيت يوم [date] للمكان (lat, lng). [asrFactor] = ١ (الجمهور) أو ٢ (الحنفي).
  /// [adjust] دقائق إضافية لكل صلاة (ضبط يدوي).
  static PrayerDay compute(DateTime date, double lat, double lng, CalcMethod method, {int asrFactor = 1, Map<Prayer, int> adjust = const {}}) {
    final jd = _julian(date.year, date.month, date.day) - lng / (15 * 24);

    double mid(double t) => _fix(12 - _sun(jd + t).$2, 24);
    double angleTime(double angle, double t, bool before) {
      final decl = _sun(jd + t).$1;
      final noon = mid(t);
      final x = _acos((-_sin(angle) - _sin(decl) * _sin(lat)) / (_cos(decl) * _cos(lat))) / 15;
      return before ? noon - x : noon + x;
    }

    double asr(double t) {
      final decl = _sun(jd + t).$1;
      final angle = -_acot(asrFactor + _tan((lat - decl).abs()));
      return angleTime(angle, t, false);
    }

    // تقريب أولي ثم تحسين مرتين
    var t = <Prayer, double>{Prayer.fajr: 5, Prayer.sunrise: 6, Prayer.dhuhr: 12, Prayer.asr: 13, Prayer.maghrib: 18, Prayer.isha: 18};
    for (var i = 0; i < 2; i++) {
      final p = t.map((k, v) => MapEntry(k, v / 24));
      t = {
        Prayer.fajr: angleTime(method.fajr, p[Prayer.fajr]!, true),
        Prayer.sunrise: angleTime(0.833, p[Prayer.sunrise]!, true),
        Prayer.dhuhr: mid(p[Prayer.dhuhr]!),
        Prayer.asr: asr(p[Prayer.asr]!),
        Prayer.maghrib: angleTime(0.833, p[Prayer.maghrib]!, false),
        Prayer.isha: method.isha != null ? angleTime(method.isha!, p[Prayer.isha]!, false) : 0,
      };
    }
    if (method.isha == null) t[Prayer.isha] = t[Prayer.maghrib]! + method.ishaMinutes / 60;

    final base = DateTime.utc(date.year, date.month, date.day);
    final out = <Prayer, DateTime>{};
    for (final e in t.entries) {
      final utcHours = e.value - lng / 15;
      final minutes = (utcHours * 60).round() + (adjust[e.key] ?? 0);
      out[e.key] = base.add(Duration(minutes: minutes)).toLocal();
    }
    return PrayerDay(DateTime(date.year, date.month, date.day), out);
  }

  // ───── القبلة ─────
  static const kaabaLat = 21.4225, kaabaLng = 39.8262;

  /// اتجاه القبلة بالدرجات من الشمال الحقيقي (مع عقارب الساعة)
  static double qibla(double lat, double lng) {
    final dl = _d2r(kaabaLng - lng);
    final y = math.sin(dl);
    final x = math.cos(_d2r(lat)) * math.tan(_d2r(kaabaLat)) - math.sin(_d2r(lat)) * math.cos(dl);
    return _fix(_r2d(math.atan2(y, x)), 360);
  }

  /// المسافة إلى الكعبة بالكيلومتر
  static double distanceToKaaba(double lat, double lng) => distanceKm(lat, lng, kaabaLat, kaabaLng);

  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    final dLat = _d2r(lat2 - lat1), dLng = _d2r(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) + math.cos(_d2r(lat1)) * math.cos(_d2r(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
