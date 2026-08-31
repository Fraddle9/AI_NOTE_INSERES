import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/meeting_card.dart';
import '../widgets/meeting_detail_sheet.dart';

class KurumDetayScreen extends StatefulWidget {
  final ApiService api;
  final int? id;
  final String? ad;

  const KurumDetayScreen({super.key, required this.api, this.id, this.ad});

  @override
  State<KurumDetayScreen> createState() => _KurumDetayScreenState();
}

class _KurumDetayScreenState extends State<KurumDetayScreen> {
  bool _loading = true;
  String? _error;
  InstitutionDetail? _detay;
  List<AnalysisRecord> _gorusmeler = const [];
  List<Product> _products = const [];
  Future<void>? _inflightLoad;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() {
    return _inflightLoad ??= _fetch().whenComplete(() => _inflightLoad = null);
  }

  Future<void> _fetch() async {
    try {
      final detay = await widget.api.fetchInstitutionDetail(id: widget.id, ad: widget.ad);
      List<AnalysisRecord> gorusmeler = const [];
      List<Product> products = _products;
      try {
        final all = await widget.api.fetchAnalyses();
        final ad = detay.kurumAdi.trim().toLowerCase();
        gorusmeler = all
            .where((r) => (r.kurumAdi ?? '').trim().toLowerCase() == ad)
            .toList();
      } catch (_) {}
      try {
        products = await widget.api.fetchProducts();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _detay = detay;
        _gorusmeler = gorusmeler;
        _products = products;
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

  String _tarih(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy').format(parsed.toLocal());
  }

  Future<void> _openMeeting(AnalysisRecord record) async {
    final changed = await showMeetingDetailSheet(
      context: context,
      api: widget.api,
      products: _products,
      record: record,
    );
    if (changed) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _detay;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text((d?.kurumAdi ?? widget.ad ?? 'Kurum detayı').toUpperCase()),
      ),
      body: AppRefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading && d == null)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else ...[
              _Field(label: 'Kurum türü / iletişim', value: d?.kurumTuru ?? '—'),
              _Field(label: 'Son görüşme tarihi', value: _tarih(d?.sonGorusmeTarihi)),
              _Field(
                label: 'Görüşme durumu',
                value: d?.gorusmeDurumu ?? '—',
                color: AppTheme.statusColor(d?.gorusmeDurumu),
              ),
              _Field(
                label: 'Süreç tipi',
                value: AnalysisRecord.normalizeSurecTipi(d?.surecTipi),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İLGİLENİLEN ÜRÜNLER',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (d?.ilgilenilenUrunler.isNotEmpty ?? false)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: d!.ilgilenilenUrunler
                                .map(
                                  (ad) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(
                                      ad,
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          )
                        else
                          const Text('—', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              _Field(
                label: 'Geçmiş görüşme notu',
                value: (d?.gecmisNot ?? '').trim().isEmpty
                    ? 'Kayıtlı görüşme notu yok.'
                    : d!.gecmisNot!.trim(),
              ),
              if (_gorusmeler.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'GÖRÜŞME KAYITLARI',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                ..._gorusmeler.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MeetingCard(
                      record: r,
                      onOpen: () => _openMeeting(r),
                      onEdit: () => _openMeeting(r),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _Field({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color ?? AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
