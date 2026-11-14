import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/cargando.dart';
import '../../../../compartido/diseno/colores.dart';
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
import '../../../registros/dominio/cuentas_lote.dart';
import '../../dominio/cierres.dart';
import '../pdf/cierre_en_pdf.dart';

/// Cómo le fue a un lote: cuánto se ganó, en qué se invirtió, cómo murieron
/// los pollos y a quién se le vendió. Con el lote abierto muestra cómo va.
class PantallaCierreLote extends ConsumerWidget {
  const PantallaCierreLote({super.key, required this.loteId});

  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentas = ref.watch(cuentasDeLoteProvider(loteId));
    if (cuentas == null) {
      return const Scaffold(body: Cargando());
    }
    final lote = cuentas.lote;
    final hoy = DateTime.now();
    final galpon = ref.watch(nombresDeGalponesProvider)[lote.galponId] ?? 'Galpón';
    final clientes = ref.watch(nombresDeClientesProvider);
    final cierre = lote.cerradoEn?.toLocal();
    final dias = cuentas.dias(hoy);
    final delAnio = [
      for (final c in ref.watch(lotesCerradosProvider).asData?.value ?? const <CuentasLote>[])
        if (cerradoEn(c, Periodo.anio, hoy)) c,
    ];
    final teDeben = (ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[])
        .fold(0, (suma, c) => suma + (c.alDia ? 0 : c.debe));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            tarjeta: _Ganancia(
              cuentas: cuentas,
              cerrado: cierre != null,
              delAnio: delAnio,
              anio: hoy.year,
            ),
            child: TitularPantalla(
              titulo: '${cierre == null ? 'Cómo va' : 'Cierre'} · $galpon',
              subtitulo: cierre == null
                  ? 'Llegaron el ${fechaConAnio(lote.fechaLlegada)} · día $dias'
                  : 'Lote del ${fechaConAnio(lote.fechaLlegada)} al ${fechaConAnio(cierre)} · $dias días',
            ),
          ),
          if (teDeben > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e12, e16, 0),
              child: Pulsable(
                onTap: () => context.go('/clientes'),
                child: AvisoAtencion('Tus clientes te deben ${plata(teDeben)} en total. Toca para ver.'),
              ),
            ),
          _Seccion(
            titulo: 'Cómo fue el lote',
            child: _LineaDeTiempo(cuentas: cuentas, clientes: clientes),
          ),
          _Seccion(titulo: 'Inversión', child: _Inversion(cuentas)),
          _Seccion(titulo: 'Indicadores', sinTarjeta: true, child: _Indicadores(cuentas)),
          if (cuentas.muertos + cuentas.faltantes > 0)
            _Seccion(titulo: 'Por qué se murieron', child: _Causas(cuentas)),
          if (cuentas.ventasPorCliente.isNotEmpty)
            _Seccion(
              titulo: 'A quién le vendiste',
              child: _PorCliente(cuentas: cuentas, clientes: clientes),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e24, e16, 0),
            child: _BotonPdf(
              cuentas: cuentas,
              granja: ref.watch(granjaActualProvider)?.nombre ?? 'Mis pollos',
              galpon: galpon,
              clientes: clientes,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e12, e16, 0),
            child: BotonSecundario(
              texto: 'Compartir resumen en texto',
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: textoParaCompartir(cuentas, galpon: galpon, clientes: clientes, hoy: hoy),
                  subject: 'Resumen del lote · $galpon',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arma el cierre en PDF y abre el menú de compartir del celular, donde
/// está WhatsApp.
class _BotonPdf extends StatefulWidget {
  const _BotonPdf({
    required this.cuentas,
    required this.granja,
    required this.galpon,
    required this.clientes,
  });

  final CuentasLote cuentas;
  final String granja;
  final String galpon;
  final Map<String, String> clientes;

  @override
  State<_BotonPdf> createState() => _BotonPdfState();
}

class _BotonPdfState extends State<_BotonPdf> {
  var _armando = false;

  Future<void> _enviar() async {
    final avisos = ScaffoldMessenger.of(context);
    final hoy = DateTime.now();
    setState(() => _armando = true);
    try {
      final pdf = await cierreEnPdf(
        widget.cuentas,
        granja: widget.granja,
        galpon: widget.galpon,
        clientes: widget.clientes,
        hoy: hoy,
      );
      final nombre = nombreDelPdf(
        widget.galpon,
        widget.cuentas.lote.cerradoEn?.toLocal() ?? hoy,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(pdf, mimeType: 'application/pdf', name: nombre)],
          fileNameOverrides: [nombre],
        ),
      );
    } on Exception {
      avisos.showSnackBar(
        const SnackBar(content: Text('No se pudo armar el PDF. Intenta de nuevo.')),
      );
    } finally {
      if (mounted) setState(() => _armando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BotonPrincipal(
      texto: 'Enviar el cierre en PDF',
      cargando: _armando,
      onPressed: _enviar,
    );
  }
}

class _Ganancia extends StatelessWidget {
  const _Ganancia({
    required this.cuentas,
    required this.cerrado,
    required this.delAnio,
    required this.anio,
  });

  final CuentasLote cuentas;
  final bool cerrado;

  /// Los lotes cerrados este año, para comparar.
  final List<CuentasLote> delAnio;
  final int anio;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    final ganancia = cuentas.ganancia;
    final gano = ganancia >= 0;
    final margen = cuentas.margen;
    final resumen = ResumenPeriodo(delAnio);
    final esElMejor = cerrado && resumen.esElMejor(cuentas);
    final otros = ResumenPeriodo([
      for (final c in delAnio)
        if (c.lote.id != cuentas.lote.id) c,
    ]);
    final etiqueta = switch ((cerrado, gano)) {
      (true, true) => 'Lote cerrado · ganaste',
      (true, false) => 'Lote cerrado · perdiste',
      (false, true) => 'Vas ganando',
      (false, false) => 'Falta para recuperar lo invertido',
    };
    final total = max(cuentas.ventas, cuentas.invertido);

    final tarjeta = TarjetaTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(etiqueta, style: apoyo)),
              if (esElMejor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: e8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColoresGranja.maiz,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Tu mejor lote de $anio',
                    style: conPeso(textos.bodySmall!.copyWith(color: ColoresGranja.tinta), 700),
                  ),
                ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              plata(ganancia.abs()),
              style: textos.displaySmall!.copyWith(
                color: gano ? ColoresGranja.maiz : ColoresGranja.graneroClaro,
              ),
            ),
          ),
          const SizedBox(height: e12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Vendiste', style: apoyo),
              Text(
                plata(cuentas.ventas),
                style: conPeso(textos.bodyMedium!.copyWith(color: ColoresGranja.crema), 700),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: e8),
            SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, cuentas.invertido * 1000 ~/ total),
                    child: _Pedazo(color: ColoresGranja.granero),
                  ),
                  if (gano && ganancia > 0) ...[
                    const SizedBox(width: 3),
                    Expanded(
                      flex: max(1, ganancia * 1000 ~/ total),
                      child: _Pedazo(color: ColoresGranja.maiz),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: e4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Invertiste ${plata(cuentas.invertido)}', style: apoyo)),
              if (margen != null)
                Text(
                  '${gano ? 'Ganaste' : 'Perdiste'} el ${decimal(margen.abs())} %',
                  style: conPeso(
                    textos.bodySmall!.copyWith(
                      color: gano ? ColoresGranja.maiz : ColoresGranja.graneroClaro,
                    ),
                    700,
                  ),
                ),
            ],
          ),
          if (otros.lotes.isNotEmpty && otros.margen != null) ...[
            const SizedBox(height: e12),
            Text(
              'Tus ${otros.lotes.length == 1 ? 'otro lote' : '${otros.lotes.length} otros lotes'} '
              'de $anio dejaron en promedio ${decimal(otros.margen!)} % de ganancia con '
              '${decimal(otros.mortalidad ?? 0)} % de mortalidad.',
              style: apoyo,
            ),
          ],
        ],
      ),
    );
    if (!cerrado || ganancia <= 0) return tarjeta;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tarjeta,
        const Positioned(
          top: -48,
          right: e8,
          child: Gallo(tamano: 60, gesto: Gesto.cantando),
        ),
      ],
    );
  }
}

