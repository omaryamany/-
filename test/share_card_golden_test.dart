import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murattil/features/mushaf/share_ayah.dart';

/// بيرسم بطاقات المشاركة كصور (بالخطوط الحقيقية) عشان نراجع التصميم من غير محاكي
Future<void> _loadFont(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(rootBundle.load(f));
  }
  await l.load();
}

void main() {
  const ayah = ShareContent(
    header: 'قال الله تعالى',
    text: 'ٱللَّهُ لَآ إِلَـٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَـٰوَٰتِ وَمَا فِى ٱلْأَرْضِ',
    source: 'سورة البقرة · الآية ٢٥٥',
    quran: true,
  );
  const dua = ShareContent(
    header: 'دعاء الإفطار',
    text: 'ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
    source: 'رواه أبو داود',
  );
  const name = ShareContent(
    header: 'من أسماء الله الحسنى',
    title: 'الرحمن',
    text: 'ذو الرحمة الواسعة التي وسعت كل شيء.',
    source: '﴿وَلِلَّهِ ٱلْأَسْمَآءُ ٱلْحُسْنَىٰ فَٱدْعُوهُ بِهَا﴾',
  );
  final long = ShareContent(
    header: 'إنما الأعمال بالنيات',
    text: List.filled(6, 'عَنْ أَمِيرِ الْمُؤْمِنِينَ أَبِي حَفْصٍ عُمَرَ بْنِ الْخَطَّابِ رَضِيَ اللهُ عَنْهُ قَالَ: سَمِعْتُ رَسُولَ اللَّهِ ﷺ يَقُولُ: إنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ').join('، '),
    source: 'الأربعون النووية · الحديث الأول',
  );

  final cases = <(String, ShareContent, int, bool)>[
    ('ayah_navy_square', ayah, 0, false),
    ('ayah_mushaf_square', ayah, 1, false),
    ('dua_night_square', dua, 2, false),
    ('name_teal_square', name, 3, false),
    ('hadith_sunset_story', long, 4, true),
    ('ayah_purple_story', ayah, 5, true),
  ];

  testWidgets('بطاقات المشاركة', (t) async {
    await _loadFont('AmiriQuran', ['assets/fonts/AmiriQuran-Regular.ttf']);
    await _loadFont('NotoSansArabic', [
      'assets/fonts/NotoSansArabic-Regular.ttf',
      'assets/fonts/NotoSansArabic-Bold.ttf',
      'assets/fonts/NotoSansArabic-ExtraBold.ttf',
    ]);
    for (final (file, c, style, story) in cases) {
      t.view.physicalSize = Size(1080, story ? 1920 : 1080);
      t.view.devicePixelRatio = 3;
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(alignment: Alignment.topLeft, child: RepaintBoundary(child: ShareCardView(content: c, style: style, story: story))),
        ),
      ));
      await t.pumpAndSettle();
      await expectLater(find.byType(ShareCardView), matchesGoldenFile('goldens/$file.png'));
    }
    t.view.reset();
  });
}
