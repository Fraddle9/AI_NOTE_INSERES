import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<bool> showEditFormSheet({
  required BuildContext context,
  required ApiService api,
  required List<Product> products,
  AnalysisRecord? record,
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
        child: EditFormSheet(api: api, products: products, record: record),
      );
    },
  );
  return saved == true;
}

class EditFormSheet extends StatefulWidget {
  final ApiService api;
  final List<Product> products;
  final AnalysisRecord? record;

  const EditFormSheet({
    super.key,
    required this.api,
    required this.products,
    this.record,
  });

  @override
  State<EditFormSheet> createState() => _EditFormSheetState();
}

class _EditFormSheetState extends State<EditFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _kurum;
  late final TextEditingController _not;
  late String _durum;
  late String _surecTipi;
  // Bir görüşmede AYNI ANDA birden fazla ürün geçebilir (ör. hem "Piri AI"
  // hem "Piri Keşif Aracı"); bu yüzden tekli dropdown yerine kod bazlı
  // çoklu-seçim (multi-select) kullanılır. `LinkedHashSet`in Dart'taki
  // varsayılan davranışı sayesinde ekleme sırası korunur, ilk seçilen ürün
  // "birincil" ürün (urun_kodu/urun_adi) olarak kaydedilir.
  Set<String> _urunKodlari = {};
  String? _error;
  bool _saving = false;
  bool _hydrating = false;
  int _formGen = 0;
  late List<Product> _products;
  List<String> _surecTipleri = SurecTipi.tumDegerler;
  List<String> _durumlar = GorusmeDurumu.tumDegerler;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final kayit = widget.record;
    _kurum = TextEditingController(text: kayit?.kurumAdi ?? '');
    _not = TextEditingController(text: kayit?.notIcerigi ?? '');
    _durum = AnalysisRecord.normalizeDurum(kayit?.durum);
    _surecTipi = AnalysisRecord.normalizeSurecTipi(kayit?.surecTipi ?? kayit?.abonelikTipi);
    _products = List<Product>.from(widget.products);
    _urunKodlari = kayit == null ? {} : _urunKodlariniCoz(kayit);
    _hydrateFromServer();
  }

  /// Kayıttaki `ilgilenilenUrunler` (İSİM listesi) ve `urunKodu` (birincil
  /// ürün kodu) alanlarını, çoklu-seçim çiplerinin işaretli gösterebilmesi
  /// için mevcut katalogdaki ürün KODLARINA çözer. Katalogda karşılığı
  /// olmayan (ör. sonradan pasifleştirilmiş) bir kod varsa, seçim
  /// kaybolmasın diye `_products`'a geçici bir placeholder olarak eklenir
  /// (eski tekli-seçim davranışıyla birebir aynı mantık).
  Set<String> _urunKodlariniCoz(AnalysisRecord kayit) {
    final secili = <String>{};
    String norm(String s) => s
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .toLowerCase();
    for (final ad in kayit.ilgilenilenUrunler) {
      final adTemiz = norm(ad);
      if (adTemiz.isEmpty) continue;
      for (final p in _products) {
        if (norm(p.name) == adTemiz || norm(p.code) == adTemiz) {
          secili.add(p.code);
          break;
        }
      }
    }
    final ilkKod = (kayit.urunKodu ?? '').trim();
    if (ilkKod.isNotEmpty) {
      secili.add(ilkKod);
      if (!_products.any((p) => p.code == ilkKod)) {
        _products = [
          ..._products,
          Product(id: -1, code: ilkKod, name: (kayit.urunAdi ?? ilkKod).trim()),
        ];
      }
    }
    return secili;
  }

  Future<void> _hydrateFromServer() async {
    if (_hydrating) return;
    _hydrating = true;
    try {
      final freshProducts = await widget.api.fetchProducts();
      // Süreç tipi seçenekleri backend'in katı Enum'undan dinamik çekilir;
      // istek başarısız olursa `SurecTipi.tumDegerler` fallback'i (zaten
      // `_surecTipleri`'nin başlangıç değeri) korunur.
      List<String> freshSurecTipleri = _surecTipleri;
      try {
        final cekilen = await widget.api.fetchSurecTipleri();
        if (cekilen.isNotEmpty) freshSurecTipleri = cekilen;
      } catch (_) {}
      List<String> freshDurumlar = _durumlar;
      try {
        final cekilenDurum = await widget.api.fetchGorusmeDurumlari();
        if (cekilenDurum.isNotEmpty) freshDurumlar = cekilenDurum;
      } catch (_) {}
      AnalysisRecord? fresh = widget.record;
      if (widget.record != null) {
        fresh = await widget.api.fetchAnalysis(widget.record!.id);
      }
      if (!mounted) return;
      setState(() {
        _products = freshProducts;
        _surecTipleri = freshSurecTipleri;
        _durumlar = freshDurumlar;
        if (fresh != null) {
          _kurum.text = fresh.kurumAdi ?? _kurum.text;
          _not.text = fresh.notIcerigi ?? _not.text;
          _durum = AnalysisRecord.normalizeDurum(fresh.durum);
          _surecTipi = AnalysisRecord.normalizeSurecTipi(fresh.surecTipi ?? fresh.abonelikTipi);
          _urunKodlari = _urunKodlariniCoz(fresh);
        }
        if (!_surecTipleri.contains(_surecTipi)) {
          _surecTipi = _surecTipleri.isNotEmpty ? _surecTipleri.first : SurecTipi.hicbiri;
        }
        if (!_durumlar.contains(_durum)) {
          _durum = _durumlar.isNotEmpty ? _durumlar.first : GorusmeDurumu.beklemede;
        }
        _formGen++;
      });
    } catch (_) {
    } finally {
      _hydrating = false;
    }
  }

  @override
  void dispose() {
    _kurum.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final kurum = _kurum.text.trim();
    // `_urunKodlari` sırayı korur (bkz. alan tanımındaki not); ilk seçilen
    // ürün "birincil" ürün (urun_kodu/urun_adi) olarak gönderilir, TÜM
    // seçili ürünler ise `ilgilenilen_urunler` dizisine eksiksiz yazılır.
    final secilenUrunler = <Product>[
      for (final kod in _urunKodlari)
        for (final p in _products)
          if (p.code == kod) p,
    ];
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = AnalysisWrite(
        kurumAdi: kurum,
        urunKodu: secilenUrunler.isEmpty ? null : secilenUrunler.first.code,
        urunAdi: secilenUrunler.isEmpty ? null : secilenUrunler.first.name,
        ilgilenilenUrunAdlari: secilenUrunler.map((p) => p.name).toList(),
        durum: _durum,
        surecTipi: _surecTipi,
        abonelikTipi: _surecTipi,
        notIcerigi: _not.text.trim(),
      );
      if (_isEdit) {
        await widget.api.updateAnalysis(widget.record!.id, payload);
      } else {
        await widget.api.createAnalysis(payload);
      }
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

  String get _tarihEtiketi {
    final iso = widget.record?.tarih;
    if (iso == null || iso.isEmpty) return 'Yeni kayıt';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
              Text(
                _isEdit ? 'Kaydı Düzenle' : 'Yeni Görüşme',
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Tarih'),
                child: Text(_tarihEtiketi, style: const TextStyle(color: AppColors.text)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _kurum,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Kurum Adı',
                  hintText: 'Örn: Gazi Üniversitesi',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kurum adı zorunludur.' : null,
              ),
              const SizedBox(height: 12),
              // Ürün alanı ÇOKLU SEÇİM destekler: bir görüşmede birden fazla
              // ürün geçmiş olabilir (ör. hem "Piri AI" hem "Piri Keşif
              // Aracı"); tekli dropdown kullanılsaydı ikinci ürün her
              // düzenleme/kayıtta sessizce kaybolurdu.
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Ürün(ler)'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _products.where((p) => p.code.isNotEmpty).isEmpty
                      ? const Text(
                          'Kayıtlı ürün yok',
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        )
                      : Wrap(
                          key: ValueKey('urun-$_formGen'),
                          spacing: 8,
                          runSpacing: 8,
                          children: _products.where((p) => p.code.isNotEmpty).map((p) {
                            final secili = _urunKodlari.contains(p.code);
                            return FilterChip(
                              label: Text(p.name.isEmpty ? p.code : p.name),
                              selected: secili,
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _urunKodlari.add(p.code);
                                } else {
                                  _urunKodlari.remove(p.code);
                                }
                              }),
                              showCheckmark: false,
                              backgroundColor: AppColors.surfaceAlt,
                              selectedColor: AppColors.accent.withValues(alpha: 0.24),
                              side: BorderSide(
                                color: secili
                                    ? AppColors.accent.withValues(alpha: 0.7)
                                    : AppColors.border,
                              ),
                              labelStyle: TextStyle(
                                color: secili ? AppColors.accent : AppColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('surec-$_formGen'),
                initialValue: _surecTipleri.contains(_surecTipi) ? _surecTipi : _surecTipleri.first,
                dropdownColor: AppColors.surfaceAlt,
                decoration: const InputDecoration(labelText: 'Süreç Tipi'),
                items: _surecTipleri
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _surecTipi = v);
                },
              ),
              const SizedBox(height: 12),
              // Durumun tek değiştirilebileceği yer burasıdır (liste/kart/detay
              // ekranlarındaki durum rozetleri artık salt okunurdur).
              DropdownButtonFormField<String>(
                key: ValueKey('durum-$_formGen'),
                initialValue: _durumlar.contains(_durum) ? _durum : _durumlar.first,
                dropdownColor: AppColors.surfaceAlt,
                decoration: const InputDecoration(labelText: 'Durum'),
                items: _durumlar
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _durum = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _not,
                minLines: 4,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Detaylı Notlar',
                  hintText: 'Görüşme notu...',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.olumsuz, fontSize: 13)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Kaydediliyor...' : (_isEdit ? 'Kaydet' : 'Kaydet')),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
