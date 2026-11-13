import 'dart:math';

import 'package:flutter/material.dart';

import 'colores.dart';

enum Figura { galpon, bulto, muerto, capsula, balanza, personas, barras }

/// El dibujo de cada cosa de la granja dentro de un cuadro de esquinas
/// suaves. El color del cuadro dice de qué se trata.
class IconoModulo extends StatelessWidget {
  const IconoModulo(
    this.figura, {
    super.key,
    this.fondo = ColoresGranja.maizClaro,
    this.color = ColoresGranja.maizOscuro,
    this.tamano = 44,
  });

  final Figura figura;
  final Color fondo;
  final Color color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(tamano * 0.3),
      ),
      child: CustomPaint(painter: _Trazo(figura, color)),
    );
  }
}

class _Trazo extends CustomPainter {
  const _Trazo(this.figura, this.color);

  final Figura figura;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      // Firme, para que pese como el contorno del gallo.
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Las figuras se dibujan en una cuadrícula de 24 y ocupan la mitad del cuadro.
    final lado = size.shortestSide * 0.5;
    canvas.translate((size.width - lado) / 2, (size.height - lado) / 2);
    canvas.scale(lado / 24);
    switch (figura) {
      case Figura.galpon:
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
      case Figura.bulto:
        canvas.drawPath(
          Path()
            ..moveTo(8, 4)
            ..lineTo(16, 4)
            ..lineTo(14.5, 7)
            ..lineTo(9.5, 7)
            ..close()
            ..moveTo(9.5, 7)
            ..cubicTo(6, 9, 5, 12.5, 5, 15.5)
            ..cubicTo(5, 18.5, 7, 20, 12, 20)
            ..cubicTo(17, 20, 19, 18.5, 19, 15.5)
            ..cubicTo(19, 12.5, 18, 9, 14.5, 7),
          trazo,
        );
      case Figura.muerto:
        canvas.drawCircle(const Offset(12, 12), 8, trazo);
        canvas.drawLine(const Offset(8.5, 12), const Offset(15.5, 12), trazo);
      case Figura.capsula:
        canvas.save();
        canvas.translate(12, 12);
        canvas.rotate(-pi / 4);
        canvas.translate(-12, -12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 9, 17, 6),
            const Radius.circular(3),
          ),
          trazo,
        );
        canvas.restore();
        canvas.drawLine(const Offset(9.2, 9.2), const Offset(14.8, 14.8), trazo);
      case Figura.balanza:
        canvas.drawPath(
          Path()
            ..moveTo(12, 4)
            ..lineTo(12, 20)
            ..moveTo(8, 20)
            ..lineTo(16, 20)
            ..moveTo(5, 7)
            ..lineTo(19, 7)
            ..moveTo(5, 7)
            ..lineTo(2, 13)
            ..arcToPoint(const Offset(8, 13), radius: const Radius.circular(3), clockwise: false)
            ..close()
            ..moveTo(19, 7)
            ..lineTo(16, 13)
            ..arcToPoint(const Offset(22, 13), radius: const Radius.circular(3), clockwise: false)
            ..close(),
          trazo,
        );
      case Figura.barras:
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..lineTo(20, 20)
            ..moveTo(7, 16)
            ..lineTo(7, 11)
            ..moveTo(12, 16)
            ..lineTo(12, 7)
            ..moveTo(17, 16)
            ..lineTo(17, 8),
          trazo,
        );
      case Figura.personas:
        canvas.drawCircle(const Offset(9, 8), 3.5, trazo);
        canvas.drawPath(
          Path()
            ..moveTo(3, 20)
            ..cubicTo(3, 16.5, 5.7, 14.5, 9, 14.5)
            ..cubicTo(12.3, 14.5, 15, 16.5, 15, 20)
            ..moveTo(16, 4.6)
            ..arcToPoint(const Offset(16, 11.4), radius: const Radius.circular(3.5))
            ..moveTo(18, 14.8)
            ..cubicTo(19.9, 15.5, 21, 17.2, 21, 20),
          trazo,
        );
    }
  }

  @override
  bool shouldRepaint(_Trazo anterior) =>
      anterior.figura != figura || anterior.color != color;
}
