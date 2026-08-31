import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/device_notification_service.dart';
import '../services/fcm_push_service.dart';

/// Ay/güneş ikonunun yanında duran uygulama içi bildirim çanı.
class NotificationBellButton extends StatefulWidget {
  final ApiService api;
  final VoidCallback? onOpenTasks;

  const NotificationBellButton({
    super.key,
    required this.api,
    this.onOpenTasks,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  Timer? _poll;
  int _unread = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _cek(toast: false);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _cek());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<NotificationInbox?> _cek({bool toast = true}) async {
    try {
      final inbox = await widget.api.fetchNotifications();
      if (!mounted) return inbox;
      final onceki = _unread;
      final ilk = !_ready;
      setState(() {
        _unread = inbox.unread;
        _ready = true;
      });
      if (toast && !ilk && inbox.unread > onceki) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Size yeni bir görev atandı.')),
        );
        if (!FcmPushService.aktif) {
          final yeni = inbox.items.where((e) => !e.isRead).toList();
          final son = yeni.isNotEmpty ? yeni.first : null;
          DeviceNotificationService.gorevAtandiGoster(
            baslik: son?.title,
            govde: son?.body,
          );
        }
      }
      return inbox;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ac() async {
    final inbox = await _cek(toast: false) ?? const NotificationInbox();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return _BildirimListesi(
          inbox: inbox,
          onMarkAll: () async {
            await widget.api.markAllNotificationsRead();
            if (ctx.mounted) Navigator.pop(ctx);
            await _cek(toast: false);
          },
          onTap: (item) async {
            if (!item.isRead) {
              await widget.api.markNotificationRead(item.id);
            }
            if (ctx.mounted) Navigator.pop(ctx);
            await _cek(toast: false);
            widget.onOpenTasks?.call();
          },
        );
      },
    );
    await _cek(toast: false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bildirimler',
      onPressed: _ac,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text(_unread > 9 ? '9+' : '$_unread'),
        child: const Icon(Icons.notifications_rounded),
      ),
    );
  }
}

class _BildirimListesi extends StatelessWidget {
  final NotificationInbox inbox;
  final Future<void> Function() onMarkAll;
  final Future<void> Function(NotificationItem item) onTap;

  const _BildirimListesi({
    required this.inbox,
    required this.onMarkAll,
    required this.onTap,
  });

  String _zaman(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final sn = DateTime.now().difference(t.toLocal()).inSeconds;
    if (sn < 45) return 'Az önce';
    if (sn < 3600) return '${sn ~/ 60} dk önce';
    if (sn < 86400) return '${sn ~/ 3600} sa önce';
    return '${sn ~/ 86400} gün önce';
  }

  @override
  Widget build(BuildContext context) {
    final items = inbox.items;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bildirimler',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (inbox.unread > 0)
                  TextButton(
                    onPressed: onMarkAll,
                    child: const Text('Tümünü okundu işaretle'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Yeni bildiriminiz yok.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (context, i) {
                    final b = items[i];
                    final kim = (b.actorName ?? '').trim();
                    final zaman = _zaman(b.createdAt);
                    final meta = [
                      if (kim.isNotEmpty) '$kim atadı',
                      if (zaman.isNotEmpty) zaman,
                    ].join(' · ');
                    return ListTile(
                      onTap: () => onTap(b),
                      tileColor: b.isRead
                          ? null
                          : AppColors.accent.withValues(alpha: 0.08),
                      title: Text(
                        b.title,
                        style: TextStyle(
                          color: AppColors.text,
                          fontWeight: b.isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if ((b.body ?? '').trim().isNotEmpty) b.body!.trim(),
                          if (meta.isNotEmpty) meta,
                        ].join('\n'),
                        style: const TextStyle(color: AppColors.muted, height: 1.35),
                      ),
                      isThreeLine:
                          (b.body ?? '').trim().isNotEmpty && meta.isNotEmpty,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
