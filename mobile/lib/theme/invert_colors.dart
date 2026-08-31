import 'package:flutter/widgets.dart';

/// Web tarafındaki `filter: invert(1) hue-rotate(180deg)` tekniğinin Flutter
/// karşılığı.
///
/// Bu uygulamadaki renklerin neredeyse tamamı (`AppColors.*`) düzinelerce
/// widget'a sabit (const) olarak dağılmış durumda; web'de olduğu gibi her
/// birini ayrı ayrı bir "açık tema" karşılığıyla değiştirmek yerine, TÜM alt
/// ağacı `invert()` ile ters çevirip `hue-rotate(180deg)` ile orijinal
/// mavi/mor tonları geri kazanıyoruz. Böylece mevcut koyu (yıldızlı gece)
/// tasarım hiç bozulmadan, web ile BİREBİR AYNI yöntemle tutarlı bir açık
/// tema elde edilir.
class InvertColors extends StatelessWidget {
  final Widget child;

  const InvertColors({super.key, required this.child});

  // CSS `invert(1)` ile birebir aynı: her kanalı (255 - kanal) yapar.
  static const List<double> _invert = <double>[
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ];

  // CSS `hue-rotate(180deg)` ile birebir aynı standart NTSC-luma matrisi.
  static const List<double> _hueRotate180 = <double>[
    -0.574, 1.430, 0.144, 0, 0,
    0.426, 0.430, 0.144, 0, 0,
    0.426, 1.430, -0.856, 0, 0,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    // Sıra CSS ile aynı olmalı: önce invert, sonra hue-rotate (ColorFiltered
    // iç içe kullanıldığında en İÇTEKİ filtre önce uygulanır).
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_hueRotate180),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_invert),
        child: child,
      ),
    );
  }
}
