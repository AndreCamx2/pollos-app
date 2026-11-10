import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/barra_etapa.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/formato.dart';
import '../../../lotes/dominio/lote.dart';
import '../../dominio/galpon.dart';

/// Un galpón por dentro: el lote que tiene hoy y los que ya pasaron por él.
class PantallaGalpon extends ConsumerWidget {
  const PantallaGalpon({super.key, required this.galponId});

  final String galponId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    final galpones = ref.watch(galponesProvider).asData?.value;
    if (granja == null || galpones == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final encontrado = galpones.where((g) => g.galpon.id == galponId).firstOrNull;
    if (encontrado == null) return const _GalponBorrado();

    final (:galpon, :lote) = encontrado;
    final anteriores = [
      for (final l in ref.watch(lotesProvider).asData?.value ?? const <Lote>[])
        if (l.galponId == galponId && !l.abierto) l,
    ];
    final administra = granja.rol.administra;
    final textos = Theme.of(context).textTheme;
    final dias = lote?.diasDeEdad(DateTime.now());

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            tarjeta: lote == null || dias == null
                ? _GalponLibre(galpon)
                : _LoteDeHoy(lote: lote, dias: dias),
            child: TitularPantalla(
              titulo: galpon.nombre,
              subtitulo: lote == null
                  ? galpon.ubicacion
                  : 'Llegaron ${miles(lote.cantidadInicial)} el '
                      '${fechaCorta(lote.fechaLlegada)} · día $dias',
              accion: administra
                  ? IconButton(
                      tooltip: 'Corregir galpón',
                      color: ColoresGranja.tinta,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push('/galpones/$galponId/editar'),
                    )
                  : null,
            ),
          ),
          if (lote != null) ...[
            // shortcut: el alimento y la medicina se suman aquí en la parte 4.
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e12, e16, 0),
              child: TarjetaTicket(
                child: CifraTicket(
                  etiqueta: 'Invertido hasta hoy',
                  cifra: plata(lote.precioCompraTotal),
                  detalle: '${miles(lote.cantidadInicial)} pollitos a '
                      '${plata(lote.costoPorPollito)} cada uno',
                ),
              ),
            ),
            if (administra)
              Padding(
                padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
                child: Column(
                  children: [
                    BotonSecundario(
                      texto: 'Cerrar lote',
                      onPressed: () => _cerrar(context, ref, galpon, lote),
                    ),
                    TextButton(
                      onPressed: () => context.push('/lotes/${lote.id}/editar'),
                      child: const Text('Corregir datos del lote'),
                    ),
                  ],
                ),
              ),
          ] else if (administra)
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
              child: BotonPrincipal(
                texto: 'Recibir pollitos',
                onPressed: () => context.push('/lotes/nuevo?galpon=$galponId'),
              ),
            ),
          if (anteriores.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(e20, e24, e20, e12),
              child: Text('Lotes anteriores', style: textos.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: e16),
              child: Container(
                decoration: BoxDecoration(
                  color: ColoresGranja.papel,
                  borderRadius: BorderRadius.circular(radioTarjeta),
                  border: Border.all(color: ColoresGranja.borde),
                ),
                child: Column(
                  children: [
                    for (final (i, anterior) in anteriores.indexed) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: e16,
                          endIndent: e16,
                          color: ColoresGranja.borde,
                        ),
                      _FilaLoteAnterior(
                        lote: anterior,
                        // Solo el último, y solo si el galpón sigue libre:
                        // dos lotes abiertos no caben en un galpón.
                        alReabrir: administra && lote == null && i == 0
                            ? () => _reabrir(context, ref, galpon, anterior)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cerrar(
    BuildContext context,
    WidgetRef ref,
    Galpon galpon,
    Lote lote,
  ) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Cerrar el lote de ${galpon.nombre}?',
      detalle: 'Ya no se podrá registrar nada en este lote y el galpón queda '
          'libre para pollitos nuevos. Si fue un error, lo puedes reabrir.',
      accion: 'Cerrar lote',
    );
    if (!acepto) return;
    await ref.read(repositorioLotesProvider).guardar(lote.cerrar(DateTime.now()));
    await ref.read(sincronizacionProvider.notifier).huboCambios();
  }

  Future<void> _reabrir(
    BuildContext context,
    WidgetRef ref,
    Galpon galpon,
    Lote lote,
  ) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Reabrir el lote del ${fechaCorta(lote.fechaLlegada)}?',
      detalle: '${galpon.nombre} vuelve a quedar ocupado con este lote.',
      accion: 'Reabrir lote',
    );
    if (!acepto) return;
    await ref.read(repositorioLotesProvider).guardar(lote.reabrir());
    await ref.read(sincronizacionProvider.notifier).huboCambios();
  }
}

class _LoteDeHoy extends StatelessWidget {
  const _LoteDeHoy({required this.lote, required this.dias});

  final Lote lote;
  final int dias;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return _TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              // shortcut: sin muertos ni ventas hasta la parte 4.
              text: miles(lote.vivos(muertos: 0, vendidos: 0)),
              style: textos.displaySmall,
              children: [TextSpan(text: ' vivos', style: textos.bodySmall)],
            ),
          ),
          const SizedBox(height: e12),
          BarraEtapa(dias: dias, conEtiquetas: true),
          if (lote.etapaAlimento(DateTime.now()) == EtapaAlimento.cambio) ...[
            const SizedBox(height: e12),
            const AvisoAtencion('Toca cambiar a alimento de engorde'),
          ],
        ],
      ),
    );
  }
}

class _GalponLibre extends StatelessWidget {
  const _GalponLibre(this.galpon);

  final Galpon galpon;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final caben = galpon.capacidad;
    final area = galpon.areaM2;
    return _TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Galpón libre', style: textos.titleLarge),
          const SizedBox(height: e4),
          Text(
            [
              caben == null ? 'Listo para recibir pollitos' : 'Caben ${miles(caben)} pollos',
              if (area != null) '${decimal(area)} m²',
            ].join(' · '),
            style: textos.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _TarjetaPapel extends StatelessWidget {
  const _TarjetaPapel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(e16),
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioTarjeta),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: child,
    );
  }
}

class _FilaLoteAnterior extends StatelessWidget {
  const _FilaLoteAnterior({required this.lote, required this.alReabrir});

  final Lote lote;
  final VoidCallback? alReabrir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cierre = lote.cerradoEn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: e16, vertical: e12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cierre == null
                      ? 'Del ${fechaCorta(lote.fechaLlegada)}'
                      : 'Del ${fechaCorta(lote.fechaLlegada)} al ${fechaCorta(cierre.toLocal())}',
                  style: textos.titleMedium,
                ),
                Text(
                  '${miles(lote.cantidadInicial)} pollitos · ${plata(lote.precioCompraTotal)}',
                  style: textos.bodySmall,
                ),
              ],
            ),
          ),
          if (alReabrir != null)
            TextButton(onPressed: alReabrir, child: const Text('Reabrir')),
        ],
      ),
    );
  }
}

class _GalponBorrado extends StatelessWidget {
  const _GalponBorrado();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(e24),
          child: Text(
            'Este galpón ya no existe. Puede que alguien lo haya borrado.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
