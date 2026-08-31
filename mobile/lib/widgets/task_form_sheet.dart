import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

Future<bool> showTaskFormSheet({
  required BuildContext context,
  required ApiService api,
  TaskItem? task,
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
        child: TaskFormSheet(api: api, task: task),
      );
    },
  );
  return saved == true;
}

class TaskFormSheet extends StatefulWidget {
  final ApiService api;
  final TaskItem? task;

  const TaskFormSheet({super.key, required this.api, this.task});

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  late final TextEditingController _baslik;
  late final TextEditingController _kurum;
  late bool _tamamlandi;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    _baslik = TextEditingController(text: widget.task?.baslik ?? '');
    _kurum = TextEditingController(text: widget.task?.kurumAdi ?? '');
    _tamamlandi = widget.task?.tamamlandi ?? false;
  }

  @override
  void dispose() {
    _baslik.dispose();
    _kurum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baslik = _baslik.text.trim();
    if (baslik.isEmpty) {
      setState(() => _error = 'Görev başlığı zorunludur.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = TaskWrite(
        baslik: baslik,
        kurumAdi: _kurum.text.trim(),
        tamamlandi: _tamamlandi,
      );
      if (_isEdit) {
        await widget.api.updateTask(widget.task!.id, payload);
      } else {
        await widget.api.createTask(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
            Text(
              _isEdit ? 'Görevi Düzenle' : 'Yeni Görev',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _baslik,
              decoration: const InputDecoration(
                labelText: 'Görev',
                hintText: 'Örn: Teklif maili gönder',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _kurum,
              decoration: const InputDecoration(
                labelText: 'Kurum',
                hintText: 'İsteğe bağlı',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tamamlandı', style: TextStyle(color: AppColors.text)),
              value: _tamamlandi,
              activeThumbColor: AppColors.olumlu,
              onChanged: (v) => setState(() => _tamamlandi = v),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.olumsuz, fontSize: 13)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
            ),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
          ],
        ),
      ),
    );
  }
}
