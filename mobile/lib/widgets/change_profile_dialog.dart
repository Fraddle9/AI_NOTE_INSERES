import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Oturum açmış kullanıcının görünen adını güncellemesi (kullanıcı adı sabit).
Future<AuthUser?> showChangeProfileDialog(
  BuildContext context, {
  required AuthUser user,
}) {
  return showDialog<AuthUser>(
    context: context,
    builder: (ctx) => _ChangeProfileDialog(user: user),
  );
}

class _ChangeProfileDialog extends StatefulWidget {
  final AuthUser user;

  const _ChangeProfileDialog({required this.user});

  @override
  State<_ChangeProfileDialog> createState() => _ChangeProfileDialogState();
}

class _ChangeProfileDialogState extends State<_ChangeProfileDialog> {
  late final TextEditingController _adCtrl;
  bool _loading = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _adCtrl = TextEditingController(text: widget.user.adSoyad);
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final ad = _adCtrl.text.trim();
    if (ad.isEmpty) {
      setState(() => _hata = 'Ad soyad zorunludur.');
      return;
    }

    setState(() {
      _loading = true;
      _hata = null;
    });

    try {
      final guncel = await AuthService.updateProfile(adSoyad: ad);
      if (!mounted) return;
      Navigator.of(context).pop(guncel);
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
      title: const Text('Adımı Düzenle', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kullanıcı adınız değişmez; yalnızca görünen adınızı güncelleyebilirsiniz.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              readOnly: true,
              controller: TextEditingController(text: widget.user.kullaniciAdi),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _adCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ad Soyad',
                prefixIcon: Icon(Icons.badge_outlined),
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
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
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
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
