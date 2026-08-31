import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/device_notification_service.dart';
import 'services/fcm_push_service.dart';
import 'theme/app_theme.dart';
import 'theme/invert_colors.dart';
import 'theme/theme_controller.dart';
import 'widgets/starfield.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> _oturumSuresiDoldu() async {
  await AuthService.logout();
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.onUnauthorized = _oturumSuresiDoldu;
  // Web'deki FOUC-önleyici satır içi script ile aynı amaç: ilk kare
  // çizilmeden önce kaydedilmiş tema tercihi diskten okunur.
  await ThemeController.instance.yukle();
  await DeviceNotificationService.init();
  await FcmPushService.baslat();
  if (await AuthService.isAuthenticated()) {
    await FcmPushService.tokenuKaydet();
  }
  runApp(const AinoteApp());
}

class AinoteApp extends StatelessWidget {
  const AinoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.instance.isLight,
      builder: (context, isLight, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: isLight ? Colors.white : AppColors.background,
            systemNavigationBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          ),
          child: MaterialApp(
            title: 'CRM Analiz',
            navigatorKey: rootNavigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            builder: (context, child) {
              // Açık tema, web'deki `filter: invert(1) hue-rotate(180deg)`
              // ile BİREBİR aynı yöntemle: uygulama içeriği ters çevrilir.
              // Yıldızlı arka plan İSTİSNA: sürekli dönen (twinkle)
              // animasyonu bir `ColorFiltered` katmanının ALTINDA donduğu
              // için, bilerek bu filtrenin DIŞINDA tutulup rengini [isLight]
              // parametresiyle kendisi seçiyor (bkz. starfield.dart).
              final appContent = child ?? const SizedBox.shrink();
              return Stack(
                fit: StackFit.expand,
                children: [
                  StarfieldBackdrop(isLight: isLight),
                  isLight ? InvertColors(child: appContent) : appContent,
                ],
              );
            },
            // AuthWrapper başlangıçta token kontrolü yapar,
            // token varsa HomeScreen yoksa LoginScreen açar.
            home: const AuthWrapper(),
          ),
        );
      },
    );
  }
}

/// Splash/Auth kontrolcüsü.
///
/// Uygulama ilk açıldığında SharedPreferences'ten token okur.
/// Okunurken yükleme göstergesi gösterir, sonra yönlendirir.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _kontrol();
  }

  Future<void> _kontrol() async {
    final girisYapildi = await AuthService.isAuthenticated();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => girisYapildi ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Token okunurken gösterilen geçici ekran
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt_rounded, size: 52, color: Color(0xFF6FC3DF)),
            const SizedBox(height: 20),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(Color(0xFF6FC3DF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
