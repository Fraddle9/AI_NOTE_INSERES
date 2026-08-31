import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum CrmNavSection {
  anaSayfa,
  gorusmeler,
  notlarim,
  gorevler,
  kurumlar,
  urunler,
  veritabani,
}

/// Sol menü: drawer (dar ekran) veya kalıcı panel (geniş ekran).
class AppSidebar extends StatelessWidget {
  final CrmNavSection selected;
  final AuthUser? user;
  final int notSayisi;
  final int gorevSayisi;
  final int yoneticiGorevSayisi;
  final ValueChanged<CrmNavSection> onSelect;
  final VoidCallback onNotEkle;
  final VoidCallback? onChangePassword;
  final VoidCallback? onEditProfile;
  final VoidCallback? onLogout;

  const AppSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onNotEkle,
    this.onChangePassword,
    this.onEditProfile,
    this.user,
    this.notSayisi = 0,
    this.gorevSayisi = 0,
    this.yoneticiGorevSayisi = 0,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSolid.withValues(alpha: 0.96),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CRM',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.accent,
                          child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF0B1020)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user!.gorunenAd,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                user!.isAdmin ? 'Yönetici' : 'Kullanıcı',
                                style: const TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                              Text(
                                '@${user!.kullaniciAdi}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FilledButton.icon(
                onPressed: onNotEkle,
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: const Text('Not Ekle'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: AppColors.accentPurple,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'MENÜ',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _NavTile(
                    icon: Icons.dashboard_rounded,
                    label: 'Ana Sayfa',
                    selected: selected == CrmNavSection.anaSayfa,
                    onTap: () => onSelect(CrmNavSection.anaSayfa),
                  ),
                  _NavTile(
                    icon: Icons.forum_rounded,
                    label: 'Görüşmeler',
                    selected: selected == CrmNavSection.gorusmeler,
                    onTap: () => onSelect(CrmNavSection.gorusmeler),
                  ),
                  _NavTile(
                    icon: Icons.sticky_note_2_rounded,
                    label: 'Notlarım',
                    badge: notSayisi > 0 ? '$notSayisi' : null,
                    selected: selected == CrmNavSection.notlarim,
                    onTap: () => onSelect(CrmNavSection.notlarim),
                  ),
                  _NavTile(
                    icon: Icons.checklist_rounded,
                    label: 'Görevler',
                    badge: gorevSayisi > 0 ? '$gorevSayisi' : null,
                    badgeAccent: yoneticiGorevSayisi > 0,
                    selected: selected == CrmNavSection.gorevler,
                    onTap: () => onSelect(CrmNavSection.gorevler),
                  ),
                  _NavTile(
                    icon: Icons.account_balance_rounded,
                    label: 'Kurumlar',
                    selected: selected == CrmNavSection.kurumlar,
                    onTap: () => onSelect(CrmNavSection.kurumlar),
                  ),
                  if (user?.isAdmin == true)
                    _NavTile(
                      icon: Icons.inventory_2_rounded,
                      label: 'Ürünler',
                      selected: selected == CrmNavSection.urunler,
                      onTap: () => onSelect(CrmNavSection.urunler),
                    ),
                  _NavTile(
                    icon: Icons.table_chart_rounded,
                    label: 'Veritabanı',
                    selected: selected == CrmNavSection.veritabani,
                    onTap: () => onSelect(CrmNavSection.veritabani),
                  ),
                ],
              ),
            ),
            if (onEditProfile != null || onChangePassword != null || onLogout != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onEditProfile != null)
                      TextButton.icon(
                        onPressed: onEditProfile,
                        icon: const Icon(Icons.badge_outlined, size: 18),
                        label: const Text('Adımı Düzenle'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                    if (onChangePassword != null)
                      TextButton.icon(
                        onPressed: onChangePassword,
                        icon: const Icon(Icons.vpn_key_outlined, size: 18),
                        label: const Text('Şifre Değiştir'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                    if (onLogout != null)
                      TextButton.icon(
                        onPressed: onLogout,
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Çıkış Yap'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.olumsuz),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool badgeAccent;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
    this.badgeAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent;
    final border = selected ? AppColors.accent.withValues(alpha: 0.55) : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AppColors.accent : AppColors.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.muted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (badgeAccent ? AppColors.beklemede : AppColors.accent)
                          .withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (badgeAccent ? AppColors.beklemede : AppColors.accent)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: badgeAccent ? AppColors.beklemede : AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
