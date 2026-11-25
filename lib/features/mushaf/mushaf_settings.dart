import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../core/quran.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../listen/listen_screen.dart';

/// إعدادات القراءة من جوه المصحف: لون الصفحة، حجم الخط، الشاشة، وضع الحفظ، التكرار، والقارئ
void showMushafSettings(
  BuildContext context, {
  required bool hifz,
  required ValueChanged<bool> onHifz,
  required int repeat,
  required ValueChanged<int> onRepeat,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (c) => _Sheet(hifz: hifz, onHifz: onHifz, repeat: repeat, onRepeat: onRepeat),
  );
}

class _Sheet extends StatefulWidget {
  final bool hifz;
  final ValueChanged<bool> onHifz;
  final int repeat;
  final ValueChanged<int> onRepeat;
  const _Sheet({required this.hifz, required this.onHifz, required this.repeat, required this.onRepeat});
  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final store = AppStore.instance;
  late bool _hifz = widget.hifz;
  late int _repeat = widget.repeat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('إعدادات القراءة', style: t.titleLarge),
          const SizedBox(height: 16),
          Text('لون الصفحة', style: t.titleSmall),
          const SizedBox(height: 8),
          const MushafThemePicker(),
          const SizedBox(height: 18),
          Text('حجم الخط', style: t.titleSmall),
          Row(children: [
            const Text('أ', style: TextStyle(fontSize: 14)),
            Expanded(child: Slider(value: store.fontScale, min: 1, max: 1.6, divisions: 6, onChanged: store.setScale)),
            const Text('أ', style: TextStyle(fontSize: 26)),
          ]),
          Text(store.fontScale > 1 ? 'يُعرض النص متصلًا بخط أكبر لسهولة القراءة.' : 'الحجم الأصلي: الصفحة كاملة برسم مصحف المدينة كما في المطبوع.',
              style: t.bodySmall),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('إبقاء الشاشة مضاءة أثناء القراءة'),
            value: store.keepAwake,
            onChanged: store.setKeepAwake,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('وضع الحفظ (إخفاء الآيات)'),
            subtitle: const Text('اختبر حفظك: تظهر الآية عند الضغط عليها'),
            value: _hifz,
            onChanged: (v) {
              setState(() => _hifz = v);
              widget.onHifz(v);
            },
          ),
          const SizedBox(height: 8),
          Text('تكرار كل آية في التلاوة', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final n in [1, 3, 5, 10])
              ChoiceChip(
                selected: _repeat == n,
                label: Text(n == 1 ? 'مرة واحدة' : '${arDigits(n)} مرات'),
                onSelected: (_) {
                  setState(() => _repeat = n);
                  widget.onRepeat(n);
                },
              ),
          ]),
          const SizedBox(height: 18),
          Text('القارئ', style: t.titleSmall),
          const SizedBox(height: 8),
          const ReciterPicker(),
        ]),
      ),
    );
  }
}

/// اختيار لون صفحة المصحف
class MushafThemePicker extends StatelessWidget {
  const MushafThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final List<(String, String, MushafPalette?)> options = [
      ('auto', 'تلقائي', null),
      ('paper', 'ورقي', MushafPalette.light),
      ('sepia', 'دافئ', MushafPalette.sepia),
      ('night', 'ليلي', MushafPalette.night),
    ];
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Row(children: [
        for (final (key, label, pal) in options)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => store.setMushafTheme(key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: pal?.paper,
                    gradient: pal == null ? const LinearGradient(colors: [Color(0xFFFCF8EE), Color(0xFF101916)], stops: [.5, .5]) : null,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: store.mushafTheme == key ? AppColors.gold : Colors.black12, width: store.mushafTheme == key ? 3 : 1),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pal?.ink ?? AppColors.gold,
                      fontWeight: FontWeight.w700,
                      shadows: pal == null ? const [Shadow(color: Colors.black54, blurRadius: 3)] : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// اختيار القارئ (بيفتح قائمة كل القرّاء)
class ReciterPicker extends StatelessWidget {
  const ReciterPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.record_voice_over_rounded, color: AppColors.gold),
          title: Text(Quran.reciter(store.reciter).name),
          subtitle: Text('${arDigits(Quran.reciters.length)} قارئًا متاحًا'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => showReciterSheet(context),
        ),
      ),
    );
  }
}
