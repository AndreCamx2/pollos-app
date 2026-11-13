import 'dart:async';

import 'package:flutter/material.dart';

import 'colores.dart';

/// Cómo está el gallo: cada gesto dice algo de lo que pasa en la pantalla.
enum Gesto { normal, cantando, dormido, duda }

/// El gallo de la app: blanco, con la cresta roja y el pico abierto.
class Gallo extends StatelessWidget {
  const Gallo({
    super.key,
    this.tamano = 150,
    this.gesto = Gesto.normal,
    this.contorno = ColoresGranja.tinta,
  });

  final double tamano;
  final Gesto gesto;

  /// Claro cuando va sobre un fondo oscuro.
  final Color contorno;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gallo de Mis pollos',
      image: true,
      child: CustomPaint(
        size: Size.square(tamano),
        painter: _PintarGallo(gesto, contorno),
      ),
    );
  }
}

/// El gallo abriendo y cerrando el pico mientras algo carga.
class GalloCantando extends StatefulWidget {
  const GalloCantando({super.key, this.tamano = 130});

  final double tamano;

  @override
  State<GalloCantando> createState() => _GalloCantandoState();
}

class _GalloCantandoState extends State<GalloCantando> {
  Timer? _reloj;
  var _abierto = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloj?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _reloj = Timer.periodic(
        const Duration(milliseconds: 450),
        (_) => setState(() => _abierto = !_abierto),
      );
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Gallo(
        tamano: widget.tamano,
        gesto: _abierto ? Gesto.cantando : Gesto.normal,
      );
}

/// Dibujado sobre un cuadro de 200 por 200; se escala al tamaño pedido.
class _PintarGallo extends CustomPainter {
  const _PintarGallo(this.gesto, this.contorno);

  final Gesto gesto;
  final Color contorno;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final trazo = Paint()
      ..color = contorno
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final tinta = Paint()..color = ColoresGranja.tinta;
    final blanco = Paint()..color = ColoresGranja.papel;

    void pieza(Path forma, Color color) {
      canvas.drawPath(forma, Paint()..color = color);
      canvas.drawPath(forma, trazo);
    }

    Path triangulo(Offset a, Offset b, Offset c) => Path()..addPolygon([a, b, c], true);

    Path curva(Offset desde, Offset control, Offset hasta) => Path()
      ..moveTo(desde.dx, desde.dy)
      ..quadraticBezierTo(control.dx, control.dy, hasta.dx, hasta.dy);

    pieza(
      Path()
        ..addPolygon(const [
          Offset(58, 82),
          Offset(62, 40),
          Offset(82, 60),
          Offset(96, 26),
          Offset(110, 58),
          Offset(130, 36),
          Offset(134, 80),
        ], true),
      ColoresGranja.cresta,
    );

    switch (gesto) {
      case Gesto.normal:
        pieza(triangulo(const Offset(140, 96), const Offset(192, 106), const Offset(142, 114)),
            ColoresGranja.pico);
        pieza(triangulo(const Offset(142, 122), const Offset(186, 138), const Offset(138, 140)),
            ColoresGranja.pico);
      case Gesto.cantando:
        pieza(triangulo(const Offset(140, 92), const Offset(192, 78), const Offset(144, 110)),
            ColoresGranja.pico);
        pieza(triangulo(const Offset(142, 124), const Offset(190, 150), const Offset(138, 140)),
            ColoresGranja.pico);
      case Gesto.dormido:
        pieza(triangulo(const Offset(140, 104), const Offset(186, 118), const Offset(140, 132)),
            ColoresGranja.pico);
      case Gesto.duda:
        pieza(triangulo(const Offset(140, 98), const Offset(190, 104), const Offset(142, 114)),
            ColoresGranja.pico);
        pieza(triangulo(const Offset(142, 122), const Offset(184, 132), const Offset(138, 138)),
            ColoresGranja.pico);
    }

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

    final rasgo = Paint()
      ..color = ColoresGranja.tinta
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    switch (gesto) {
      case Gesto.normal:
        canvas
          ..drawCircle(const Offset(114, 102), 10, tinta)
          ..drawCircle(const Offset(117, 99), 3, blanco)
          ..drawLine(const Offset(100, 86), const Offset(124, 82), rasgo..strokeWidth = 5);
      case Gesto.cantando:
        canvas.drawPath(curva(const Offset(104, 104), const Offset(114, 92), const Offset(124, 104)), rasgo);
        final notas = Paint()
          ..color = contorno
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas
          ..drawLine(const Offset(172, 58), const Offset(184, 44), notas)
          ..drawLine(const Offset(186, 72), const Offset(198, 66), notas)
          ..drawLine(const Offset(156, 48), const Offset(160, 32), notas);
      case Gesto.dormido:
        canvas.drawPath(curva(const Offset(104, 104), const Offset(114, 114), const Offset(124, 104)), rasgo);
        final zetas = Paint()
          ..color = contorno
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas
          ..drawPath(
            Path()
              ..addPolygon(const [Offset(150, 30), Offset(170, 30), Offset(150, 52), Offset(170, 52)], false),
            zetas,
          )
          ..drawPath(
            Path()
              ..addPolygon(const [Offset(176, 10), Offset(190, 10), Offset(176, 26), Offset(190, 26)], false),
            zetas,
          );
      case Gesto.duda:
        canvas
          ..drawCircle(const Offset(114, 104), 10, tinta)
          ..drawCircle(const Offset(117, 101), 3, blanco)
          ..drawLine(const Offset(100, 82), const Offset(124, 70), rasgo..strokeWidth = 5);
        final globo = Path()..addOval(Rect.fromCircle(center: const Offset(166, 44), radius: 22));
        canvas
          ..drawPath(globo, blanco)
          ..drawPath(globo, trazo..strokeWidth = 5)
          ..drawPath(
            Path()
              ..moveTo(158, 38)
              ..cubicTo(158, 28, 174, 28, 174, 38)
              ..cubicTo(174, 46, 166, 46, 166, 54),
            rasgo,
          )
          ..drawCircle(const Offset(166, 61), 3, tinta);
    }
  }

  @override
  bool shouldRepaint(_PintarGallo anterior) =>
      anterior.gesto != gesto || anterior.contorno != contorno;
}
