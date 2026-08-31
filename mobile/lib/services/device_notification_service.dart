import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Telefonun bildirim çekmecesine (Android) / bildirim merkezine sistem bildirimi.
class DeviceNotificationService {
  DeviceNotificationService._();

  static final FlutterLocalNotificationsPlugin _eklenti =
      FlutterLocalNotificationsPlugin();
  static bool _hazir = false;
  static int _sonId = 0;

  static const _androidKanal = AndroidNotificationDetails(
    'gorev_atama',
    'Görev atamaları',
    channelDescription: 'Size görev atandığında bildirim',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_hazir) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _eklenti.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _eklenti
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'gorev_atama',
            'Görev atamaları',
            description: 'Size görev atandığında bildirim',
            importance: Importance.high,
          ),
        );
    _hazir = true;
    await izinIste();
  }

  static Future<void> izinIste() async {
    try {
      await _eklenti
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
    try {
      final durum = await Permission.notification.status;
      if (!durum.isGranted && !durum.isPermanentlyDenied) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  static Future<void> gorevAtandiGoster({
    String? baslik,
    String? govde,
  }) async {
    if (!_hazir) await init();
    _sonId = (_sonId + 1) % 10000;
    await _eklenti.show(
      _sonId,
      (baslik ?? '').trim().isEmpty ? 'Size yeni bir görev atandı' : baslik!.trim(),
      (govde ?? '').trim().isEmpty ? 'CRM Analiz Portalı' : govde!.trim(),
      const NotificationDetails(
        android: _androidKanal,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
