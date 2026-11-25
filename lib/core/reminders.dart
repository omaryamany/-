import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'adhan_sounds.dart';

/// التذكيرات المحلية (من غير سيرفر): ورد يومي في ميعاد يختاره المستخدم، وتذكير سورة الكهف يوم الجمعة.
class Reminders extends ChangeNotifier {
  Reminders._();
  static final Reminders instance = Reminders._();

  static const _wirdId = 1;
  static const _kahfId = 2;

  final _n = FlutterLocalNotificationsPlugin();
  late SharedPreferences _p;

  bool wirdOn = false;
  int hour = 20;
  int minute = 0;
  bool kahfOn = false;

  // أذكار الصباح والمساء
  bool morningOn = false;
  int morningH = 7, morningM = 0;
  bool eveningOn = false;
  int eveningH = 17, eveningM = 0;

  /// تذكير بالذكر كل كام ساعة (٠ = متوقف) من ٨ الصبح لـ ١٠ بالليل
  int dhikrEvery = 0;

  /// تذكير صيام الاثنين والخميس (الليلة اللي قبلها)
  bool fastingOn = false;

  /// الإشعار اللي المستخدم ضغط عليه ('wird' أو 'kahf') — الواجهة بتفتح المكان المناسب
  final tapped = ValueNotifier<String?>(null);

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    wirdOn = _p.getBool('rem:wird') ?? false;
    hour = _p.getInt('rem:hour') ?? 20;
    minute = _p.getInt('rem:minute') ?? 0;
    kahfOn = _p.getBool('rem:kahf') ?? false;
    morningOn = _p.getBool('rem:morning') ?? false;
    morningH = _p.getInt('rem:morningH') ?? 7;
    morningM = _p.getInt('rem:morningM') ?? 0;
    eveningOn = _p.getBool('rem:evening') ?? false;
    eveningH = _p.getInt('rem:eveningH') ?? 17;
    eveningM = _p.getInt('rem:eveningM') ?? 0;
    dhikrEvery = _p.getInt('rem:dhikrEvery') ?? 0;
    fastingOn = _p.getBool('rem:fasting') ?? false;

    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      }
      await _n.initialize(
        const InitializationSettings(android: AndroidInitializationSettings('ic_stat_murattil')),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _n.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) tapped.value = launch!.notificationResponse?.payload;
      // بنعيد جدولة التذكيرات مع كل فتحة (لو الموبايل اتقفل أو التوقيت اتغير)
      if (wirdOn) await _scheduleWird();
      if (kahfOn) await _scheduleKahf();
      await _scheduleAdhkar();
    } catch (e) {
      debugPrint('reminders init: $e');
    }
  }

  Future<bool> _askPermission() async {
    final android = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  tz.TZDateTime _next(int h, int m, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (!t.isAfter(now) || (weekday != null && t.weekday != weekday)) {
      t = tz.TZDateTime(tz.local, t.year, t.month, t.day + 1, h, m);
    }
    return t;
  }

  NotificationDetails _details(String channel, String name, String desc) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          channelDescription: desc,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF1E3A6E),
        ),
      );

  Future<void> _scheduleWird() async {
    await _n.cancel(_wirdId);
    await _n.zonedSchedule(
      _wirdId,
      'وِردك اليومي من القرآن',
      'خصّص دقائق لوردك اليوم، واكتب لنفسك خطوة جديدة في ختمتك.',
      _next(hour, minute),
      _details('wird', 'الورد اليومي', 'تذكير يومي بورد القرآن'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'wird',
    );
  }

  Future<void> _scheduleKahf() async {
    await _n.cancel(_kahfId);
    await _n.zonedSchedule(
      _kahfId,
      'جمعة مباركة',
      'لا تنسَ قراءة سورة الكهف اليوم.',
      _next(10, 0, weekday: DateTime.friday),
      _details('kahf', 'سورة الكهف', 'تذكير بقراءة سورة الكهف يوم الجمعة'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'kahf',
    );
  }

  /// تشغيل/إيقاف تذكير الورد — بترجع false لو المستخدم رفض إذن الإشعارات
  Future<bool> setWird(bool on, {int? h, int? m}) async {
    if (h != null) hour = h;
    if (m != null) minute = m;
    if (on && !await _askPermission()) return false;
    wirdOn = on;
    await _p.setBool('rem:wird', on);
    await _p.setInt('rem:hour', hour);
    await _p.setInt('rem:minute', minute);
    try {
      on ? await _scheduleWird() : await _n.cancel(_wirdId);
    } catch (e) {
      debugPrint('wird reminder: $e');
    }
    notifyListeners();
    return true;
  }

  // ───── الأذان ─────

  static const _adhanBase = 100; // ١٠٠..١٩٩ الأذان، ٢٠٠..٢٩٩ التنبيه قبل الأذان

  /// مسموح بالمنبه الدقيق؟ (أندرويد ١٢+ بيطلب إذن عشان الأذان يطلع في ميعاده بالظبط)
  Future<bool> exactAllowed() async {
    final android = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExact() async {
    final android = _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  Future<bool> askPermission() => _askPermission();

  /// قناة إشعار لكل صوت أذان (صوت القناة مايتغيرش بعد إنشائها في أندرويد)
  NotificationDetails _adhanDetails(String soundId) {
    final snd = AdhanSound.byId(soundId);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_${snd.id}',
        'الأذان — ${snd.name}',
        channelDescription: 'تنبيه دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        sound: snd.raw == null ? null : RawResourceAndroidNotificationSound(snd.raw!),
        color: const Color(0xFF1E3A6E),
      ),
    );
  }

  /// تجربة صوت أذان (إشعار فوري بنفس القناة)
  Future<void> previewAdhan(String soundId) async {
    if (!await _askPermission()) return;
    await _n.cancel(998);
    await _n.show(998, 'تجربة صوت الأذان', AdhanSound.byId(soundId).name, _adhanDetails(soundId), payload: 'prayer');
  }

  Future<void> stopPreview() => _n.cancel(998);

  /// جدولة إشعارات الصلوات (بتمسح القديمة الأول). كل عنصر: (الوقت، العنوان، النص، قبل الأذان؟، صوت الأذان)
  Future<void> schedulePrayers(List<(DateTime, String, String, bool, String)> items) async {
    try {
      for (var i = 0; i < 200; i++) {
        await _n.cancel(_adhanBase + i);
      }
      if (items.isEmpty) return;
      final exact = await exactAllowed();
      final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      final now = DateTime.now();
      var adhanIdx = 0, preIdx = 0;
      for (final (at, title, body, pre, sound) in items) {
        if (!at.isAfter(now)) continue;
        final id = pre ? _adhanBase + 100 + preIdx++ : _adhanBase + adhanIdx++;
        if (id >= _adhanBase + 200 || (!pre && adhanIdx > 100)) continue;
        await _n.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(at, tz.local),
          pre
              ? _details('prayer_pre', 'قبل الأذان', 'تنبيه قبل موعد الصلاة')
              : _adhanDetails(sound),
          androidScheduleMode: mode,
          payload: 'prayer',
        );
      }
    } catch (e) {
      debugPrint('prayer notifications: $e');
    }
  }

  // ───── الأذكار وغيرها ─────

  static const _morningId = 3, _eveningId = 4, _monId = 5, _thuId = 6, _dhikrBase = 300;

  /// أذكار بتتبدّل في تذكير «اذكر الله»
  static const _dhikrTexts = [
    'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ ﷺ',
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
    'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ',
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
    'لَا إِلَهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ الظَّالِمِينَ',
    'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ',
  ];

  Future<void> _daily(int id, int h, int m, String title, String body, String payload, {String channel = 'adhkar', String channelName = 'الأذكار'}) {
    return _n.zonedSchedule(
      id,
      title,
      body,
      _next(h, m),
      _details(channel, channelName, 'تذكير بالأذكار'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> _weekly(int id, int weekday, int h, int m, String title, String body) {
    return _n.zonedSchedule(
      id,
      title,
      body,
      _next(h, m, weekday: weekday),
      _details('fasting', 'الصيام', 'تذكير بصيام الاثنين والخميس'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'fasting',
    );
  }

  Future<void> _scheduleAdhkar() async {
    try {
      for (final id in [_morningId, _eveningId, _monId, _thuId]) {
        await _n.cancel(id);
      }
      for (var i = 0; i < 16; i++) {
        await _n.cancel(_dhikrBase + i);
      }
      if (morningOn) await _daily(_morningId, morningH, morningM, 'أذكار الصباح', 'ابدأ يومك بذكر الله — اضغط لقراءة أذكار الصباح', 'adhkar_morning');
      if (eveningOn) await _daily(_eveningId, eveningH, eveningM, 'أذكار المساء', 'حصّن مساءك بذكر الله — اضغط لقراءة أذكار المساء', 'adhkar_evening');
      if (fastingOn) {
        // ليلة الاثنين = الأحد، وليلة الخميس = الأربعاء
        await _weekly(_monId, DateTime.sunday, 21, 0, 'غدًا الاثنين', 'تذكير بصيام يوم الاثنين لمن استطاع — لا تنسَ السحور');
        await _weekly(_thuId, DateTime.wednesday, 21, 0, 'غدًا الخميس', 'تذكير بصيام يوم الخميس لمن استطاع — لا تنسَ السحور');
      }
      if (dhikrEvery > 0) {
        var i = 0;
        for (var h = 8; h <= 22 && i < 16; h += dhikrEvery) {
          await _daily(_dhikrBase + i, h, 30, 'اذكر الله', _dhikrTexts[i % _dhikrTexts.length], 'dhikr', channel: 'dhikr', channelName: 'تذكير بالذكر');
          i++;
        }
      }
    } catch (e) {
      debugPrint('adhkar reminders: $e');
    }
  }

  Future<bool> setAdhkar({bool? morning, bool? evening, int? mh, int? mm, int? eh, int? em, int? every, bool? fasting}) async {
    final turningOn = (morning ?? false) || (evening ?? false) || (every != null && every > 0) || (fasting ?? false);
    if (turningOn && !await _askPermission()) return false;
    morningOn = morning ?? morningOn;
    eveningOn = evening ?? eveningOn;
    morningH = mh ?? morningH;
    morningM = mm ?? morningM;
    eveningH = eh ?? eveningH;
    eveningM = em ?? eveningM;
    dhikrEvery = every ?? dhikrEvery;
    fastingOn = fasting ?? fastingOn;
    await _p.setBool('rem:morning', morningOn);
    await _p.setInt('rem:morningH', morningH);
    await _p.setInt('rem:morningM', morningM);
    await _p.setBool('rem:evening', eveningOn);
    await _p.setInt('rem:eveningH', eveningH);
    await _p.setInt('rem:eveningM', eveningM);
    await _p.setInt('rem:dhikrEvery', dhikrEvery);
    await _p.setBool('rem:fasting', fastingOn);
    await _scheduleAdhkar();
    notifyListeners();
    return true;
  }

  Future<bool> setKahf(bool on) async {
    if (on && !await _askPermission()) return false;
    kahfOn = on;
    await _p.setBool('rem:kahf', on);
    try {
      on ? await _scheduleKahf() : await _n.cancel(_kahfId);
    } catch (e) {
      debugPrint('kahf reminder: $e');
    }
    notifyListeners();
    return true;
  }
}
