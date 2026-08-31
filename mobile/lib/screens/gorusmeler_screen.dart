import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/list_query.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/edit_form_sheet.dart';
import '../widgets/list_query_bar.dart';
import '../widgets/meeting_card.dart';
import '../widgets/meeting_detail_sheet.dart';

class GorusmelerScreen extends StatefulWidget {
  final ApiService api;
  final bool showUserBadge;

  const GorusmelerScreen({
    super.key,
    required this.api,
    this.showUserBadge = false,
  });

  @override
  State<GorusmelerScreen> createState() => _GorusmelerScreenState();
}

class _GorusmelerScreenState extends State<GorusmelerScreen> {
  static const _sortOptions = [
    ListSortOption('tarih_desc', 'Yeni tarih'),
    ListSortOption('tarih_asc', 'Eski tarih'),
    ListSortOption('kurum_asc', 'Kurum A–Z'),
    ListSortOption('durum_asc', 'Durum A–Z'),
  ];

  bool _loading = true;
  List<AnalysisRecord> _items = const [];
  List<Product> _products = const [];
  Future<void>? _inflightLoad;
  final _search = TextEditingController();
  String _sort = 'tarih_desc';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() {
    return _inflightLoad ??= _fetch().whenComplete(() => _inflightLoad = null);
  }

  Future<void> _fetch() async {
    try {
      final items = await widget.api.fetchAnalyses();
      List<Product> products = _products;
      try {
        products = await widget.api.fetchProducts();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open(AnalysisRecord record) async {
    final changed = await showMeetingDetailSheet(
      context: context,
      api: widget.api,
      products: _products,
      record: record,
    );
    if (changed) await _load();
  }

  Future<void> _edit(AnalysisRecord? record) async {
    final saved = await showEditFormSheet(
      context: context,
      api: widget.api,
      products: _products,
      record: record,
    );
    if (saved) await _load();
  }

  Future<void> _delete(AnalysisRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text(
          'Bu kaydı silmek istiyor musunuz? Kayıt kalıcı silinmez, listeden kaldırılır.',
        ),
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
    await widget.api.deleteAnalysis(record.id);
    await _load();
  }

  List<AnalysisRecord> get _visible {
    final filtered = _items
        .where(
          (r) => matchesQuery(_search.text, [
            r.kurumAdi,
            r.urunAdi,
            r.urunKodu,
            ...r.ilgilenilenUrunler,
            r.durum,
            r.notIcerigi,
            r.kullaniciAdi,
          ]),
        )
        .toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case 'tarih_asc':
          return compareDate(a.tarih, b.tarih);
        case 'kurum_asc':
          return compareText(a.kurumAdi, b.kurumAdi);
        case 'durum_asc':
          return compareText(a.durum, b.durum);
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
        title: const Text('GÖRÜŞMELER'),
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
            hint: 'Kurum, ürün, durum veya not ara…',
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
                                ? 'Henüz görüşme yok'
                                : 'Aramayla eşleşen görüşme yok',
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
                        final r = visible[i];
                        return MeetingCard(
                          record: r,
                          mode: MeetingCardMode.gorusme,
                          showUserBadge: widget.showUserBadge,
                          onOpen: () => _open(r),
                          onEdit: () => _edit(r),
                          onDelete: () => _delete(r),
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
