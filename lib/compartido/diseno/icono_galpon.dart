import 'package:flutter/material.dart';

import 'colores.dart';

/// La casita del galpón dentro de un cuadro de esquinas suaves. El color del
/// cuadro dice en qué está el galpón.
class IconoGalpon extends StatelessWidget {
  const IconoGalpon({
    super.key,
    this.fondo = ColoresGranja.maizClaro,
    this.color = ColoresGranja.maizOscuro,
  });

  final Color fondo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(13),
      ),
      child: CustomPaint(painter: _Casita(color)),
    );
  }
}

class _Casita extends CustomPainter {
  const _Casita(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Dibujada en una cuadrícula de 24 y centrada en el cuadro de 44.
    canvas.translate((size.width - 22) / 2 - 1, (size.height - 22) / 2 - 1);
    canvas.scale(22 / 24);
    canvas.drawPath(
      Path()
        ..moveTo(3, 10.5)
        ..lineTo(12, 4)
        ..lineTo(21, 10.5)
        ..moveTo(5, 9.5)
        ..lineTo(5, 20)
        ..lineTo(19, 20)
        ..lineTo(19, 9.5)
        ..moveTo(9.5, 20)
        ..lineTo(9.5, 15)
        ..lineTo(14.5, 15)
        ..lineTo(14.5, 20),
      trazo,
    );
  }

  @override
  bool shouldRepaint(_Casita anterior) => anterior.color != color;
}
