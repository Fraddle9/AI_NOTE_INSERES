import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Koyu/açık tema tercihini tutan tekil (singleton) kontrolcü.
///
/// Web tarafındaki `localStorage` tabanlı tema tercihiyle BİREBİR aynı
/// mantık: tercih cihazda saklanır (`shared_preferences`), uygulama açılışında
/// geri yüklenir, [isLight] bir [ValueNotifier] olduğu için değiştiğinde
/// dinleyen tüm widget'lar (bkz. `main.dart`, `home_screen.dart`) otomatik
/// olarak yeniden çizilir.
class ThemeController {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const _prefsKey = 'crm_tema_acik';

  final ValueNotifier<bool> isLight = ValueNotifier<bool>(false);

  /// Uygulama açılışında (bkz. `main()`), CSS yüklenmeden önce tema
  /// uygulanan web'deki FOUC-önleyici scriptin karşılığı: ilk frame
  /// çizilmeden ÖNCE tercih diskten okunur.
  Future<void> yukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isLight.value = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      // Tercih okunamazsa (ör. ilk kurulum) sessizce varsayılan (koyu) kalır.
    }
  }

  Future<void> toggle() async {
    isLight.value = !isLight.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, isLight.value);
    } catch (_) {}
  }
}