class _Pedazo extends StatelessWidget {
  const _Pedazo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      );
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child, this.sinTarjeta = false});

  final String titulo;
  final Widget child;

  /// Para lo que ya trae sus propias tarjetas.
  final bool sinTarjeta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: e4, bottom: e8),
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (sinTarjeta)
            child
          else
            Container(
              padding: const EdgeInsets.all(e16),
              decoration: BoxDecoration(
                color: ColoresGranja.papel,
                borderRadius: BorderRadius.circular(radioTarjeta),
                border: Border.all(color: ColoresGranja.borde),
              ),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _LineaDeTiempo extends StatelessWidget {
  const _LineaDeTiempo({required this.cuentas, required this.clientes});

  final CuentasLote cuentas;
  final Map<String, String> clientes;

  @override
  Widget build(BuildContext context) {
    final lote = cuentas.lote;
    final cierre = lote.cerradoEn?.toLocal();
    String dia(DateTime fecha) => 'día ${lote.diasDeEdad(fecha)}';
    final eventos = <(DateTime, String, Color)>[
      (
        lote.fechaLlegada,
        'Llegaron ${miles(lote.cantidadInicial)} pollitos a ${plata(lote.costoPorPollito)} cada uno',
        ColoresGranja.maiz,
      ),
      if (cuentas.primerEngorde case final engorde?)
        (engorde, 'Pasaron a alimento de engorde', ColoresGranja.granero),
      if (cuentas.primeraVenta case final venta?)
        (
          venta.fecha,
          'Primera venta${clientes[venta.clienteId] == null ? '' : ', a ${clientes[venta.clienteId]}'}',
          ColoresGranja.pasto,
        ),
      if (cierre != null)
        (
          cierre,
          cuentas.faltantes > 0
              ? 'Se cerró el lote; faltaron ${miles(cuentas.faltantes)} pollos'
              : 'Se cerró el lote',
          ColoresGranja.tinta,
        ),
    ];
    final textos = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final (i, (fecha, texto, color)) in eventos.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: e20,
                  child: Column(
                    children: [
                      const SizedBox(height: e4),
                      Container(
                        width: e12,
                        height: e12,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      if (i < eventos.length - 1)
                        const Expanded(child: VerticalDivider(width: 2, thickness: 2, color: ColoresGranja.surco)),
                    ],
                  ),
                ),
                const SizedBox(width: e8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: e12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fechaCorta(fecha)} · ${dia(fecha)}', style: conPeso(textos.bodyMedium!, 700)),
                        Text(texto, style: textos.bodyMedium),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Inversion extends StatelessWidget {
  const _Inversion(this.cuentas);

  final CuentasLote cuentas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final invertido = cuentas.invertido;
    String parte(int valor) =>
        invertido == 0 ? '' : '${(valor * 100 / invertido).round()} % de lo invertido';
    String bultos(int n, double kilos) =>
        '${miles(n)} ${n == 1 ? 'bulto' : 'bultos'} · ${decimal(kilos)} kg';
    final filas = [
      (
        const IconoModulo(Figura.galpon, fondo: ColoresGranja.graneroClaro, color: ColoresGranja.granero, tamano: 38),
        'Pollitos · ${miles(cuentas.lote.cantidadInicial)}',
        parte(cuentas.lote.precioCompraTotal),
        cuentas.lote.precioCompraTotal,
      ),
      (
        const IconoModulo(Figura.bulto, tamano: 38),
        'Alimento de inicio',
        bultos(cuentas.bultosInicio, cuentas.kilosInicio),
        cuentas.alimentoInicio,
      ),
      (
        const IconoModulo(Figura.bulto, fondo: ColoresGranja.granero, color: ColoresGranja.papel, tamano: 38),
        'Alimento de engorde',
        bultos(cuentas.bultosEngorde, cuentas.kilosEngorde),
        cuentas.alimentoEngorde,
      ),
      (
        const IconoModulo(Figura.capsula, fondo: ColoresGranja.lilaClaro, color: ColoresGranja.lilaOscuro, tamano: 38),
        'Medicamentos',
        cuentas.medicinas == 1 ? '1 compra' : '${cuentas.medicinas} compras',
        cuentas.medicina,
      ),
    ];
    final cifra = conPeso(
      textos.bodyLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      700,
    );
    return Column(
      children: [
        for (final (icono, nombre, detalle, valor) in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: e12),
            child: Row(
              children: [
                icono,
                const SizedBox(width: e12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: textos.bodyLarge),
                      Text(detalle, style: textos.bodySmall),
                    ],
                  ),
                ),
                Text(plata(valor), style: cifra),
              ],
            ),
          ),
        const Divider(height: 1, thickness: 2, color: ColoresGranja.tinta),
        const SizedBox(height: e12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Total invertido', style: textos.titleMedium),
            Text(plata(invertido), style: textos.titleLarge),
          ],
        ),
      ],
    );
  }
}

