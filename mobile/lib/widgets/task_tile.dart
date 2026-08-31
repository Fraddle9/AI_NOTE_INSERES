import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class TaskTile extends StatelessWidget {
  final TaskItem task;
  final int? mevcutKullaniciId;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggle;

  const TaskTile({
    super.key,
    required this.task,
    this.mevcutKullaniciId,
    this.onEdit,
    this.onDelete,
    this.onToggle,
  });

  bool get _banaAtandi => task.yoneticiAtamasiMi(mevcutKullaniciId);
  bool get _sariAtama => _banaAtandi;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.beklemede;
    final borderColor = _sariAtama ? accent : AppColors.border;
    final fillColor = _sariAtama ? accent.withValues(alpha: 0.10) : Colors.transparent;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: _sariAtama ? AppColors.surfaceAlt.withValues(alpha: 0.92) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: borderColor,
          width: _sariAtama ? 1.6 : 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sariAtama)
              Container(
                width: 5,
                color: accent,
              ),
            Expanded(
              child: Column(
                children: [
                  if (_sariAtama)
                    Container(
                      width: double.infinity,
                      color: fillColor,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.assignment_ind_rounded,
                            size: 16,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _bannerText(),
                              style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ATAMA',
                              style: TextStyle(
                                color: accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 8, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: onToggle,
                          icon: Icon(
                            task.tamamlandi
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            color: task.tamamlandi
                                ? AppColors.olumlu
                                : (_sariAtama ? accent : AppColors.accent),
                          ),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onEdit,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(4, 10, 8, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (task.kurumAdi ?? '').trim().isNotEmpty
                                          ? task.kurumAdi!.trim()
                                          : 'Kurum belirtilmedi',
                                      style: const TextStyle(
                                        color: Color(0xFF6FC3DF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      task.baslik,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        decoration: task.tamamlandi
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      [
                                        if (!_banaAtandi)
                                          if ((task.kaynak ?? '').toLowerCase() == 'manuel')
                                            'Manuel'
                                          else
                                            'Görüşmeden',
                                        _formatDate(task.tarih),
                                      ].where((e) => e.isNotEmpty).join(' · '),
                                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Düzenle'),
                          style: TextButton.styleFrom(
                            foregroundColor: _sariAtama ? accent : AppColors.accent,
                          ),
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
            ),
          ],
        ),
      ),
    );
  }

  String _bannerText() {
    final kim = (task.olusturanAdi ?? '').trim();
    return kim.isNotEmpty ? 'Yöneticiden görev · $kim' : 'Yöneticiden görev';
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy').format(parsed.toLocal());
  }
}
