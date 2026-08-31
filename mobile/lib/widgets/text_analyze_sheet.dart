import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<bool> showTextAnalyzeSheet({
  required BuildContext context,
  required ApiService api,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: TextAnalyzeSheet(api: api),
      );
    },
  );
  return saved == true;
}

class TextAnalyzeSheet extends StatefulWidget {
  final ApiService api;

  const TextAnalyzeSheet({super.key, required this.api});

  @override
  State<TextAnalyzeSheet> createState() => _TextAnalyzeSheetState();
}

class _TextAnalyzeSheetState extends State<TextAnalyzeSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final metin = _ctrl.text.trim();
    if (metin.isEmpty) {
      setState(() => _error = 'Önce görüşme notu girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.analyzeText(metin);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Metinle analiz et',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              minLines: 5,
              maxLines: 8,
              enabled: !_busy,
              decoration: const InputDecoration(
                hintText: 'Bugün görüşülen üniversite, yetkili kişi ve toplantı detaylarını girin...',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.olumsuz, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _run,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_busy ? 'Analiz ediliyor...' : 'Yapay Zeka ile Analiz Et'),
            ),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }
}