class _Indicadores extends StatelessWidget {
  const _Indicadores(this.cuentas);

  final CuentasLote cuentas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final conversion = cuentas.conversion;
    final mortalidadAlta = cuentas.mortalidad >= 5;
    final tarjetas = [
      ('Vendidos', miles(cuentas.vendidos), 'de ${miles(cuentas.lote.cantidadInicial)}', null),
      (
        'Mortalidad',
        '${decimal(cuentas.mortalidad)} %',
        [
          '${miles(cuentas.muertos)} pollos',
          if (cuentas.faltantes > 0) '${miles(cuentas.faltantes)} faltantes',
        ].join(' · '),
        mortalidadAlta ? ColoresGranja.granero : null,
      ),
      (
        'Peso promedio',
        cuentas.pesoPromedio == null ? '—' : '${decimal(cuentas.pesoPromedio!)} lb',
        '${decimal(cuentas.librasVendidas)} lb vendidas',
        null,
      ),
      (
        'Conversión',
        conversion == null ? '—' : dosDecimales(conversion),
        'kg de alimento por kg de pollo',
        conversion != null && conversion > CuentasLote.conversionNormal ? ColoresGranja.granero : null,
      ),
      (
        'Te costó cada pollo',
        cuentas.costoPorPollo == null ? '—' : plata(cuentas.costoPorPollo!),
        cuentas.costoPorLibra == null ? '' : '${plata(cuentas.costoPorLibra!)} por libra',
        null,
      ),
      (
        (cuentas.gananciaPorPollo ?? 0) >= 0 ? 'Ganaste por pollo' : 'Perdiste por pollo',
        cuentas.gananciaPorPollo == null ? '—' : plata(cuentas.gananciaPorPollo!.abs()),
        cuentas.precioPromedioLibra == null
            ? ''
            : 'vendido a ${plata(cuentas.precioPromedioLibra!.round())} la libra',
        (cuentas.gananciaPorPollo ?? 0) >= 0 ? ColoresGranja.pasto : ColoresGranja.granero,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, medidas) => Wrap(
            spacing: e8,
            runSpacing: e8,
            children: [
              for (final (titulo, cifra, detalle, color) in tarjetas)
                Container(
                  width: (medidas.maxWidth - e8) / 2,
                  padding: const EdgeInsets.all(e12),
                  decoration: BoxDecoration(
                    color: ColoresGranja.papel,
                    borderRadius: BorderRadius.circular(e16),
                    border: Border.all(color: ColoresGranja.borde),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: textos.bodySmall),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(cifra, style: textos.titleLarge!.copyWith(color: color)),
                      ),
                      if (detalle.isNotEmpty) Text(detalle, style: textos.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (conversion != null && conversion > CuentasLote.conversionNormal) ...[
          const SizedBox(height: e12),
          Text(
            'La conversión salió por encima de lo habitual para pollo de engorde '
            '(alrededor de 1,6 a 1,9): vale la pena revisar si se desperdicia alimento '
            'o si los pollos salieron livianos.',
            style: textos.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Causas extends StatelessWidget {
  const _Causas(this.cuentas);

  final CuentasLote cuentas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final filas = [
      for (final MapEntry(key: causa, value: cantidad) in cuentas.causas.entries)
        (nombreDeCausa(causa), cantidad),
      if (cuentas.faltantes > 0) ('Faltaron (no aparecieron)', cuentas.faltantes),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final mayor = filas.fold(1, (m, f) => max(m, f.$2));
    return Column(
      children: [
        for (final (nombre, cantidad) in filas)
          Padding(
            padding: const EdgeInsets.only(bottom: e8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(nombre, style: textos.bodyMedium),
                    Text(miles(cantidad), style: conPeso(textos.bodyMedium!, 700)),
                  ],
                ),
                const SizedBox(height: e4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const ColoredBox(color: ColoresGranja.surco),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: cantidad / mayor,
                          child: const ColoredBox(color: ColoresGranja.granero),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PorCliente extends StatelessWidget {
  const _PorCliente({required this.cuentas, required this.clientes});

  final CuentasLote cuentas;
  final Map<String, String> clientes;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final (i, venta) in cuentas.ventasPorCliente.indexed) ...[
          if (i > 0) const Divider(height: e16, color: ColoresGranja.borde),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: ColoresGranja.maizClaro, shape: BoxShape.circle),
                child: Text(
                  iniciales(clientes[venta.clienteId] ?? '?'),
                  style: conPeso(textos.bodySmall!.copyWith(color: ColoresGranja.maizOscuro), 800),
                ),
              ),
              const SizedBox(width: e12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(clientes[venta.clienteId] ?? 'Cliente', style: textos.titleMedium),
                    Text(
                      '${miles(venta.pollos)} pollos · ${decimal(venta.libras)} lb · '
                      '${plata((venta.total / venta.libras).round())} la libra',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                plata(venta.total),
                style: conPeso(
                  textos.bodyLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
