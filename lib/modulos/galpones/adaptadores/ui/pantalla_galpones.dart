import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/aviso_sincronizacion.dart';
import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/barra_etapa.dart';
import '../../../../compartido/diseno/cargando.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_granja.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/gallo.dart';
import '../../../../compartido/diseno/icono_modulo.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../clientes/dominio/cliente.dart';
import '../../../granja/adaptadores/ui/selector_granja.dart';
import '../../../lotes/dominio/lote.dart';

/// La pantalla de entrada: cómo está cada galpón hoy.
class PantallaGalpones extends ConsumerWidget {
  const PantallaGalpones({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    if (granja == null) return const Scaffold(body: Cargando());
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
            loading: () => const [Cargando()],
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

class _ResumenGranja extends ConsumerWidget {
  const _ResumenGranja({required this.galpones});

  final List<GalponConLote> galpones;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abiertos = [
      for (final galpon in galpones) ?galpon.cuentas,
    ];
    final vivos = abiertos.fold(0, (suma, cuentas) => suma + cuentas.vivos);
    final deudores = [
      for (final cuenta in ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[])
        if (!cuenta.alDia) cuenta,
    ];
    final teDeben = deudores.fold(0, (suma, cuenta) => suma + cuenta.debe);
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
            child: Pulsable(
              onTap: () => context.go('/clientes'),
              child: CifraTicket(
                etiqueta: 'Te deben',
                cifra: plata(teDeben),
                detalle: switch (deudores.length) {
                  0 => 'nadie te debe',
                  1 => '1 cliente con fiado',
                  final n => '$n clientes con fiado',
                },
              ),
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
    final (:galpon, :lote, :cuentas) = item;
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
                  null => const IconoModulo(
                      Figura.galpon,
                      fondo: ColoresGranja.pastoClaro,
                      color: ColoresGranja.pasto,
                    ),
                  EtapaAlimento.engorde => const IconoModulo(
                      Figura.galpon,
                      fondo: ColoresGranja.graneroClaro,
                      color: ColoresGranja.granero,
                    ),
                  _ => const IconoModulo(Figura.galpon),
                },
                const SizedBox(width: e12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(galpon.nombre, style: textos.titleMedium, maxLines: 2),
                      Text(
                        cuentas != null
                            ? '${miles(cuentas.vivos)} vivos · '
                                '${decimal(cuentas.mortalidad)} % mortalidad'
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
            if (cuentas?.tocaCambiarAEngorde(hoy) ?? false) ...[
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
            const Gallo(tamano: 96, gesto: Gesto.dormido),
            const SizedBox(height: e12),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: e20, vertical: e12),
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
