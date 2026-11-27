import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'core/hijri.dart';
import 'core/khatma.dart';
import 'core/prayer.dart';
import 'core/quran.dart';
import 'core/reminders.dart';
import 'core/seasonal.dart';
import 'core/store.dart';
import 'core/widget_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // التلاوة بتكمّل في الخلفية والشاشة مقفولة، مع أزرار تحكم في الإشعار
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.murattil.quran.audio',
    androidNotificationChannelName: 'تلاوة القرآن',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_murattil',
  );
  await Quran.init();
  await Hizb.init();
  await AppStore.instance.load();
  await KhatmaStore.instance.load();
  await Reminders.instance.init();
  await Hijri.load();
  await PrayerStore.instance.load();
  runApp(const MurattilApp());
  // بعد ما الواجهة تفتح: تذكيرات المواسم وبيانات الويدجت
  unawaited(Seasonal.reschedule());
  unawaited(HomeWidgetSync.update());
}
