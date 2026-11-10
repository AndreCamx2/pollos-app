import 'package:flutter/material.dart';

import '../errores.dart';
import 'colores.dart';
import 'pulsable.dart';
import 'tema.dart';

/// Pantalla completa para cuando no se pudieron cargar los datos.
class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.error,
    required this.alReintentar,
  });

  final Object error;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: ColoresGranja.tintaSuave,
            ),
            const SizedBox(height: 12),
            Text(
              mensajeDeError(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            BotonPrincipal(texto: 'Intentar de nuevo', onPressed: alReintentar),
          ],
        ),
      ),
    );
  }
}

/// Frase de error debajo de un formulario.
class AvisoError extends StatelessWidget {
  const AvisoError(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        mensaje,
        style: conPeso(
          Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: ColoresGranja.granero),
          600,
        ),
      ),
    );
  }
}
