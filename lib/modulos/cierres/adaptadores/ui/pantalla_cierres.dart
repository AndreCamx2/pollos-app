import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/fichas.dart';
import '../../../../compartido/diseno/gallo.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../registros/dominio/cuentas_lote.dart';
import '../../dominio/cierres.dart';

/// Los lotes terminados y cuánto dejaron, por periodo.
class PantallaCierres extends ConsumerStatefulWidget {
  const PantallaCierres({super.key});

  @override
  ConsumerState<PantallaCierres> createState() => _PantallaCierresState();
}

class _PantallaCierresState extends ConsumerState<PantallaCierres> {
  var _periodo = Periodo.anio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final hoy = DateTime.now();
    final cerrados = ref.watch(lotesCerradosProvider);
    final galpones = ref.watch(nombresDeGalponesProvider);
    final lotes = [
      for (final c in cerrados.asData?.value ?? const <CuentasLote>[])
        if (cerradoEn(c, _periodo, hoy)) c,
    ];
    final resumen = ResumenPeriodo(lotes);
    final nombrePeriodo = {
      Periodo.anio: '${hoy.year}',
      Periodo.seisMeses: '6 meses',
      Periodo.todo: 'Todo',
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: e24),
      children: [
        EncabezadoMaiz(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cierres', style: textos.headlineSmall),
              Text(
                'Lotes terminados y cómo te fue',
                style: conPeso(textos.bodyMedium!.copyWith(color: ColoresGranja.textoSobreMaiz), 600),
              ),
              const SizedBox(height: e12),
              FichasOpcion<Periodo>(
                opciones: Periodo.values,
                elegida: _periodo,
                etiqueta: (periodo) => nombrePeriodo[periodo]!,
                alElegir: (periodo) => setState(() => _periodo = periodo),
              ),
            ],
          ),
        ),
        if (cerrados.hasError)
          EstadoError(
            error: cerrados.error!,
            alReintentar: () => ref.invalidate(lotesCerradosProvider),
          )
        else if (cerrados.hasValue && lotes.isEmpty)
          _SinCierres(hayOtros: (cerrados.value ?? const []).isNotEmpty)
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e16, e16, 0),
            child: _Resumen(resumen: resumen, periodo: _periodo, anio: hoy.year),
          ),
          if (lotes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e12, e16, 0),
              child: _Grafica(resumen: resumen, galpones: galpones),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e20, e20, e20, e8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text('Lotes cerrados', style: textos.titleLarge)),
                Text('El más reciente primero', style: textos.bodySmall),
              ],
            ),
          ),
          for (final cuentas in lotes)
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, 0, e16, 10),
              child: _TarjetaCierre(cuentas: cuentas, galpon: galpones[cuentas.lote.galponId] ?? 'Galpón'),
            ),
        ],
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.resumen, required this.periodo, required this.anio});

  final ResumenPeriodo resumen;
  final Periodo periodo;
  final int anio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    final dato = textos.titleLarge!.copyWith(color: ColoresGranja.crema);
    final gano = resumen.ganancia >= 0;
    final cuando = switch (periodo) {
      Periodo.anio => 'en $anio',
      Periodo.seisMeses => 'en los últimos 6 meses',
      Periodo.todo => 'desde que usas la app',
    };
    Widget columna(String cifra, String etiqueta) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(cifra, style: dato)),
              Text(etiqueta, style: apoyo),
            ],
          ),
        );
    return TarjetaTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CifraTicket(
            etiqueta: '${gano ? 'Ganaste' : 'Perdiste'} $cuando',
            cifra: plata(resumen.ganancia.abs()),
            detalle: 'Vendiste ${plata(resumen.ventas)}',
            color: gano ? ColoresGranja.maiz : ColoresGranja.graneroClaro,
          ),
          const SizedBox(height: e12),
          const Divider(height: 1, color: ColoresGranja.tintaSuave),
          const SizedBox(height: e12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              columna(
                '${resumen.lotes.length}',
                resumen.lotes.length == 1 ? 'lote cerrado' : 'lotes cerrados',
              ),
              columna(
                resumen.margen == null ? '—' : '${decimal(resumen.margen!)} %',
                'ganancia sobre ventas',
              ),
              columna(
                resumen.mortalidad == null ? '—' : '${decimal(resumen.mortalidad!)} %',
                'mortalidad',
              ),
            ],
          ),
          const SizedBox(height: e8),
          Text(
            '${miles(resumen.vendidos)} pollos vendidos de ${miles(resumen.llegaron)} que llegaron',
            style: apoyo,
          ),
        ],
      ),
    );
  }
}

/// La ganancia de cada lote en barras, del más antiguo al más reciente. Las
/// pérdidas bajan de la raya.
class _Grafica extends StatelessWidget {
  const _Grafica({required this.resumen, required this.galpones});

  final ResumenPeriodo resumen;
  final Map<String, String> galpones;

  static const _cuantos = 8;
  static const _altoArriba = 96.0;
  static const _altoAbajo = 30.0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lotes = resumen.lotes.take(_cuantos).toList().reversed.toList();
    final mayor = lotes.fold(1, (m, c) => max(m, c.ganancia.abs()));
    final mejor = resumen.mejor;
    final perdidas = resumen.conPerdida;
    final lectura = [
      if (mejor != null)
        'Tu mejor lote fue ${galpones[mejor.lote.galponId] ?? 'un galpón'} '
            '(${mesCorto(mejor.lote.cerradoEn!.toLocal())})',
      switch (perdidas) {
        0 => 'ninguno dio pérdida.',
        1 => '1 lote dio pérdida.',
        _ => '$perdidas lotes dieron pérdida.',
      },
    ].join('; ');
    final etiquetaPequena = conPeso(textos.bodySmall!.copyWith(fontSize: 11), 700);

