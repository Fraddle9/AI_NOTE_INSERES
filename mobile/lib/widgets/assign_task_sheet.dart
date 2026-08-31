import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<bool> showAssignTaskSheet({
  required BuildContext context,
  required ApiService api,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: AssignTaskSheet(api: api),
      );
    },
  );
  return saved == true;
}

class AssignTaskSheet extends StatefulWidget {
  final ApiService api;

  const AssignTaskSheet({super.key, required this.api});

  @override
  State<AssignTaskSheet> createState() => _AssignTaskSheetState();
}

class _AssignTaskSheetState extends State<AssignTaskSheet> {
  final _baslik = TextEditingController();
  List<Product> _urunler = const [];
  List<Map<String, dynamic>> _calisanlar = const [];
  int? _urunId;
  int? _calisanId;
  bool _loadingUrun = true;
  bool _loadingCalisan = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUrunler();
  }

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<void> _loadUrunler() async {
    setState(() {
      _loadingUrun = true;
      _error = null;
    });
    try {
      final urunler = await widget.api.fetchProducts();
      if (!mounted) return;
      setState(() {
        _urunler = urunler;
        _loadingUrun = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUrun = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadCalisanlar(int urunId) async {
    setState(() {
      _loadingCalisan = true;
      _calisanId = null;
      _calisanlar = const [];
      _error = null;
    });
    try {
      final liste = await widget.api.fetchProductUsers(urunId);
      if (!mounted) return;
      setState(() {
        _calisanlar = liste;
        _loadingCalisan = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCalisan = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    final baslik = _baslik.text.trim();
    if (_urunId == null) {
      setState(() => _error = 'Ürün seçin.');
      return;
    }
    if (_calisanId == null) {
      setState(() => _error = 'Personel seçin.');
      return;
    }
    if (baslik.isEmpty) {
      setState(() => _error = 'Görev metnini yazın.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.assignTask(
        baslik: baslik,
        assignedUserId: _calisanId!,
        urunId: _urunId!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Personele Görev Ata',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingUrun)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              DropdownButtonFormField<int>(
                initialValue: _urunId,
                decoration: const InputDecoration(labelText: 'Ürün'),
                items: _urunler
                    .map(
                      (u) => DropdownMenuItem<int>(
                        value: u.id,
                        child: Text(u.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() => _urunId = v);
                  if (v != null) _loadCalisanlar(v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _calisanId,
                decoration: InputDecoration(
                  labelText: 'Personel',
                  hintText: _urunId == null ? 'Önce ürün seçin' : null,
                ),
                items: _calisanlar
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c['id'] as int?,
                        child: Text(
                          (c['ad_soyad'] ?? c['kullanici_adi'] ?? '—').toString(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (_loadingCalisan || _urunId == null)
                    ? null
                    : (v) => setState(() => _calisanId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baslik,
                decoration: const InputDecoration(
                  labelText: 'Görev',
                  hintText: 'Örn: Teklif maili gönder',
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.olumsuz, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_saving || _loadingUrun) ? null : _save,
              child: Text(_saving ? 'Atanıyor...' : 'Görevi Ata'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }
}
