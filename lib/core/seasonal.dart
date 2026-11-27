import 'arabic.dart';
import 'hijri.dart';
import 'prayer.dart';
import 'prayer_calc.dart';
import 'reminders.dart';

/// جدولة تذكيرات المواسم: المناسبات وأيام الصيام المستحب، وسحور وتراويح رمضان.
/// بتتعاد مع كل فتحة للتطبيق ومع أي تغيير في الإعدادات أو المكان.
class Seasonal {
  static Future<void> reschedule() async {
    final r = Reminders.instance;

    final occ = <(DateTime, String, String)>[];
    if (r.occasionsOn) {
      for (final o in Hijri.upcoming(days: 120)) {
        if (o.fast) {
          final eve = o.date.subtract(const Duration(days: 1));
          occ.add((DateTime(eve.year, eve.month, eve.day, 21), 'غدًا: ${o.title}', o.hint));
        } else {
          occ.add((DateTime(o.date.year, o.date.month, o.date.day, 8), o.title, o.hint));
        }
      }
    }
    await r.oneShots(400, 40, occ, channel: 'occasions', channelName: 'المناسبات والصيام', payload: 'calendar');

    final rm = <(DateTime, String, String)>[];
    final ps = PrayerStore.instance;
    if (ps.configured && (r.suhoorBefore > 0 || r.taraweehOn)) {
      final today = dateOnly(DateTime.now());
      for (var k = 0; k < 40; k++) {
        final d = today.add(Duration(days: k));
        final day = ps.day(d);
        if (r.suhoorBefore > 0 && Hijri.of(d).month == 9) {
          final fajr = day[Prayer.fajr];
          rm.add((
            fajr.subtract(Duration(minutes: r.suhoorBefore)),
            'السحور',
            'الفجر ${timeLabel(fajr.hour, fajr.minute)} — «تسحّروا فإن في السحور بركة»',
          ));
        }
        // ليلة من ليالي رمضان: اليوم اللي بعدها من رمضان
        if (r.taraweehOn && Hijri.of(d.add(const Duration(days: 1))).month == 9) {
          final isha = day[Prayer.isha];
          rm.add((isha.add(const Duration(minutes: 15)), 'صلاة التراويح', '«من قام رمضان إيمانًا واحتسابًا غُفر له ما تقدّم من ذنبه»'));
        }
      }
      rm.sort((a, b) => a.$1.compareTo(b.$1));
    }
    await r.oneShots(460, 70, rm, channel: 'ramadan', channelName: 'رمضان', payload: 'ramadan');
  }
}
