import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/list_query.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/list_query_bar.dart';
import 'kurum_detay_screen.dart';

class KurumlarScreen extends StatefulWidget {
  final ApiService api;

  const KurumlarScreen({super.key, required this.api});

  @override
  State<KurumlarScreen> createState() => _KurumlarScreenState();
}

class _KurumlarScreenState extends State<KurumlarScreen> {
  static const _sortOptions = [
    ListSortOption('ad_asc', 'Ad A–Z'),
    ListSortOption('ad_desc', 'Ad Z–A'),
    ListSortOption('tarih_desc', 'Yeni eklenen'),
    ListSortOption('tarih_asc', 'Eski eklenen'),
    ListSortOption('tur_asc', 'Tür A–Z'),
  ];

  bool _loading = true;
  bool _isAdmin = false;
  String? _error;
  List<Institution> _items = const [];
  Future<void>? _inflightLoad;
  final _search = TextEditingController();
  String _sort = 'ad_asc';

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
    setState(() => _isAdmin = user?.isAdmin ?? false);
  }

  Future<void> _load() {
    return _inflightLoad ??= _fetch().whenComplete(() => _inflightLoad = null);
  }

  Future<void> _fetch() async {
    try {
      final items = await widget.api.fetchInstitutions();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Institution> get _visible {
    final filtered = _items
        .where(
          (k) => matchesQuery(_search.text, [k.name, k.type, k.createdAt]),
        )
        .toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case 'ad_desc':
          return compareText(a.name, b.name, desc: true);
        case 'tarih_desc':
          return compareDate(a.createdAt, b.createdAt, desc: true);
        case 'tarih_asc':
          return compareDate(a.createdAt, b.createdAt);
        case 'tur_asc':
          final c = compareText(a.type, b.type);
          return c != 0 ? c : compareText(a.name, b.name);
        case 'ad_asc':
        default:
          return compareText(a.name, b.name);
      }
    });
    return filtered;
  }

  Future<void> _addKurum() async {
    final nameCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Kurum'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kurum adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true || name.isEmpty) return;
    try {
      await widget.api.createInstitution(name: name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editKurum(Institution k) async {
    final nameCtrl = TextEditingController(text: k.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kurumu düzenle'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kurum adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (saved != true || name.isEmpty) return;
    try {
      await widget.api.updateInstitution(k.id, yeniAd: name);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteKurum(Institution k) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kurumu sil'),
        content: Text('${k.name} silinsin mi?'),
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
    try {
      await widget.api.deleteInstitution(k.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
        title: const Text('KURUMLAR'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _addKurum,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          ListQueryBar(
            controller: _search,
            hint: 'Kurum adı veya tür ara…',
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 48, 16, 88),
                      children: [
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_error != null)
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.olumsuz),
                          )
                        else
                          Text(
                            _items.isEmpty
                                ? 'Henüz kurum yok'
                                : 'Aramayla eşleşen kurum yok',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final k = visible[i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Text(k.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              (k.type ?? 'Kurum').trim(),
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            trailing: _isAdmin
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                                    onSelected: (v) {
                                      if (v == 'edit') _editKurum(k);
                                      if (v == 'delete') _deleteKurum(k);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                                    ],
                                  )
                                : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => KurumDetayScreen(
                                    api: widget.api,
                                    id: k.id,
                                    ad: k.name,
                                  ),
                                ),
                              );
                              if (mounted) await _load();
                            },
                          ),
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
