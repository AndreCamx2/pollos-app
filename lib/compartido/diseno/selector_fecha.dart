import 'package:flutter/material.dart';

import '../formato.dart';
import 'colores.dart';
import 'espacios.dart';
import 'tema.dart';

/// Casi todo se anota el mismo día o pocos días después, así que la fecha se
/// mueve de a un día con dos botones grandes.
class SelectorFecha extends StatelessWidget {
  const SelectorFecha({
    super.key,
    required this.fecha,
    required this.alCambiar,
    this.desde,
  });

  final DateTime fecha;
  final ValueChanged<DateTime> alCambiar;

  /// La fecha más antigua que se puede elegir, por ejemplo la llegada del lote.
  final DateTime? desde;

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final elegida = DateTime(fecha.year, fecha.month, fecha.day);
    final haceDias = hoy.difference(elegida).inDays;
    final limite = desde;
    final puedeAntes = limite == null ||
        elegida.isAfter(DateTime(limite.year, limite.month, limite.day));
    final corta = fechaCorta(elegida);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioCampo),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Un día antes',
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: puedeAntes
                ? () => alCambiar(DateTime(elegida.year, elegida.month, elegida.day - 1))
                : null,
          ),
          Expanded(
            child: Text(
              switch (haceDias) {
                0 => 'Hoy, $corta',
                1 => 'Ayer, $corta',
                _ => '$corta · hace $haceDias días',
              },
              textAlign: TextAlign.center,
              style: conPeso(Theme.of(context).textTheme.bodyLarge!, 700),
            ),
          ),
          IconButton(
            tooltip: 'Un día después',
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: haceDias <= 0
                ? null
                : () => alCambiar(DateTime(elegida.year, elegida.month, elegida.day + 1)),
          ),
        ],
      ),
    );
  }
}
