/// أدوات النص العربي: الأرقام، التطبيع للبحث، والتواريخ النسبية.
library;

import 'dart:math' as math;

const _arDigits = '٠١٢٣٤٥٦٧٨٩';

/// 20 → ٢٠
String arDigits(Object n) => n.toString().replaceAllMapped(RegExp(r'[0-9]'), (m) => _arDigits[int.parse(m[0]!)]);

/// «٣ صفحات» / «صفحة واحدة» / «صفحتين» / «١١ صفحة»
String pagesLabel(int n) {
  if (n == 1) return 'صفحة واحدة';
  if (n == 2) return 'صفحتين';
  if (n >= 3 && n <= 10) return '${arDigits(n)} صفحات';
  return '${arDigits(n)} صفحة';
}

/// «يوم واحد» / «يومين» / «٣ أيام» / «١٥ يوم»
String daysLabel(int n) {
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومين';
  if (n >= 3 && n <= 10) return '${arDigits(n)} أيام';
  return '${arDigits(n)} يوم';
}

/// تطبيع النص العربي للبحث: يشيل التشكيل وعلامات المصحف ويوحّد الألف والهمزات والتاء المربوطة
String normalizeArabic(String s) {
  final noMarks = s.replaceAll(RegExp(r'[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '');
  return noMarks
      .replaceAll(RegExp(r'[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// تاريخ اليوم بس (من غير ساعة) — أساس حساب أيام الختمة
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// عدد الأيام بين تاريخين (بالتقويم، مش بالساعات — عشان التوقيت الصيفي مايلخبطش الحساب)
int daysBetween(DateTime a, DateTime b) {
  final x = DateTime.utc(a.year, a.month, a.day);
  final y = DateTime.utc(b.year, b.month, b.day);
  return y.difference(x).inDays;
}

String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

/// ٢٤ نوفمبر
String shortDate(DateTime d) => '${arDigits(d.day)} ${_months[d.month - 1]}';

/// الثلاثاء ٢٤ نوفمبر
String longDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${shortDate(d)}';

/// ٩:٠٠ م
String timeLabel(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '${arDigits(h12)}:${arDigits(minute.toString().padLeft(2, '0'))} ${hour < 12 ? 'ص' : 'م'}';
}

String relativeTime(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'الآن';
  if (d.inMinutes < 60) return 'منذ ${countLabel(d.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
  final days = daysBetween(t, DateTime.now());
  if (days == 0) return 'منذ ${countLabel(math.max(1, d.inHours), 'ساعة', 'ساعتين', 'ساعات')}';
  if (days == 1) return 'أمس';
  if (days < 7) return 'منذ ${daysLabel(days)}';
  return shortDate(t);
}

/// «ساعة» / «ساعتين» / «٣ ساعات» / «١١ ساعة»
String countLabel(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n >= 3 && n <= 10) return '${arDigits(n)} $few';
  return '${arDigits(n)} $one';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h >= 4 && h < 12) return 'صباح الخير';
  return 'مساء الخير';
}

/// «دقيقة» / «دقيقتين» / «٥ دقائق» / «١٥ دقيقة»
String minutesLabel(int n) => countLabel(n, 'دقيقة', 'دقيقتين', 'دقائق');
