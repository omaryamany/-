import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'arabic.dart';
import 'cities.dart';
import 'prayer_calc.dart';
import 'reminders.dart';

/// إعدادات وحالة مواقيت الصلاة: الموقع، طريقة الحساب، الأذان، والتنبيه قبله.
class PrayerStore extends ChangeNotifier {
  PrayerStore._();
  static final PrayerStore instance = PrayerStore._();

  static const prayers5 = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  late SharedPreferences _p;
  double? lat;
  double? lng;
  String place = '';
  String methodId = 'egypt';
  bool hanafi = false;
  Map<Prayer, int> adjust = {};

  /// الأذان شغال لأي صلاة
  Set<Prayer> adhan = {...prayers5};

  /// تنبيه قبل الأذان بكام دقيقة (٠ = متوقف)
  int preMinutes = 0;

  Timer? _tick;

  bool get configured => lat != null && lng != null;
  CalcMethod get method => CalcMethod.byId(methodId);

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lat = _p.getDouble('pr:lat');
    lng = _p.getDouble('pr:lng');
    place = _p.getString('pr:place') ?? '';
    methodId = _p.getString('pr:method') ?? 'egypt';
    hanafi = _p.getBool('pr:hanafi') ?? false;
    preMinutes = _p.getInt('pr:pre') ?? 0;
    try {
      final a = jsonDecode(_p.getString('pr:adjust') ?? '{}') as Map;
      adjust = {for (final e in a.entries) Prayer.values.byName(e.key as String): e.value as int};
    } catch (_) {
      adjust = {};
    }
    final saved = _p.getStringList('pr:adhan');
    if (saved != null) adhan = saved.map(Prayer.values.byName).toSet();
    // الشاشة بتتحدّث كل دقيقة (العدّ التنازلي للصلاة الجاية)
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => notifyListeners());
    if (configured) unawaited(reschedule());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    if (lat != null) await _p.setDouble('pr:lat', lat!);
    if (lng != null) await _p.setDouble('pr:lng', lng!);
    await _p.setString('pr:place', place);
    await _p.setString('pr:method', methodId);
    await _p.setBool('pr:hanafi', hanafi);
    await _p.setInt('pr:pre', preMinutes);
    await _p.setString('pr:adjust', jsonEncode(adjust.map((k, v) => MapEntry(k.name, v))));
    await _p.setStringList('pr:adhan', adhan.map((e) => e.name).toList());
    notifyListeners();
    await reschedule();
  }

  // ───── المواقيت ─────

  PrayerDay day(DateTime d) => PrayerCalc.compute(d, lat!, lng!, method, asrFactor: hanafi ? 2 : 1, adjust: adjust);

  PrayerDay get today => day(DateTime.now());

  /// الصلاة الجاية (من غير الشروق) ووقتها
  ({Prayer prayer, DateTime at})? get next {
    if (!configured) return null;
    final now = DateTime.now();
    for (final d in [today, day(DateTime.now().add(const Duration(days: 1)))]) {
      for (final p in prayers5) {
        if (d[p].isAfter(now)) return (prayer: p, at: d[p]);
      }
    }
    return null;
  }

  /// الصلاة الحالية (آخر صلاة دخل وقتها)
  Prayer? get current {
    if (!configured) return null;
    final now = DateTime.now();
    Prayer? c;
    for (final p in prayers5) {
      if (!today[p].isAfter(now)) c = p;
    }
    return c;
  }

  double get qibla => PrayerCalc.qibla(lat!, lng!);

  // ───── الموقع ─────

  Future<void> setCity(City c) async {
    lat = c.lat;
    lng = c.lng;
    place = c.name;
    methodId = c.method;
    await _save();
  }

  /// تحديد الموقع بالـ GPS. بترجع رسالة خطأ لو فشل، أو null لو نجح.
  Future<String?> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return 'شغّل خدمة الموقع (GPS) في الهاتف ثم حاول مرة أخرى';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return 'لم يُسمح بالوصول للموقع — يمكنك اختيار مدينتك من القائمة';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
      );
      lat = pos.latitude;
      lng = pos.longitude;
      // أقرب مدينة من القائمة (للاسم وطريقة الحساب)
      City? near;
      var best = double.infinity;
      for (final c in cities) {
        final dist = PrayerCalc.distanceKm(lat!, lng!, c.lat, c.lng);
        if (dist < best) {
          best = dist;
          near = c;
        }
      }
      if (near != null && best < 40) {
        place = 'قرب ${near.name}';
        methodId = near.method;
      } else {
        place = 'موقعي الحالي';
        if (near != null && best < 400) methodId = near.method;
      }
      await _save();
      return null;
    } catch (e) {
      debugPrint('locate: $e');
      return 'تعذّر تحديد الموقع — اختر مدينتك من القائمة';
    }
  }

  // ───── الإعدادات ─────

  Future<void> setMethod(String id) async {
    methodId = id;
    await _save();
  }

  Future<void> setHanafi(bool v) async {
    hanafi = v;
    await _save();
  }

  Future<void> setAdjust(Prayer p, int minutes) async {
    adjust = {...adjust, p: minutes.clamp(-30, 30)};
    await _save();
  }

  /// تشغيل/إيقاف أذان صلاة — بترجع false لو المستخدم رفض الإشعارات
  Future<bool> toggleAdhan(Prayer p, bool on) async {
    if (on && !await Reminders.instance.askPermission()) return false;
    adhan = on ? {...adhan, p} : ({...adhan}..remove(p));
    await _save();
    return true;
  }

  Future<void> setPre(int minutes) async {
    preMinutes = minutes;
    await _save();
  }

  /// جدولة إشعارات أسبوع قدّام (بتتعاد مع كل فتحة للتطبيق ومع أي تغيير)
  Future<void> reschedule() async {
    if (!configured) return;
    final items = <(DateTime, String, String, bool)>[];
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final d = day(DateTime(now.year, now.month, now.day + i));
      for (final p in prayers5) {
        if (!adhan.contains(p)) continue;
        final name = p.arOn(d.date);
        items.add((d[p], 'حان الآن موعد صلاة $name', place.isEmpty ? 'حيّ على الصلاة' : 'حسب توقيت $place', false));
        if (preMinutes > 0) {
          items.add((d[p].subtract(Duration(minutes: preMinutes)), 'صلاة $name بعد ${minutesLabel(preMinutes)}', 'استعد للصلاة', true));
        }
      }
    }
    await Reminders.instance.schedulePrayers(items);
  }
}
