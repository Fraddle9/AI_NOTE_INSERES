import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/list_query.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/list_query_bar.dart';

class UrunlerScreen extends StatefulWidget {
  final ApiService api;

  const UrunlerScreen({super.key, required this.api});

  @override
  State<UrunlerScreen> createState() => _UrunlerScreenState();
}

class _UrunlerScreenState extends State<UrunlerScreen> {
  static const _sortOptions = [
    ListSortOption('ad_asc', 'Ad A–Z'),
    ListSortOption('ad_desc', 'Ad Z–A'),
    ListSortOption('kod_asc', 'Kod A–Z'),
  ];

  bool _loading = true;
  bool _isAdmin = false;
  String? _error;
  List<Product> _items = const [];
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
      final items = await widget.api.fetchProducts();
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

  List<Product> get _visible {
    final filtered = _items
        .where((u) => matchesQuery(_search.text, [u.name, u.code]))
        .toList();
    filtered.sort((a, b) {
      switch (_sort) {
        case 'ad_desc':
          return compareText(a.name, b.name, desc: true);
        case 'kod_asc':
          return compareText(a.code, b.code);
        case 'ad_asc':
        default:
          return compareText(a.name, b.name);
      }
    });
    return filtered;
  }

  Future<void> _addUrun() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni ürün'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ürün adı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kod (isteğe bağlı)',
                hintText: 'Boş bırakılırsa addan üretilir',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim();
    nameCtrl.dispose();
    codeCtrl.dispose();
    if (saved != true || name.isEmpty) return;
    try {
      await widget.api.createProduct(name: name, code: code.isEmpty ? null : code);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteUrun(Product u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünü kaldır'),
        content: Text('${u.name} listeden kaldırılsın mı?'),
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
      await widget.api.deleteProduct(u.id);
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
        title: const Text('ÜRÜNLER'),
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _addUrun,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          ListQueryBar(
            controller: _search,
            hint: 'Ürün adı veya kod ara…',
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
                          Text(_error!, textAlign: TextAlign.center)
                        else
                          Text(
                            _items.isEmpty
                                ? 'Henüz ürün yok'
                                : 'Aramayla eşleşen ürün yok',
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
                        final u = visible[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2_outlined, color: AppColors.accentBlue),
                            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(u.code, style: const TextStyle(color: AppColors.muted)),
                            trailing: _isAdmin
                                ? IconButton(
                                    tooltip: 'Kaldır',
                                    onPressed: () => _deleteUrun(u),
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.olumsuz),
                                  )
                                : null,
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
