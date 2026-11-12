import 'package:flutter/material.dart';

import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';

/// La franja maíz de las pantallas de entrada, con los techos de los galpones
/// recortados contra el fondo.
class EncabezadoGallo extends StatelessWidget {
  const EncabezadoGallo({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ColoresGranja.maiz,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(e24, e24, e24, e20),
              child: child,
            ),
            const SizedBox(
              height: 34,
              child: CustomPaint(painter: _TechosRecortados()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechosRecortados extends CustomPainter {
  const _TechosRecortados();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 390;
    final techos = Path()
      ..moveTo(0, 34)
      ..lineTo(0, 22);
    for (final (ancho, alto) in const [
      (46.0, 6.0), (92.0, 22.0), (92.0, 16.0), (148.0, 0.0), (204.0, 16.0),
      (204.0, 24.0), (250.0, 8.0), (296.0, 24.0), (296.0, 18.0), (344.0, 2.0),
      (390.0, 18.0),
    ]) {
      techos.lineTo(ancho * x, alto);
    }
    techos
      ..lineTo(size.width, 34)
      ..close();
    canvas.drawPath(techos, Paint()..color = ColoresGranja.crema);
  }

  @override
  bool shouldRepaint(_TechosRecortados anterior) => false;
}
