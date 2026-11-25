import 'package:flutter/material.dart';

import '../core/khatma.dart';
import '../core/quran.dart';
import '../core/reminders.dart';
import 'celebration.dart';
import 'home/home_screen.dart';
import 'index/index_screen.dart';
import 'khatma/khatma_screen.dart';
import 'khatma/khatma_setup.dart';
import 'mushaf/mushaf_screen.dart';
import 'adhkar/adhkar_screen.dart';
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
      setState(() => _tab = 2);
    }
  }

  void goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onTab: goTo),
      const IndexScreen(),
      const KhatmaScreen(),
      const PrayerScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        MiniPlayer(safeBottom: false, onOpen: (g) => openMushaf(context, ayah: g)),
        NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'المصحف'),
          NavigationDestination(icon: Icon(Icons.track_changes_outlined), selectedIcon: Icon(Icons.track_changes_rounded), label: 'الختمة'),
          NavigationDestination(icon: Icon(Icons.mosque_outlined), selectedIcon: Icon(Icons.mosque_rounded), label: 'الصلاة'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
        ),
      ]),
    );
  }
}
