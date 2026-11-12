import 'package:flutter/material.dart';

import 'colores.dart';

/// El gallo de la app: blanco, con la cresta roja y el pico abierto.
class Gallo extends StatelessWidget {
  const Gallo({super.key, this.tamano = 150});

  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gallo de Mis pollos',
      image: true,
      child: CustomPaint(size: Size.square(tamano), painter: const _PintarGallo()),
    );
  }
}

/// Dibujado sobre un cuadro de 200 por 200; se escala al tamaño pedido.
class _PintarGallo extends CustomPainter {
  const _PintarGallo();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final trazo = Paint()
      ..color = ColoresGranja.tinta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void pieza(Path forma, Color color) {
      canvas.drawPath(forma, Paint()..color = color);
      canvas.drawPath(forma, trazo);
    }

    Path poligono(List<Offset> puntos) => Path()..addPolygon(puntos, true);

    pieza(
      poligono(const [
        Offset(58, 82),
        Offset(62, 40),
        Offset(82, 60),
        Offset(96, 26),
        Offset(110, 58),
        Offset(130, 36),
        Offset(134, 80),
      ]),
      ColoresGranja.cresta,
    );
    pieza(
      poligono(const [Offset(140, 96), Offset(192, 106), Offset(142, 114)]),
      ColoresGranja.pico,
    );
    pieza(
      poligono(const [Offset(142, 122), Offset(186, 138), Offset(138, 140)]),
      ColoresGranja.pico,
    );
    pieza(
      Path()
        ..moveTo(128, 146)
        ..cubicTo(128, 168, 150, 172, 150, 154)
        ..cubicTo(150, 146, 142, 140, 136, 140)
        ..close(),
      ColoresGranja.cresta,
    );
    pieza(
      Path()..addOval(Rect.fromCircle(center: const Offset(94, 116), radius: 54)),
      ColoresGranja.papel,
    );
    canvas
      ..drawCircle(const Offset(114, 102), 10, Paint()..color = ColoresGranja.tinta)
      ..drawCircle(const Offset(117, 99), 3, Paint()..color = ColoresGranja.papel)
      ..drawLine(const Offset(100, 86), const Offset(124, 82), trazo..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(_PintarGallo anterior) => false;
}
