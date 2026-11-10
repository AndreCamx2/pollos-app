import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../compartido/diseno/colores.dart';
import '../compartido/diseno/espacios.dart';
import '../compartido/diseno/estado_error.dart';
import '../compartido/diseno/movimiento.dart';
import '../compartido/diseno/pulsable.dart';
import '../compartido/diseno/tema.dart';
import '../compartido/errores.dart';
import '../compartido/local/base_local.dart';
import 'sincronizacion.dart';

/// Dice en una frase si lo del celular ya está en el servidor. Al tocarla
/// sincroniza, o abre la lista de lo que no se pudo subir.
class AvisoSincronizacion extends ConsumerWidget {
  const AvisoSincronizacion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sincronizacionProvider);
    final hayRechazados = estado.rechazados > 0;
    final alDia = !hayRechazados &&
        !estado.trabajando &&
        !estado.sinSenal &&
        estado.falla == null &&
        estado.porSubir == 0;
    final (fondo, color) = hayRechazados
        ? (ColoresGranja.graneroClaro, ColoresGranja.granero)
        : alDia
            ? (ColoresGranja.pastoClaro, ColoresGranja.pasto)
            : (ColoresGranja.maizClaro, ColoresGranja.textoSobreMaiz);

    return Pulsable(
      onTap: hayRechazados
          ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                sheetAnimationStyle: animacionDeHoja,
                builder: (_) => const _HojaRechazados(),
              )
          : ref.read(sincronizacionProvider.notifier).sincronizar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: e8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: e12, vertical: e8),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(e16),
          ),
          child: Text(
            _frase(estado),
            style: conPeso(
              Theme.of(context).textTheme.bodySmall!.copyWith(color: color),
              700,
            ),
          ),
        ),
      ),
    );
  }

  String _frase(EstadoSincronizacion estado) {
    final porSubir = estado.porSubir;
    if (estado.rechazados == 1) return '1 cambio no se pudo subir. Toca para revisar';
    if (estado.rechazados > 1) {
      return '${estado.rechazados} cambios no se pudieron subir. Toca para revisar';
    }
    if (estado.trabajando) return 'Sincronizando…';
    if (estado.sinSenal) {
      return porSubir == 0 ? 'Sin señal' : 'Sin señal · $porSubir por subir';
    }
    if (estado.falla != null) return 'No se pudo sincronizar. Toca para intentar';
    if (porSubir > 0) return '$porSubir por subir';
    return 'Al día';
  }
}

class _HojaRechazados extends ConsumerStatefulWidget {
  const _HojaRechazados();

  @override
  ConsumerState<_HojaRechazados> createState() => _HojaRechazadosState();
}

class _HojaRechazadosState extends ConsumerState<_HojaRechazados> {
  var _ocupado = false;
  String? _error;

  Future<void> _hacer(Future<void> Function() accion) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final rechazados =
        ref.watch(rechazadosProvider).asData?.value ?? const <Pendiente>[];
    final sincronizacion = ref.read(sincronizacionProvider.notifier);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(e20, 0, e20, e16),
        children: [
          Text('No se pudo subir', style: textos.titleLarge),
          const SizedBox(height: e4),
          Text(
            rechazados.isEmpty
                ? 'Ya no queda nada por revisar.'
                : 'Estos cambios solo están en este celular. Corrígelos, '
                    'inténtalo otra vez o descártalos.',
            style: textos.bodySmall,
          ),
          for (final pendiente in rechazados) ...[
            const SizedBox(height: e12),
            Container(
              padding: const EdgeInsets.fromLTRB(e16, e16, e16, e4),
              decoration: BoxDecoration(
                color: ColoresGranja.papel,
                borderRadius: BorderRadius.circular(radioTarjeta),
                border: Border.all(color: ColoresGranja.borde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pendiente.operacion == Operacion.borrar
                        ? 'Borrar ${pendiente.titulo}'
                        : pendiente.titulo,
                    style: textos.titleMedium,
                  ),
                  const SizedBox(height: e4),
                  Text(pendiente.error ?? '', style: textos.bodyMedium),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _ocupado
                            ? null
                            : () => _hacer(() => sincronizacion.descartar(pendiente)),
                        child: const Text('Descartar'),
                      ),
                      TextButton(
                        onPressed: _ocupado
                            ? null
                            : () => _hacer(() => sincronizacion.reintentar(pendiente)),
                        child: const Text('Intentar de nuevo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_error case final error?) ...[
            const SizedBox(height: e12),
            AvisoError(error),
          ],
        ],
      ),
    );
  }
}
