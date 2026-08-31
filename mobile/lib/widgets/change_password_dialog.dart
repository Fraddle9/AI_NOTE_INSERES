import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Oturum açmış kullanıcının kendi şifresini güncellemesi (kullanıcı adı sabit).
Future<bool?> showChangePasswordDialog(
  BuildContext context, {
  required AuthUser user,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ChangePasswordDialog(user: user),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  final AuthUser user;

  const _ChangePasswordDialog({required this.user});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _mevcutCtrl = TextEditingController();
  final _yeniCtrl = TextEditingController();
  final _tekrarCtrl = TextEditingController();
  bool _loading = false;
  bool _gizleMevcut = true;
  bool _gizleYeni = true;
  String? _hata;

  @override
  void dispose() {
    _mevcutCtrl.dispose();
    _yeniCtrl.dispose();
    _tekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final mevcut = _mevcutCtrl.text;
    final yeni = _yeniCtrl.text;
    final tekrar = _tekrarCtrl.text;

    if (mevcut.isEmpty || yeni.isEmpty || tekrar.isEmpty) {
      setState(() => _hata = 'Tüm alanları doldurun.');
      return;
    }
    if (yeni.length < 4) {
      setState(() => _hata = 'Yeni şifre en az 4 karakter olmalıdır.');
      return;
    }
    if (yeni != tekrar) {
      setState(() => _hata = 'Yeni şifreler eşleşmiyor.');
      return;
    }

    setState(() {
      _loading = true;
      _hata = null;
    });

    try {
      await AuthService.changePassword(
        mevcutSifre: mevcut,
        yeniSifre: yeni,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hata = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B1F30),
      title: const Text('Şifre Değiştir', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kullanıcı adınız değişmez; yalnızca şifrenizi güncelleyebilirsiniz.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.user.kullaniciAdi),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _mevcutCtrl,
              obscureText: _gizleMevcut,
              decoration: InputDecoration(
                labelText: 'Mevcut şifre',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_gizleMevcut ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _gizleMevcut = !_gizleMevcut),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _yeniCtrl,
              obscureText: _gizleYeni,
              decoration: InputDecoration(
                labelText: 'Yeni şifre',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_gizleYeni ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _gizleYeni = !_gizleYeni),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tekrarCtrl,
              obscureText: _gizleYeni,
              decoration: const InputDecoration(
                labelText: 'Yeni şifre (tekrar)',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              onSubmitted: (_) => _kaydet(),
            ),
            if (_hata != null) ...[
              const SizedBox(height: 12),
              Text(_hata!, style: const TextStyle(color: AppColors.olumsuz, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _loading ? null : _kaydet,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Güncelle'),
        ),
      ],
    );
  }
}
