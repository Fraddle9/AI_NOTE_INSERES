import 'dart:math';

import 'package:flutter/material.dart';

/// Web'deki yıldızlı gece arka planının Flutter karşılığı.
///
/// NOT: Açık tema, geri kalan tüm ekranda `InvertColors` (CSS `filter:
/// invert()` karşılığı) ile sağlanıyor (bkz. `main.dart`), AMA bu arka plan
/// BİLEREK o filtrenin DIŞINDA tutuluyor ve rengini doğrudan [isLight]
/// parametresiyle kendisi seçiyor. Sebep: sürekli tekrar eden (twinkle)
/// animasyonu, tüm ekranı kaplayan bir `ColorFiltered` katmanının ALTINDA
/// çalıştığında cihazda gözle görülür şekilde donuyor/takılıyordu. Rengi
/// burada native olarak seçmek, animasyonun web'deki gibi pürüzsüz ve
/// kesintisiz akmasını garantiler.
///
/// Yıldızlar sabit konumda durur (web'deki `position: fixed` arka planla
/// aynı davranış); sadece parlaklıkları (twinkle) zamanla değişir. Kaydırma
/// ile birlikte konum değiştirmezler — bu bilerek böyle, aksi göz yorucu
/// bulunduğu için kaldırıldı.
class StarfieldBackdrop extends StatefulWidget {
  final bool isLight;

  const StarfieldBackdrop({super.key, this.isLight = false});

  @override
  State<StarfieldBackdrop> createState() => _StarfieldBackdropState();
}

class _StarfieldBackdropState extends State<StarfieldBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _stars = List.generate(90, (i) {
      return _Star(
        dx: rng.nextDouble(),
        dy: rng.nextDouble(),
        size: i % 11 == 0 ? 2.2 : (i % 4 == 0 ? 1.4 : 0.9),
        phase: rng.nextDouble() * pi * 2,
        speed: 0.6 + rng.nextDouble() * 1.4,
      );
    });
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _twinkle,
          builder: (context, _) {
            return CustomPaint(
              painter: _StarfieldPainter(
                t: _twinkle.value * pi * 2,
                stars: _stars,
                isLight: widget.isLight,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _Star {
  final double dx;
  final double dy;
  final double size;
  final double phase;
  final double speed;

  const _Star({
    required this.dx,
    required this.dy,
    required this.size,
    required this.phase,
    required this.speed,
  });
}

class _StarfieldPainter extends CustomPainter {
  final double t;
  final List<_Star> stars;
  final bool isLight;

  _StarfieldPainter({required this.t, required this.stars, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Açık temada, geri kalan ekranın `InvertColors` ile ulaştığı çok açık
    // lavanta/mavi tonuyla kaynaşan pastel bir "gündüz göğü" gradyanı.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isLight
              ? const [Color(0xFFF6F5FF), Color(0xFFEFEDFB), Color(0xFFF3F1FA)]
              : const [Color(0xFF050816), Color(0xFF0B1230), Color(0xFF070B1C)],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.85),
          radius: 1.15,
          colors: [
            (isLight ? const Color(0xFF8B7FE0) : const Color(0xFF5846B4))
                .withValues(alpha: isLight ? 0.12 : 0.28),
            Colors.transparent,
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, 0.75),
          radius: 0.95,
          colors: [
            (isLight ? const Color(0xFF6E90D8) : const Color(0xFF2846A0))
                .withValues(alpha: isLight ? 0.10 : 0.22),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    // Koyu temada beyaz, parlak yıldızlar; açık temada ise sert siyah
    // noktalar yerine, temanın indigo vurgusuyla uyumlu YUMUŞAK, koyu mor-mavi
    // benekler (aynı twinkle animasyonuyla, ama gözü rahatsız etmeyen bir
    // renkle) kullanılıyor.
    final starColor = isLight ? const Color(0xFF5B5F8C) : Colors.white;
    final maxAlpha = isLight ? 0.55 : 1.0;
    final minAlpha = isLight ? 0.16 : 0.42;
    for (final star in stars) {
      final twinkle = minAlpha + (maxAlpha - minAlpha) * (0.5 + 0.5 * sin(t * star.speed + star.phase));
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        star.size,
        Paint()..color = starColor.withValues(alpha: twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.isLight != isLight;
}
