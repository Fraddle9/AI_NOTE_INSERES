import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// [gorusme]: kurum / ürün / durum / süreç özeti, transkript yok.
/// [not]: not metni öne çıkar; dokununca görüşme detayı açılır.
enum MeetingCardMode { gorusme, not }

class MeetingCard extends StatelessWidget {
  final AnalysisRecord record;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  /// true olduğunda ve record.kullaniciAdi doluysa personel adı badge gösterilir
  final bool showUserBadge;
  final MeetingCardMode mode;

  const MeetingCard({
    super.key,
    required this.record,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    this.showUserBadge = false,
    this.mode = MeetingCardMode.gorusme,
  });


  @override
  Widget build(BuildContext context) {
    final durum = AnalysisRecord.normalizeDurum(record.durum);
    final color = AppTheme.statusColor(durum);
    final urunler = record.urunRozetleri;
    final surecTipi = AnalysisRecord.normalizeSurecTipi(record.surecTipi ?? record.abonelikTipi);
    final not = (record.notIcerigi ?? '').trim();
    final kurum = (record.kurumAdi ?? 'Kurum belirtilmedi').trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen ?? onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'KURUM',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                kurum.isEmpty ? 'Kurum belirtilmedi' : kurum,
                                style: const TextStyle(
                                  color: Color(0xFF6FC3DF),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Durum artık listede DÜZENLENEMEZ (salt okunur); tek
                        // değişim noktası "Düzenle" ile açılan formdur.
                        _Badge(label: durum, color: color, icon: AppTheme.statusIcon(durum)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ...urunler.map((ad) => _ProductChip(label: ad)),
                        if (mode == MeetingCardMode.gorusme)
                          _SubscriptionChip(label: surecTipi),
                        _MetaChip(
                          icon: Icons.schedule_outlined,
                          label: _formatDate(record.tarih),
                        ),
                        if (showUserBadge && (record.kullaniciAdi ?? '').isNotEmpty)
                          _MetaChip(
                            icon: Icons.person_outline,
                            label: record.kullaniciAdi!,
                            color: const Color(0xFF6FC3DF),
                          ),
                      ],
                    ),
                    if (mode == MeetingCardMode.not) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'NOT',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        not.isEmpty ? 'Not içeriği yok' : not,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Dokunarak görüşme detayını açın',
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: onEdit ?? onOpen,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Sil'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Tarih yok';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm').format(parsed.toLocal());
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ürün bilgisini diğer düz metinlerden ayırmak için belirgin, oval ve
/// hafif renkli bir çip (badge) olarak gösterir.
class _ProductChip extends StatelessWidget {
  final String label;

  const _ProductChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Deneme" / "Abonelik" / "Hiçbiri" süreç tipini ürün çipinin yanında, net bir
/// renkle ayırt edilebilir şekilde gösterir.
class _SubscriptionChip extends StatelessWidget {
  final String label;

  const _SubscriptionChip({required this.label});

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final labelColor = color ?? AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color != null
            ? color!.withValues(alpha: 0.1)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: color != null
            ? Border.all(color: color!.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: labelColor),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

      ),
    );
  }
}
