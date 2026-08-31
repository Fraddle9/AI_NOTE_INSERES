import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ListSortOption {
  final String id;
  final String label;

  const ListSortOption(this.id, this.label);
}

/// Arama kutusu + sıralama menüsü (web’deki tablo araç çubuğunun mobil karşılığı).
class ListQueryBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String sortValue;
  final List<ListSortOption> sortOptions;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onQueryChanged;
  final int? shownCount;
  final int? totalCount;

  const ListQueryBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.sortValue,
    required this.sortOptions,
    required this.onSortChanged,
    required this.onQueryChanged,
    this.shownCount,
    this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    ListSortOption? current;
    for (final o in sortOptions) {
      if (o.id == sortValue) {
        current = o;
        break;
      }
    }
    current ??= sortOptions.isEmpty ? null : sortOptions.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onQueryChanged(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Temizle',
                            onPressed: () {
                              controller.clear();
                              onQueryChanged();
                            },
                            icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                          ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Sırala',
                initialValue: sortValue,
                onSelected: onSortChanged,
                itemBuilder: (_) => [
                  for (final o in sortOptions)
                    PopupMenuItem(
                      value: o.id,
                      child: Text(o.label),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort_rounded, size: 20, color: AppColors.accent),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 92),
                        child: Text(
                          current?.label ?? 'Sırala',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (shownCount != null && totalCount != null) ...[
            const SizedBox(height: 6),
            Text(
              shownCount == totalCount
                  ? '$totalCount kayıt'
                  : '$shownCount / $totalCount kayıt',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
