import 'package:flutter/material.dart';

import '../core/khatma.dart';
import '../core/theme.dart';
import '../core/quran.dart';
import '../core/reminders.dart';
import 'celebration.dart';
import 'home/home_screen.dart';
import 'index/index_screen.dart';
import 'khatma/khatma_screen.dart';
import 'khatma/khatma_setup.dart';
import 'mushaf/mushaf_screen.dart';
import 'adhkar/adhkar_home.dart';
import 'adhkar/adhkar_screen.dart';
import 'listen/now_playing.dart';
import 'listen/listen_screen.dart';
import 'prayer/prayer_screen.dart';
import 'settings/settings_screen.dart';

/// فتح المصحف على صفحة (أو آية) — [wird] بيظهر شريط ورد اليوم فوق
Future<void> openMushaf(BuildContext context, {int? page, int? ayah, bool wird = false}) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => MushafScreen(page: page, ayah: ayah, wird: wird)));
}

/// فتح ورد اليوم من أول صفحة لسه ماتقرتش
Future<void> openWird(BuildContext context) => openMushaf(context, page: KhatmaStore.instance.nextPage, wird: true);

class Shell extends StatefulWidget {
  const Shell({super.key});

  /// بعد أول تشغيل: افتح إعداد الختمة مباشرة
  static bool openKhatmaSetup = false;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    KhatmaStore.instance.events.addListener(_onKhatmaEvent);
    Reminders.instance.tapped.addListener(_onNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onNotification();
      if (Shell.openKhatmaSetup && mounted) {
        Shell.openKhatmaSetup = false;
        showKhatmaSetup(context);
      }
    });
  }

  @override
  void dispose() {
    KhatmaStore.instance.events.removeListener(_onKhatmaEvent);
    Reminders.instance.tapped.removeListener(_onNotification);
    super.dispose();
  }

  void _onKhatmaEvent() {
    final e = KhatmaStore.instance.events.value;
    if (e == null || !mounted) return;
    KhatmaStore.instance.events.value = null;
    showCelebration(context, e);
  }

  /// المستخدم ضغط على إشعار: الورد بيفتح الورد، والكهف بيفتح سورة الكهف
  void _onNotification() {
    final p = Reminders.instance.tapped.value;
    if (p == null || !mounted) return;
    Reminders.instance.tapped.value = null;
    if (p == 'kahf') {
      openMushaf(context, ayah: Quran.surah(18).start);
    } else if (p == 'prayer') {
      setState(() => _tab = 3);
    } else if (p == 'adhkar_morning') {
      openAdhkar(context, AdhkarKind.morning);
    } else if (p == 'adhkar_evening') {
      openAdhkar(context, AdhkarKind.evening);
    } else if (p == 'dhikr' || p == 'fasting') {
      setState(() => _tab = 0);
    } else if (KhatmaStore.instance.active && !KhatmaStore.instance.finished) {
      openWird(context);
    } else {
      openKhatma(context);
    }
  }

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onTab: goTo),
      const IndexScreen(),
      const AdhkarHome(),
      const PrayerScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      extendBody: false,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        MiniPlayer(safeBottom: false, onOpen: (_) => openNowPlaying(context)),
        MurattilNavBar(
          index: _tab,
          onTap: goTo,
          items: const [
            (Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
            (Icons.menu_book_outlined, Icons.menu_book_rounded, 'المصحف'),
            (Icons.spa_outlined, Icons.spa_rounded, 'الأذكار'),
            (Icons.mosque_outlined, Icons.mosque_rounded, 'الصلاة'),
            (Icons.grid_view_outlined, Icons.grid_view_rounded, 'المزيد'),
          ],
        ),
      ]),
    );
  }
}

/// شريط التنقل السفلي العائم (تصميم «مُرتِّل»): كبسولة فيها كل أيقونة وتحتها اسمها،
/// والمختار بيظهر حوالين أيقونته كبسولة فيروزي
class MurattilNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(IconData, IconData, String)> items;
  const MurattilNavBar({super.key, required this.index, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        padding: const EdgeInsets.fromLTRB(4, 7, 4, 6),
        decoration: BoxDecoration(
          color: dark ? AppColors.nightCard : AppColors.pineDeep,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.0,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  label: items[i].$3,
                  button: true,
                  selected: i == index,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: i == index ? 54 : 40,
                        height: 30,
                        decoration: BoxDecoration(
                          color: i == index ? AppColors.turquoise : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(i == index ? items[i].$2 : items[i].$1, color: i == index ? Colors.white : Colors.white70, size: 22),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == index ? Colors.white : Colors.white70,
                          fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 11.5,
                          height: 1.25,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
