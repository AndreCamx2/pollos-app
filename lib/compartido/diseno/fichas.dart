import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'pulsable.dart';
import 'tema.dart';

/// Opciones cortas para elegir con un toque, como la causa o la marca.
class FichasOpcion<T> extends StatelessWidget {
  const FichasOpcion({
    super.key,
    required this.opciones,
    required this.elegida,
    required this.etiqueta,
    required this.alElegir,
  });

  final List<T> opciones;
  final T? elegida;
  final String Function(T opcion) etiqueta;
  final ValueChanged<T> alElegir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme.bodyMedium!;
    return Wrap(
      spacing: e8,
      runSpacing: e8,
      children: [
        for (final opcion in opciones)
          Semantics(
            selected: opcion == elegida,
            child: Pulsable(
              onTap: () => alElegir(opcion),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: e16, vertical: e8),
                decoration: BoxDecoration(
                  color: opcion == elegida ? ColoresGranja.tinta : ColoresGranja.papel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: opcion == elegida ? ColoresGranja.tinta : ColoresGranja.borde,
                  ),
                ),
                child: Text(
                  etiqueta(opcion),
                  style: conPeso(
                    texto.copyWith(
                      color: opcion == elegida ? ColoresGranja.crema : ColoresGranja.tinta,
                    ),
                    700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
