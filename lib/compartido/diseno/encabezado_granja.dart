import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'icono_modulo.dart';
import 'pulsable.dart';

/// La fecha de hoy y el nombre de la granja, arriba de las pantallas
/// principales. Si hay varias granjas, tocar el nombre deja cambiar de una a otra.
class EncabezadoGranja extends StatelessWidget {
  const EncabezadoGranja({
    super.key,
    required this.nombre,
    required this.alCambiarGranja,
    this.accion,
  });

  final String nombre;
  final VoidCallback? alCambiarGranja;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Row(
      children: [
        const IconoModulo(Figura.galpon, fondo: ColoresGranja.tinta, color: ColoresGranja.maiz),
        const SizedBox(width: e12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fechaLarga(DateTime.now()).toUpperCase(),
                style: textos.labelLarge!.copyWith(color: ColoresGranja.textoSobreMaiz),
              ),
              Pulsable(
                onTap: alCambiarGranja,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(nombre, style: textos.titleLarge, maxLines: 2),
                    ),
                    if (alCambiarGranja != null)
                      const Icon(Icons.expand_more_rounded, size: 28),
                  ],
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

String fechaLarga(DateTime fecha) {
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${dias[fecha.weekday - 1]} ${fecha.day} de ${meses[fecha.month - 1]}';
}