    return Container(
      padding: const EdgeInsets.fromLTRB(e16, e16, e16, e12),
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioTarjeta),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ganancia por lote', style: textos.titleMedium),
          Text(lectura, style: textos.bodySmall),
          const SizedBox(height: e12),
          Semantics(
            label: 'Ganancia por lote, del más antiguo al más reciente. $lectura',
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cuentas in lotes)
                    Expanded(
                      child: Column(
                        children: [
                          SizedBox(
                            height: _altoArriba + 18,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (cuentas.ganancia >= 0) ...[
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(millones(cuentas.ganancia), style: etiquetaPequena),
                                  ),
                                  const SizedBox(height: e4),
                                  _Barra(
                                    alto: max(4, cuentas.ganancia / mayor * _altoArriba),
                                    color: identical(cuentas, mejor)
                                        ? ColoresGranja.maiz
                                        : ColoresGranja.maizClaro,
                                    arriba: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(height: 1, color: ColoresGranja.tinta),
                          SizedBox(
                            height: _altoAbajo + 16,
                            child: Column(
                              children: [
                                if (cuentas.ganancia < 0) ...[
                                  _Barra(
                                    alto: max(4, -cuentas.ganancia / mayor * _altoAbajo),
                                    color: ColoresGranja.granero,
                                    arriba: false,
                                  ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      millones(cuentas.ganancia),
                                      style: etiquetaPequena.copyWith(color: ColoresGranja.granero),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(mesCorto(cuentas.lote.cerradoEn!.toLocal()), style: textos.bodySmall),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.alto, required this.color, required this.arriba});

  final double alto;
  final Color color;
  final bool arriba;

  @override
  Widget build(BuildContext context) {
    const radio = Radius.circular(6);
    return FractionallySizedBox(
      widthFactor: 0.7,
      child: Container(
        height: alto,
        constraints: const BoxConstraints(maxWidth: 34),
        decoration: BoxDecoration(
          color: color,
          borderRadius: arriba
              ? const BorderRadius.vertical(top: radio)
              : const BorderRadius.vertical(bottom: radio),
        ),
      ),
    );
  }
}

class _TarjetaCierre extends StatelessWidget {
  const _TarjetaCierre({required this.cuentas, required this.galpon});

  final CuentasLote cuentas;
  final String galpon;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final lote = cuentas.lote;
    final gano = cuentas.ganancia >= 0;
    final margen = cuentas.margen;
    Widget ficha(String texto, {required Color fondo, required Color color}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: e4),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
          child: Text(texto, style: conPeso(textos.bodySmall!.copyWith(color: color), 700)),
        );
    return Pulsable(
      onTap: () => context.push('/lotes/${lote.id}/cierre'),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(galpon, style: textos.titleMedium),
                      Text(
                        '${fechaConAnio(lote.fechaLlegada)} – ${fechaConAnio(lote.cerradoEn!.toLocal())}'
                        ' · ${cuentas.dias(DateTime.now())} días',
                        style: textos.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(gano ? 'Ganaste' : 'Perdiste', style: textos.bodySmall),
                    Text(
                      plata(cuentas.ganancia.abs()),
                      style: textos.titleLarge!.copyWith(
                        color: gano ? ColoresGranja.pasto : ColoresGranja.granero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: e8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (margen != null)
                  ficha(
                    '${decimal(margen)} % de ganancia',
                    fondo: gano ? ColoresGranja.pastoClaro : ColoresGranja.graneroClaro,
                    color: gano ? ColoresGranja.pasto : ColoresGranja.granero,
                  ),
                ficha(
                  '${miles(lote.cantidadInicial)} pollos',
                  fondo: ColoresGranja.surco,
                  color: ColoresGranja.tinta,
                ),
                ficha(
                  'Mortalidad ${decimal(cuentas.mortalidad)} %',
                  fondo: cuentas.mortalidad >= 5 ? ColoresGranja.graneroClaro : ColoresGranja.surco,
                  color: cuentas.mortalidad >= 5 ? ColoresGranja.granero : ColoresGranja.tinta,
                ),
              ],
            ),
            if (cuentas.faltantes > 0) ...[
              const SizedBox(height: e8),
              Text(
                'Faltaron ${miles(cuentas.faltantes)} pollos al cerrar.',
                style: textos.bodySmall!.copyWith(color: ColoresGranja.granero),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinCierres extends StatelessWidget {
  const _SinCierres({required this.hayOtros});

  /// Hay lotes cerrados, pero fuera del periodo elegido.
  final bool hayOtros;

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
            Text(
              hayOtros ? 'Ningún lote cerrado en este periodo' : 'Todavía no has cerrado ningún lote',
              style: textos.titleLarge,
            ),
            const SizedBox(height: e4),
            Text(
              hayOtros
                  ? 'Elige otro periodo para ver los demás.'
                  : 'Cuando cierres uno desde su galpón, aquí verás cuánto ganaste.',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
