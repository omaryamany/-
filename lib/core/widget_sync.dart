import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'arabic.dart';
import 'hijri.dart';
import 'khatma.dart';
import 'prayer.dart';
import 'prayer_calc.dart';
import 'quran.dart';

/// بيانات ويدجت الشاشة الرئيسية (الصلاة القادمة + مواقيت اليوم + الورد) — الويدجت نفسه مكتوب بأندرويد
class HomeWidgetSync {
  static const _ch = MethodChannel('murattil/adhan');

  static Future<void> update() async {
    try {
      final ps = PrayerStore.instance;
      final times = <Map<String, Object>>[];
      if (ps.configured) {
        final today = dateOnly(DateTime.now());
        for (var k = 0; k < 8; k++) {
          final d = today.add(Duration(days: k));
          final day = ps.day(d);
          for (final p in PrayerStore.prayers5) {
            final at = day[p];
            times.add({'at': at.millisecondsSinceEpoch, 'name': p.arOn(d), 'time': timeLabel(at.hour, at.minute)});
          }
        }
      }
      final k = KhatmaStore.instance;
      String wird;
      if (!k.active) {
        wird = 'ابدأ ختمتك من التطبيق';
      } else if (k.finished) {
        wird = 'أتممت الختمة — تقبّل الله';
      } else if (k.todayDone) {
        wird = 'ورد اليوم تمّ ✓  ·  الختمة ${arDigits((k.progress * 100).round())}٪';
      } else {
        final s = Quran.surahOfPage(k.nextPage).name;
        wird = 'ورد اليوم: ${pagesLabel(k.remainingToday)} — من سورة $s ص ${arDigits(k.nextPage)}';
      }
      await _ch.invokeMethod('widget', {
        'json': jsonEncode({'times': times, 'wird': wird, 'place': ps.configured ? ps.place : '', 'hijri': Hijri.today.label}),
      });
    } catch (e) {
      debugPrint('widget: $e');
    }
  }
}
