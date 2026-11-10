import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'movimiento.dart';
import 'pulsable.dart';

/// Pregunta antes de hacer algo que cuesta deshacer. Devuelve true si la
/// persona tocó el botón de [accion].
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String detalle,
  required String accion,
}) async {
  final acepto = await showModalBottomSheet<bool>(
    context: context,
    sheetAnimationStyle: animacionDeHoja,
    builder: (hoja) {
      final textos = Theme.of(hoja).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(e20, 0, e20, e8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: textos.titleLarge),
              const SizedBox(height: e8),
              Text(
                detalle,
                style: textos.bodyMedium!.copyWith(color: ColoresGranja.tintaSuave),
              ),
              const SizedBox(height: e20),
              BotonPrincipal(
                texto: accion,
                onPressed: () => Navigator.pop(hoja, true),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(hoja, false),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  return acepto ?? false;
}
