import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/list_query.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/list_query_bar.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/task_tile.dart';

class GorevlerScreen extends StatefulWidget {
  final ApiService api;

  const GorevlerScreen({super.key, required this.api});

  @override
  State<GorevlerScreen> createState() => _GorevlerScreenState();
}

class _GorevlerScreenState extends State<GorevlerScreen> {
  static const _sortOptions = [
    ListSortOption('tarih_desc', 'Yeni tarih'),
    ListSortOption('tarih_asc', 'Eski tarih'),
    ListSortOption('baslik_asc', 'Başlık A–Z'),
    ListSortOption('durum_asc', 'Açık önce'),
  ];

  bool _loading = true;
  int? _mevcutKullaniciId;
  List<TaskItem> _items = const [];
  Future<void>? _inflightLoad;
  final _search = TextEditingController();
  String _sort = 'tarih_desc';

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _mevcutKullaniciId = user?.id);
  }

  Future<void> _load() {
    return _inflightLoad ??= _fetch().whenComplete(() => _inflightLoad = null);
  }

  Future<void> _fetch() async {
    try {
      final items = await widget.api.fetchTasks();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _edit(TaskItem? task) async {
    final saved = await showTaskFormSheet(context: context, api: widget.api, task: task);
    if (saved) await _load();
  }

  Future<void> _delete(TaskItem task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Görevi sil'),
        content: const Text('Bu görev listeden kaldırılacak (soft delete).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.api.deleteTask(task.id);
    await _load();
  }

  List<TaskItem> get _visible {
    final filtered = _items
        .where(
          (t) => matchesQuery(_search.text, [
            t.baslik,
            t.kurumAdi,
            t.assignedUserName,
            t.olusturanAdi,
            t.tamamlandi ? 'tamamlandı' : 'açık',
          ]),
        )
        .toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case 'tarih_asc':
          return compareDate(a.tarih, b.tarih);
        case 'baslik_asc':
          return compareText(a.baslik, b.baslik);
        case 'durum_asc':
          final c = (a.tamamlandi ? 1 : 0).compareTo(b.tamamlandi ? 1 : 0);
          return c != 0 ? c : compareDate(a.tarih, b.tarih, desc: true);
        case 'tarih_desc':
        default:
          return compareDate(a.tarih, b.tarih, desc: true);
      }
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('GÖREVLER'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(null),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          ListQueryBar(
            controller: _search,
            hint: 'Görev, kurum veya kişi ara…',
            sortValue: _sort,
            sortOptions: _sortOptions,
            onSortChanged: (v) => setState(() => _sort = v),
            onQueryChanged: () => setState(() {}),
            shownCount: _loading ? null : visible.length,
            totalCount: _loading ? null : _items.length,
          ),
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty || visible.isEmpty
                  ? ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 48, 16, 88),
                      children: [
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else
                          Text(
                            _items.isEmpty
                                ? 'Henüz görev yok'
                                : 'Aramayla eşleşen görev yok',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                      ],
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final t = visible[i];
                        return TaskTile(
                          task: t,
                          mevcutKullaniciId: _mevcutKullaniciId,
                          onEdit: () => _edit(t),
                          onDelete: () => _delete(t),
                          onToggle: () async {
                            await widget.api.patchTask(
                              t.id,
                              {'tamamlandi': !t.tamamlandi},
                            );
                            await _load();
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
