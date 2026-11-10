import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'tema.dart';

/// La franja amarilla con los techos de los galpones al fondo, arriba de
/// cada pantalla.
class EncabezadoMaiz extends StatelessWidget {
  const EncabezadoMaiz({super.key, required this.child, this.tarjeta});

  final Widget child;

  /// Se monta sobre el borde de abajo de la franja, mitad adentro y mitad afuera.
  final Widget? tarjeta;

  static const _loQueSobresale = 56.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: tarjeta == null ? 0 : _loQueSobresale,
          child: const ColoredBox(
            color: ColoresGranja.maiz,
            child: CustomPaint(painter: _Techos()),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(e16, e16, e16, e20),
                child: child,
              ),
              if (tarjeta case final tarjeta?)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: e16),
                  child: tarjeta,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Techos extends CustomPainter {
  const _Techos();

  @override
  void paint(Canvas canvas, Size size) {
    final pintura = Paint()..color = ColoresGranja.maizTecho;
    final esquina = Offset(size.width - 220, size.height - 96);
    void galpon(List<Offset> silueta) => canvas.drawPath(
          Path()..addPolygon([for (final punto in silueta) punto + esquina], true),
          pintura,
        );
    galpon(const [
      Offset(18, 96),
      Offset(18, 56),
      Offset(74, 22),
      Offset(130, 56),
      Offset(130, 96),
    ]);
    galpon(const [
      Offset(126, 96),
      Offset(126, 64),
      Offset(172, 34),
      Offset(218, 64),
      Offset(218, 96),
    ]);
  }

  @override
  bool shouldRepaint(_Techos anterior) => false;
}

/// Botón de volver, título y una línea de apoyo, para las pantallas a las
/// que se entra desde otra.
class TitularPantalla extends StatelessWidget {
  const TitularPantalla({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
  });

  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        IconButton(
          tooltip: 'Volver',
          color: ColoresGranja.tinta,
          icon: const Icon(Icons.chevron_left_rounded, size: 32),
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: e4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.headlineSmall, maxLines: 2),
              if (subtitulo case final subtitulo?)
                Text(
                  subtitulo,
                  style: conPeso(
                    textos.bodyMedium!.copyWith(color: ColoresGranja.textoSobreMaiz),
                    600,
                  ),
                ),
            ],
          ),
        ),
        ?accion,
      ],
    );
  }
}
