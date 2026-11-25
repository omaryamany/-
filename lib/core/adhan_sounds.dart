/// أصوات الأذان المدمجة في التطبيق (android/app/src/main/res/raw).
/// المصدر: مجموعة Kiwifu/adhan-mp3 على GitHub (متاحة لتطبيقات المسلمين) — والنغمة الهادئة من تصميم مُرتِّل.
class AdhanSound {
  final String id;
  final String name;
  final String group;

  /// اسم الملف في res/raw (من غير الامتداد) — null = صوت الإشعار الافتراضي للهاتف
  final String? raw;
  const AdhanSound(this.id, this.name, this.group, this.raw);

  static const all = [
    AdhanSound('egypt_refaat', 'الشيخ محمد رفعت', 'مصر', 'adhan_egypt_refaat'),
    AdhanSound('egypt_abdulbasit', 'الشيخ عبد الباسط عبد الصمد', 'مصر', 'adhan_egypt_abdulbasit'),
    AdhanSound('egypt_hussary', 'الشيخ محمود خليل الحصري', 'مصر', 'adhan_egypt_hussary'),
    AdhanSound('egypt_minshawi', 'الشيخ محمد صديق المنشاوي', 'مصر', 'adhan_egypt_minshawi'),
    AdhanSound('egypt_banna', 'الشيخ محمود علي البنا', 'مصر', 'adhan_egypt_banna'),
    AdhanSound('egypt_mustafa', 'الشيخ مصطفى إسماعيل', 'مصر', 'adhan_egypt_mustafa'),
    AdhanSound('fajr_cairo', 'أذان الفجر — القاهرة', 'مصر', 'adhan_fajr_cairo'),
    AdhanSound('makkah_mulla', 'الحرم المكي — الشيخ علي ملا', 'السعودية', 'adhan_makkah_mulla'),
    AdhanSound('makkah_hadrawi', 'الحرم المكي — الشيخ فاروق حضراوي', 'السعودية', 'adhan_makkah_hadrawi'),
    AdhanSound('madinah', 'الحرم المدني', 'السعودية', 'adhan_madinah'),
    AdhanSound('saudi_qatami', 'الشيخ ناصر القطامي', 'السعودية', 'adhan_saudi_qatami'),
    AdhanSound('fajr_makkah', 'أذان الفجر — الحرم المكي', 'السعودية', 'adhan_fajr_makkah'),
    AdhanSound('aqsa', 'المسجد الأقصى — الشيخ ناجي قزاز', 'فلسطين', 'adhan_aqsa'),
    AdhanSound('chime', 'نغمة هادئة', 'تنبيهات', 'murattil_chime'),
    AdhanSound('default', 'صوت إشعار الهاتف', 'تنبيهات', null),
  ];

  static AdhanSound byId(String id) => all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
