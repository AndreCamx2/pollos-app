import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/aviso_sincronizacion.dart';
import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/barra_etapa.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_granja.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/icono_galpon.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../granja/adaptadores/ui/selector_granja.dart';
import '../../../lotes/dominio/lote.dart';

/// La pantalla de entrada: cómo está cada galpón hoy.
class PantallaGalpones extends ConsumerWidget {
  const PantallaGalpones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    if (granja == null) return const Scaffold();
    final variasGranjas = (ref.watch(misGranjasProvider).asData?.value.length ?? 0) > 1;
    final galpones = ref.watch(galponesProvider);
    final cargados = galpones.asData?.value ?? const <GalponConLote>[];
    final administra = granja.rol.administra;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: administra && cargados.isNotEmpty
          ? _BotonNuevoLote(alTocar: () => context.push('/lotes/nuevo'))
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          EncabezadoMaiz(
            tarjeta: cargados.isEmpty ? null : _ResumenGranja(galpones: cargados),
            child: EncabezadoGranja(
              nombre: granja.nombre,
              alCambiarGranja: variasGranjas ? () => mostrarSelectorGranja(context) : null,
              accion: IconButton(
                tooltip: 'Personas',
                color: ColoresGranja.tinta,
                icon: const Icon(Icons.group_outlined),
                onPressed: () => context.push('/personas'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(e16, e8, e16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AvisoSincronizacion(),
            ),
          ),
          ...galpones.when<List<Widget>>(
            skipLoadingOnReload: true,
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(e24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              EstadoError(
                error: error,
                alReintentar: () => ref.invalidate(galponesProvider),
              ),
            ],
            data: (galpones) => galpones.isEmpty
                ? [_SinGalpones(administra: administra)]
                : [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(e20, e8, e20, e12),
                      child: Text('Galpones', style: textos.titleLarge),
                    ),
                    for (final galpon in galpones)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(e16, 0, e16, e12),
                        child: _TarjetaGalpon(galpon),
                      ),
                    if (administra)
                      Center(
                        child: TextButton(
                          onPressed: () => context.push('/galpones/nuevo'),
                          child: const Text('Agregar otro galpón'),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _ResumenGranja extends StatelessWidget {
  const _ResumenGranja({required this.galpones});

  final List<GalponConLote> galpones;

  @override
  Widget build(BuildContext context) {
    final abiertos = [
      for (final galpon in galpones) ?galpon.lote,
    ];
    // shortcut: los muertos y las ventas llegan en la parte 4; hasta entonces
    // siguen vivos todos los que llegaron.
    final vivos = abiertos.fold(
      0,
      (suma, lote) => suma + lote.vivos(muertos: 0, vendidos: 0),
    );
    final libres = galpones.length - abiertos.length;
    return TarjetaTicket(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: CifraTicket(
              etiqueta: 'Pollos vivos',
              cifra: miles(vivos),
              detalle: galpones.length == 1 ? 'en 1 galpón' : 'en ${galpones.length} galpones',
              color: ColoresGranja.crema,
            ),
          ),
          const SizedBox(width: e12),
          Expanded(
            child: CifraTicket(
              etiqueta: 'Galpones libres',
              cifra: '$libres',
              detalle: libres == 0 ? 'todos tienen lote' : 'listos para pollitos',
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaGalpon extends StatelessWidget {
  const _TarjetaGalpon(this.item);

  final GalponConLote item;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final (:galpon, :lote) = item;
    final hoy = DateTime.now();
    final dias = lote?.diasDeEdad(hoy);
    final etapa = lote?.etapaAlimento(hoy);
    final caben = galpon.capacidad;

    return Pulsable(
      onTap: () => context.push('/galpones/${galpon.id}'),
      child: Container(
        padding: const EdgeInsets.all(e16),
        decoration: BoxDecoration(
          color: ColoresGranja.papel,
          borderRadius: BorderRadius.circular(radioTarjeta),
          border: Border.all(color: ColoresGranja.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                switch (etapa) {
                  null => const IconoGalpon(
                      fondo: ColoresGranja.pastoClaro,
                      color: ColoresGranja.pasto,
                    ),
                  EtapaAlimento.engorde => const IconoGalpon(
                      fondo: ColoresGranja.graneroClaro,
                      color: ColoresGranja.granero,
                    ),
                  _ => const IconoGalpon(),
                },
                const SizedBox(width: e12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(galpon.nombre, style: textos.titleMedium, maxLines: 2),
                      Text(
                        lote != null
                            ? '${miles(lote.vivos(muertos: 0, vendidos: 0))} vivos'
                            : caben != null
                                ? 'Libre · caben ${miles(caben)} pollos'
                                : 'Libre · listo para recibir pollitos',
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (dias != null)
                  Text.rich(
                    TextSpan(
                      text: '$dias',
                      style: textos.headlineSmall,
                      children: [
                        TextSpan(
                          text: dias == 1 ? ' día' : ' días',
                          style: textos.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (dias != null) ...[
              const SizedBox(height: e12),
              BarraEtapa(dias: dias),
            ],
            if (etapa == EtapaAlimento.cambio) ...[
              const SizedBox(height: e12),
              const AvisoAtencion('Toca cambiar a alimento de engorde'),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinGalpones extends StatelessWidget {
  const _SinGalpones({required this.administra});

  final bool administra;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(e16),
      child: Container(
        padding: const EdgeInsets.all(e24),
        decoration: BoxDecoration(
          color: ColoresGranja.papel,
          borderRadius: BorderRadius.circular(radioTarjeta),
          border: Border.all(color: ColoresGranja.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Todavía no hay galpones', style: textos.titleLarge),
            const SizedBox(height: e4),
            Text(
              administra
                  ? 'Agrega el primero y después registra los pollitos que lleguen.'
                  : 'Cuando el dueño agregue los galpones, los verás aquí.',
              style: textos.bodySmall,
            ),
            if (administra) ...[
              const SizedBox(height: e20),
              BotonPrincipal(
                texto: 'Agregar galpón',
                onPressed: () => context.push('/galpones/nuevo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BotonNuevoLote extends StatelessWidget {
  const _BotonNuevoLote({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Pulsable(
      onTap: alTocar,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: e20),
        decoration: BoxDecoration(
          color: ColoresGranja.granero,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ColoresGranja.granero.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: ColoresGranja.papel),
            const SizedBox(width: e8),
            Text(
              'Nuevo lote',
              style: conPeso(
                const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 17,
                  color: ColoresGranja.papel,
                ),
                700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
