import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';

/// La tarjeta oscura para el número que importa en la pantalla. Una por
/// pantalla, como mucho.
class TarjetaTicket extends StatelessWidget {
  const TarjetaTicket({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(e20, e16, e20, e20),
      decoration: BoxDecoration(
        color: ColoresGranja.tinta,
        borderRadius: BorderRadius.circular(radioTarjeta),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: ColoresGranja.crema),
        child: child,
      ),
    );
  }
}

/// Etiqueta pequeña, cifra grande y una línea de detalle, para dentro del ticket.
class CifraTicket extends StatelessWidget {
  const CifraTicket({
    super.key,
    required this.etiqueta,
    required this.cifra,
    this.detalle,
    this.color = ColoresGranja.maiz,
  });

  final String etiqueta;
  final String cifra;
  final String? detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: apoyo),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(cifra, style: textos.displaySmall!.copyWith(color: color)),
        ),
        if (detalle case final detalle?) Text(detalle, style: apoyo),
      ],
    );
  }
}
