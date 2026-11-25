import 'package:flutter/material.dart';

import '../listen/listen_screen.dart';
import '../mushaf/sheets.dart';
import '../shell.dart';

/// فهرس المصحف: السور (مع بحث بالاسم) والأجزاء والعلامات
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});
  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    void open(int g) => openMushaf(context, ayah: g);
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
            child: Row(children: [
              Expanded(child: Text('فهرس المصحف', style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.filledTonal(
                tooltip: 'الاستماع',
                onPressed: () => openListen(context),
                icon: const Icon(Icons.headphones_rounded),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'بحث في الآيات',
                onPressed: () => showSearchSheet(context, onPick: open),
                icon: const Icon(Icons.manage_search_rounded),
              ),
            ]),
          ),
          const TabBar(tabs: [Tab(text: 'السور'), Tab(text: 'الأجزاء'), Tab(text: 'الأحزاب'), Tab(text: 'العلامات')]),
          Expanded(
            child: TabBarView(children: [
              Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _filter = v),
                    decoration: const InputDecoration(hintText: 'اسم السورة أو رقمها', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                  ),
                ),
                Expanded(child: SurahList(filter: _filter, onPick: open)),
              ]),
              JuzList(onPick: open),
              HizbList(onPick: open),
              BookmarksList(onPick: open),
            ]),
          ),
        ]),
      ),
    );
  }
}
