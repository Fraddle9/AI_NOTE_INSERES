// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'device_notification_service.dart';

/// Uygulama kapalıyken gelen FCM mesajı için izolat giriş noktası.
/// `notification` yükü varsa Android zaten sistem bildirimi gösterir;
/// burada tekrar local notification basılmaz (çift bildirim olmasın).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Firebase Cloud Messaging. google-services.json yoksa sessizce kapanır;
/// uygulama içi çan + yerel bildirim çalışmaya devam eder.
class FcmPushService {
  FcmPushService._();

  static bool aktif = false;

  static Future<void> baslat() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('[FCM] Firebase başlatılamadı (google-services.json eksik olabilir): $e');
      aktif = false;
      return;
    }
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onMessage.listen((msg) {
        DeviceNotificationService.gorevAtandiGoster(
          baslik: msg.notification?.title,
          govde: msg.notification?.body,
        );
      });
      FirebaseMessaging.instance.onTokenRefresh.listen((jeton) {
        unawaited(_kaydet(jeton));
      });
      aktif = true;
      print('[FCM] hazır');
    } catch (e) {
      aktif = false;
      print('[FCM] izin/dinleyici kurulamadı: $e');
    }
  }

  static Future<void> tokenuKaydet() async {
    if (!aktif) return;
    try {
      final jeton = await FirebaseMessaging.instance.getToken();
      if (jeton == null || jeton.isEmpty) return;
      await _kaydet(jeton);
    } catch (e) {
      print('[FCM] jeton alınamadı: $e');
    }
  }

  static Future<void> tokenuSil() async {
    if (!aktif) return;
    try {
      final jeton = await FirebaseMessaging.instance.getToken();
      if (jeton == null || jeton.isEmpty) return;
      await ApiService().deleteDeviceToken(jeton);
    } catch (e) {
      print('[FCM] jeton silinemedi: $e');
    }
  }

  static Future<void> _kaydet(String jeton) async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    try {
      await ApiService().registerDeviceToken(jeton, platform);
      print('[FCM] jeton kaydedildi');
    } catch (e) {
      print('[FCM] jeton kaydı başarısız: $e');
    }
  }
}
