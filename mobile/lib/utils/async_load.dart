import 'package:flutter/widgets.dart';

/// Aynı anda birden fazla fetch'i ve setState döngüsünü engeller.
mixin AsyncLoad<T extends StatefulWidget> on State<T> {
  bool _fetching = false;
  bool loading = true;
  String? loadError;

  bool get isFetching => _fetching;

  Future<void> loadData(Future<void> Function() fetch) async {
    if (_fetching) return;
    _fetching = true;
    try {
      await fetch();
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = e.toString();
      });
    } finally {
      _fetching = false;
    }
  }
}
