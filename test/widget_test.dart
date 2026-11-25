import 'package:flutter_test/flutter_test.dart';
import 'package:murattil/core/arabic.dart';
import 'package:murattil/core/khatma.dart';

void main() {
  test('الورد بيتوزّع على كل الصفحات من غير ما يضيع صفحة', () {
    for (final days in [1, 3, 7, 10, 15, 30, 60, 90, 365]) {
      final p = KhatmaPlan(start: DateTime(2026, 1, 1), days: days);
      expect(p.targetEnd(0), 0);
      expect(p.targetEnd(days), 604);
      var sum = 0;
      for (var d = 1; d <= days; d++) {
        final x = p.portionOfDay(d);
        expect(x.to >= x.from - 1, isTrue);
        sum += x.to - x.from + 1;
      }
      expect(sum, 604);
    }
  });

  test('ختمة شهر = حوالي ٢٠ صفحة يوميًا', () {
    final p = KhatmaPlan(start: DateTime(2026, 1, 1), days: 30);
    final first = p.portionOfDay(1);
    expect(first.from, 1);
    expect(first.to - first.from + 1, inInclusiveRange(20, 21));
  });

  test('الأرقام العربية والتواريخ', () {
    expect(arDigits(604), '٦٠٤');
    expect(pagesLabel(2), 'صفحتين');
    expect(daysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 29, 1)), 1);
  });
}
