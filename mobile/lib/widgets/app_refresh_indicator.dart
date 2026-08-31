import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kullanıcı parmakla çekince yeniler; layout/bounce kendi kendine yenilemez.
///
/// [RefreshIndicator] parmak bırakınca [ScrollEndNotification] ister. Bu
/// kesilirse ok takılı kalır. İlk karedeki bounce ise [onRefresh] tetiklerse
/// boş listede "Yükleniyor"da kilitlenir.
class AppRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
  });

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator> {
  bool _armed = false;
  bool _running = false;
  Timer? _armTimer;

  @override
  void initState() {
    super.initState();
    _armTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _armed = true;
    });
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (!_armed || _running) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return;
    }
    _running = true;
    try {
      await widget.onRefresh();
    } finally {
      _running = false;
    }
  }

  bool _notificationPredicate(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    // Parmak bırakılınca yenilemenin başlaması / okun kaybolması.
    if (notification is ScrollEndNotification) return true;
    // iOS bounce: parmak kalktıktan sonra dragDetails null gelir.
    if (notification is ScrollUpdateNotification) return true;
    // Layout/glow overscroll yenileme başlatmasın; yalnızca gerçek sürükleme.
    if (notification is OverscrollNotification) {
      return notification.dragDetails != null;
    }
    if (notification is ScrollStartNotification) {
      return notification.dragDetails != null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: widget.color ?? AppColors.accent,
      backgroundColor: widget.backgroundColor ?? AppColors.surfaceSolid,
      notificationPredicate: _notificationPredicate,
      onRefresh: _handleRefresh,
      child: widget.child,
    );
  }
}
