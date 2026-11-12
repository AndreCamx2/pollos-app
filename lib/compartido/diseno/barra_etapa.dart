import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'movimiento.dart';

/// Por dónde va el lote entre la llegada y la venta: amarillo mientras come
/// alimento de inicio, rojizo desde que pasa a engorde.
class BarraEtapa extends StatelessWidget {
  const BarraEtapa({super.key, required this.dias, this.conEtiquetas = false});

  final int dias;
  final bool conEtiquetas;

  static const _diaDeEngorde = 22;
  static const _diaDeVenta = 45;

  @override
  Widget build(BuildContext context) {
    final avance = dias.clamp(0, _diaDeVenta) / _diaDeVenta;
    final inicio = dias.clamp(0, _diaDeEngorde) / _diaDeVenta;
    final barra = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curvas.salida,
      builder: (context, llenado, _) => SizedBox(
        height: e8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(e4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: ColoresGranja.surco),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: avance * llenado,
                child: const ColoredBox(color: ColoresGranja.granero),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: inicio * llenado,
                child: const ColoredBox(color: ColoresGranja.maiz),
              ),
            ],
          ),
        ),
      ),
    );
    if (!conEtiquetas) return barra;

    final apoyo = Theme.of(context).textTheme.bodySmall;
    return Column(
      children: [
        barra,
        const SizedBox(height: e4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('Inicio · hasta día 21', style: apoyo)),
            const SizedBox(width: e8),
            Flexible(
              child: Text(
                'Engorde · venta ~día $_diaDeVenta',
                style: apoyo,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
