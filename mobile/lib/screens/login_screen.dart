import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

/// Giriş ekranı.
///
/// Projenin karanlık / yıldızlı temasıyla uyumlu, minimalist tasarım.
/// Başarılı girişte [HomeScreen]'e yönlendirir (stack temizlenerek).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _kadiCtrl     = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  final _adCtrl       = TextEditingController();
  bool _yukleniyor    = false;
  bool _sifreGizle    = true;
  bool _kayitModu     = false;
  bool _kayitAcik     = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _kayitAyarlariYukle();
  }

  Future<void> _kayitAyarlariYukle() async {
    final acik = await AuthService.fetchAllowPublicRegister();
    if (!mounted) return;
    setState(() {
      _kayitAcik = acik;
      if (!acik) _kayitModu = false;
    });
  }

  @override
  void dispose() {
    _kadiCtrl.dispose();
    _sifreCtrl.dispose();
    _adCtrl.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _yukleniyor = true; _hata = null; });

    try {
      if (_kayitModu) {
        await AuthService.register(
          _kadiCtrl.text.trim(),
          _sifreCtrl.text,
          adSoyad: _adCtrl.text.trim(),
        );
      } else {
        await AuthService.login(
          _kadiCtrl.text.trim(),
          _sifreCtrl.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString().replaceFirst('Exception: ', '');
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F30).withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Marka ──────────────────────────────────────────
            const Icon(Icons.satellite_alt_rounded, size: 48, color: Color(0xFF6FC3DF)),
            const SizedBox(height: 12),
            Text(
              'CRM Analiz Portalı',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .3,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _kayitModu ? 'Yeni hesap oluşturun' : 'Devam etmek için giriş yapın',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 32),

            if (_kayitModu) ...[
              _buildField(
                controller: _adCtrl,
                label: 'Ad Soyad',
                hint: 'Ad Soyad (isteğe bağlı)',
                prefixIcon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
            ],

            // ── Kullanıcı Adı ───────────────────────────────────
            _buildField(
              controller: _kadiCtrl,
              label: 'Kullanıcı Adı',
              hint: 'kullanici_adi',
              prefixIcon: Icons.person_outline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Kullanıcı adı gereklidir' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            // ── Şifre ───────────────────────────────────────────
            _buildField(
              controller: _sifreCtrl,
              label: 'Şifre',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline,
              obscure: _sifreGizle,
              suffixIcon: IconButton(
                icon: Icon(
                  _sifreGizle ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _sifreGizle = !_sifreGizle),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Şifre gereklidir';
                if (_kayitModu && v.length < 4) return 'Şifre en az 4 karakter olmalıdır';
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _gonder(),
            ),
            const SizedBox(height: 24),

            // ── Giriş / Kayıt Butonu ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _yukleniyor ? null : _gonder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6FC3DF),
                  foregroundColor: const Color(0xFF0D1117),
                  disabledBackgroundColor: const Color(0xFF6FC3DF).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _yukleniyor
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Color(0xFF0D1117)),
                        ),
                      )
                      : Text(
                        _kayitModu ? 'Kayıt Ol' : 'Giriş Yap',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),
            if (_kayitAcik)
              TextButton(
                onPressed: _yukleniyor
                    ? null
                    : () => setState(() {
                          _kayitModu = !_kayitModu;
                          _hata = null;
                        }),
                child: Text(
                  _kayitModu
                      ? 'Zaten hesabınız var mı? Giriş yapın'
                      : 'Hesabınız yok mu? Kayıt olun',
                  style: const TextStyle(color: Color(0xFF6FC3DF), fontSize: 13),
                ),
              ),

            // ── Hata Mesajı ─────────────────────────────────────
            if (_hata != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Color(0xFFF08080)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _hata!,
                        style: const TextStyle(
                          color: Color(0xFFF08080),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: .1,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22), fontSize: 14),
            prefixIcon: Icon(prefixIcon, size: 20, color: Colors.white38),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6FC3DF)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF08080)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF08080)),
            ),
            errorStyle: const TextStyle(color: Color(0xFFF08080)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
