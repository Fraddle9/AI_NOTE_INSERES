import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../screens/kurum_detay_screen.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'edit_form_sheet.dart';

Future<bool> showMeetingDetailSheet({
  required BuildContext context,
  required ApiService api,
  required List<Product> products,
  required AnalysisRecord record,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => MeetingDetailSheet(api: api, products: products, record: record),
  );
  return changed == true;
}

class MeetingDetailSheet extends StatefulWidget {
  final ApiService api;
  final List<Product> products;
  final AnalysisRecord record;

  const MeetingDetailSheet({
    super.key,
    required this.api,
    required this.products,
    required this.record,
  });

  @override
  State<MeetingDetailSheet> createState() => _MeetingDetailSheetState();
}

class _MeetingDetailSheetState extends State<MeetingDetailSheet> {
  late AnalysisRecord _record;
  bool _changed = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _loading = _record.gorevler.isEmpty;
    Future.microtask(_yenile);
  }

  Future<void> _yenile() async {
    try {
      final fresh = await widget.api.fetchAnalysis(_record.id);
      if (!mounted) return;
      setState(() {
        _record = fresh;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _tarih(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }

  Future<void> _edit() async {
    final saved = await showEditFormSheet(
      context: context,
      api: widget.api,
      products: widget.products,
      record: _record,
    );
    if (saved != true || !mounted) return;
    try {
      final fresh = await widget.api.fetchAnalysis(_record.id);
      setState(() {
        _record = fresh;
        _changed = true;
      });
    } catch (_) {
      setState(() => _changed = true);
    }
  }

  Future<void> _delete() async {
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
    await widget.api.deleteAnalysis(_record.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _openKurum() async {
    final ad = (_record.kurumAdi ?? '').trim();
    if (ad.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KurumDetayScreen(api: widget.api, ad: ad),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durum = AnalysisRecord.normalizeDurum(_record.durum);
    final not = (_record.notIcerigi ?? '').trim();
    final kurum = (_record.kurumAdi ?? '').trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
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
                'KURUM',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                kurum.isEmpty ? 'Kurum belirtilmedi' : kurum,
                style: const TextStyle(
                  color: Color(0xFF6FC3DF),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _Field(label: 'Tarih', value: _tarih(_record.tarih)),
              const SizedBox(height: 2),
              const Text(
                'ÜRÜN VE SÜREÇ',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._record.urunRozetleri.map((ad) => _ProductBadge(label: ad)),
                  _SubscriptionBadge(
                    label: AnalysisRecord.normalizeSurecTipi(_record.surecTipi ?? _record.abonelikTipi),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'GÖRÜŞME DURUMU',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              // Durum artık burada DEĞİŞTİRİLEMEZ (salt okunur rozet); tek
              // değişim noktası aşağıdaki "Düzenle" butonuyla açılan formdur.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.statusColor(durum).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.statusColor(durum).withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppTheme.statusIcon(durum), size: 14, color: AppTheme.statusColor(durum)),
                      const SizedBox(width: 5),
                      Text(
                        durum,
                        style: TextStyle(
                          color: AppTheme.statusColor(durum),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'GEÇMİŞ GÖRÜŞME NOTU',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                not.isEmpty ? 'Kayıtlı görüşme notu yok.' : not,
                style: const TextStyle(color: AppColors.text, height: 1.4, fontSize: 14),
              ),
              const SizedBox(height: 20),
              const Text(
                'BU GÖRÜŞMEDEN ÇIKAN GÖREVLER',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_record.gorevler.isEmpty)
                const Text(
                  'Bu görüşme için AI tarafından çıkarılan bir görev bulunmuyor.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                )
              else
                ..._record.gorevler.map((g) {
                  final gorevKurum = (g.kurumAdi ?? kurum).trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          g.tamamlandi
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: g.tamamlandi ? AppColors.olumlu : AppColors.muted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gorevKurum.isEmpty ? 'Kurum belirtilmedi' : gorevKurum,
                                style: const TextStyle(
                                  color: Color(0xFF6FC3DF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                g.baslik,
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  height: 1.3,
                                  decoration: g.tamamlandi
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if ((g.assignedUserName ?? '').isNotEmpty)
                                Text(
                                  g.assignedUserName!,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 20),
              if (kurum.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _openKurum,
                  icon: const Icon(Icons.account_balance_rounded),
                  label: const Text('Kurum detayını aç'),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Düzenle'),
              ),
              TextButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Sil'),
                style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _changed),
                child: const Text('Kapat'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detay ekranında ürün bilgisini belirgin bir çip olarak gösterir
/// (bkz. `MeetingCard` içindeki eşdeğeri).
class _ProductBadge extends StatelessWidget {
  final String label;

  const _ProductBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// "Deneme" / "Abonelik" / "Hiçbiri" süreç tipini ürün rozetinin yanında gösterir.
class _SubscriptionBadge extends StatelessWidget {
  final String label;

  const _SubscriptionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      SurecTipi.deneme => AppColors.beklemede,
      SurecTipi.abonelik => AppColors.accentBlue,
      _ => AppColors.muted,
    };
    final icon = switch (label) {
      SurecTipi.deneme => Icons.hourglass_top_rounded,
      SurecTipi.abonelik => Icons.verified_rounded,
      _ => Icons.remove_circle_outline_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
