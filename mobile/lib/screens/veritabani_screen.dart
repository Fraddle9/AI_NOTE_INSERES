import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/list_query.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/list_query_bar.dart';

class VeritabaniScreen extends StatefulWidget {
  final ApiService api;

  const VeritabaniScreen({super.key, required this.api});

  @override
  State<VeritabaniScreen> createState() => _VeritabaniScreenState();
}

class _VeritabaniScreenState extends State<VeritabaniScreen> {
  bool _loadingTables = true;
  bool _loadingRows = false;
  String? _error;
  List<DbTableInfo> _tablolar = const [];
  String? _seciliAd;
  DbTableData? _data;
  final _search = TextEditingController();
  String _sort = '';
  bool _sortDesc = false;

  @override
  void initState() {
    super.initState();
    _yukleTablolar();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _yukleTablolar() async {
    setState(() {
      _loadingTables = true;
      _error = null;
    });
    try {
      final tablolar = await widget.api.fetchDbTables();
      if (!mounted) return;
      setState(() {
        _tablolar = tablolar;
        _loadingTables = false;
      });
      if (tablolar.isNotEmpty) {
        await _yukleSatirlar(tablolar.first.ad);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTables = false;
      });
    }
  }

  Future<void> _yukleSatirlar(String ad) async {
    setState(() {
      _seciliAd = ad;
      _loadingRows = true;
      _error = null;
      _search.clear();
    });
    try {
      final data = await widget.api.fetchDbTableRows(ad);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loadingRows = false;
        _sort = data.kolonlar.contains('id')
            ? 'id'
            : (data.kolonlar.isNotEmpty ? data.kolonlar.first : '');
        _sortDesc = _sort == 'id';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingRows = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible {
    final data = _data;
    if (data == null) return const [];
    var liste = data.kayitlar
        .where((row) => matchesQuery(_search.text, row.values))
        .toList();
    if (_sort.isNotEmpty) {
      liste.sort((a, b) {
        final av = a[_sort];
        final bv = b[_sort];
        if (av is num || bv is num || num.tryParse('${av ?? ''}') != null) {
          return compareNum(av, bv, desc: _sortDesc);
        }
        final as_ = '$av';
        final bs = '$bv';
        if (DateTime.tryParse(as_) != null || DateTime.tryParse(bs) != null) {
          return compareDate(as_, bs, desc: _sortDesc);
        }
        return compareText(av, bv, desc: _sortDesc);
      });
    }
    return liste;
  }

  List<ListSortOption> get _sortOptions {
    final kolonlar = _data?.kolonlar ?? const <String>[];
    return [
      for (final k in kolonlar) ...[
        ListSortOption('$k|asc', '$k A–Z'),
        ListSortOption('$k|desc', '$k Z–A'),
      ],
    ];
  }

  String get _sortValue => _sort.isEmpty ? '' : '$_sort|${_sortDesc ? 'desc' : 'asc'}';

  String _hucre(Object? deger) {
    if (deger == null) return '—';
    if (deger is bool) return deger ? 'true' : 'false';
    final s = deger.toString();
    return s.isEmpty ? '—' : s;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final kolonlar = _data?.kolonlar ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('VERİTABANI'),
        actions: [
          IconButton(onPressed: _yukleTablolar, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _tablolar.isEmpty
                ? const SizedBox.shrink()
                : InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tablo',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _seciliAd,
                        dropdownColor: AppColors.surfaceSolid,
                        items: [
                          for (final t in _tablolar)
                            DropdownMenuItem(
                              value: t.ad,
                              child: Text(t.baslik),
                            ),
                        ],
                        onChanged: (ad) {
                          if (ad != null) _yukleSatirlar(ad);
                        },
                      ),
                    ),
                  ),
          ),
          if (kolonlar.isNotEmpty)
            ListQueryBar(
              controller: _search,
              hint: 'Tabloda herhangi bir kolonda ara…',
              sortValue: _sortValue,
              sortOptions: _sortOptions,
              onSortChanged: (v) {
                final parts = v.split('|');
                setState(() {
                  _sort = parts.first;
                  _sortDesc = parts.length > 1 && parts.last == 'desc';
                });
              },
              onQueryChanged: () => setState(() {}),
              shownCount: _loadingRows ? null : visible.length,
              totalCount: _loadingRows ? null : (_data?.kayitlar.length ?? 0),
            ),
          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () async {
                if (_seciliAd != null) {
                  await _yukleSatirlar(_seciliAd!);
                } else {
                  await _yukleTablolar();
                }
              },
              child: _buildBody(visible, kolonlar),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> visible, List<String> kolonlar) {
    if (_loadingTables || _loadingRows) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.olumsuz)),
        ],
      );
    }
    if (_tablolar.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Tablo yok', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ],
      );
    }
    if (kolonlar.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          Text('Kolon yok', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ],
      );
    }
    if (visible.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            (_data?.kayitlar.isEmpty ?? true)
                ? 'Bu tabloda kayıt yok'
                : 'Aramayla eşleşen kayıt yok',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(AppColors.surfaceAlt.withValues(alpha: 0.9)),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 64,
          columns: [
            for (final k in kolonlar)
              DataColumn(
                label: Text(
                  k,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                onSort: (_, __) {
                  setState(() {
                    if (_sort == k) {
                      _sortDesc = !_sortDesc;
                    } else {
                      _sort = k;
                      _sortDesc = false;
                    }
                  });
                },
              ),
          ],
          rows: [
            for (final row in visible)
              DataRow(
                cells: [
                  for (final k in kolonlar)
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          _hucre(row[k]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
