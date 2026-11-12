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
import '../../../../compartido/diseno/icono_modulo.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../clientes/dominio/cliente.dart';
import '../../../granja/dominio/granja.dart';
import '../../../lotes/dominio/lote.dart';
import '../../../registros/dominio/cuentas_lote.dart';
import '../../../registros/dominio/registro.dart';
import '../../dominio/galpon.dart';

/// Un galpón por dentro: el lote que tiene hoy, lo que se ha anotado en él y
/// los lotes que ya pasaron.
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

    final (:galpon, :lote, :cuentas) = encontrado;
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
            tarjeta: lote == null || cuentas == null || dias == null
                ? _GalponLibre(galpon)
                : _LoteDeHoy(cuentas: cuentas, dias: dias),
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
          if (lote != null && cuentas != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e12, e16, 0),
              child: _Invertido(cuentas),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(e20, e24, e20, e12),
              child: Text('Registrar', style: textos.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: e16),
              child: _BotonesRegistrar(loteId: lote.id),
            ),
            _Movimientos(granja: granja, loteId: lote.id),
            if (administra)
              Padding(
                padding: const EdgeInsets.fromLTRB(e16, e24, e16, 0),
                child: Column(
                  children: [
                    BotonSecundario(
                      texto: 'Cerrar lote',
                      onPressed: () => _cerrar(context, ref, galpon, cuentas),
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
              child: _Lista(
                filas: [
                  for (final (i, anterior) in anteriores.indexed)
                    _FilaLoteAnterior(
                      lote: anterior,
                      // Solo el último, y solo si el galpón sigue libre:
                      // dos lotes abiertos no caben en un galpón.
                      alReabrir: administra && lote == null && i == 0
                          ? () => _reabrir(context, ref, galpon, anterior)
                          : null,
                    ),
                ],
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
    CuentasLote cuentas,
  ) async {
    final quedan = cuentas.vivos;
    final acepto = await confirmar(
      context,
      titulo: '¿Cerrar el lote de ${galpon.nombre}?',
      detalle: [
        if (quedan > 0)
          'Todavía quedan ${miles(quedan)} pollos vivos en las cuentas del lote.',
        'Ya no se podrá anotar nada en este lote y el galpón queda libre para '
            'pollitos nuevos. Si fue un error, lo puedes reabrir.',
      ].join(' '),
      accion: 'Cerrar lote',
    );
    if (!acepto) return;
    await ref.read(repositorioLotesProvider).guardar(cuentas.lote.cerrar(DateTime.now()));
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
  const _LoteDeHoy({required this.cuentas, required this.dias});

  final CuentasLote cuentas;
  final int dias;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    Widget columna(String cifra, String etiqueta, {Color? color}) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(cifra, style: textos.headlineSmall!.copyWith(color: color)),
              ),
              Text(etiqueta, style: textos.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );

    return _TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              columna(miles(cuentas.vivos), 'vivos'),
              columna(
                miles(cuentas.muertos),
                'muertos · ${decimal(cuentas.mortalidad)} %',
                color: ColoresGranja.granero,
              ),
              columna(miles(cuentas.vendidos), 'vendidos'),
            ],
          ),
          const SizedBox(height: e16),
          BarraEtapa(dias: dias, conEtiquetas: true),
          if (cuentas.tocaCambiarAEngorde(DateTime.now())) ...[
            const SizedBox(height: e12),
            Pulsable(
              onTap: () => context.push('/lotes/${cuentas.lote.id}/alimento'),
              child: const AvisoAtencion('Toca cambiar a alimento de engorde. Toca para anotar la compra.'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Invertido extends StatelessWidget {
  const _Invertido(this.cuentas);

  final CuentasLote cuentas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final partes = [
      ('Pollitos', cuentas.lote.precioCompraTotal, ColoresGranja.crema),
      ('Alimento', cuentas.alimento, ColoresGranja.maiz),
      ('Medicina', cuentas.medicina, ColoresGranja.lila),
    ];
    final total = cuentas.invertido;

    return TarjetaTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CifraTicket(etiqueta: 'Invertido hasta hoy', cifra: plata(total)),
          if (total > 0) ...[
            const SizedBox(height: e12),
            SizedBox(
              height: e8,
              child: Row(
                children: [
                  for (final (_, valor, color) in partes)
                    if (valor > 0)
                      Expanded(
                        // Ningún pedazo tan delgado que no se vea.
                        flex: (valor * 1000 ~/ total).clamp(20, 1000),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(e4),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
          const SizedBox(height: e12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (nombre, valor, color) in partes)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: e8,
                            height: e8,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              nombre,
                              style: textos.bodySmall!.copyWith(
                                color: ColoresGranja.textoSobreTinta,
                              ),
                            ),
                          ),
                        ],
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          plata(valor),
                          style: conPeso(
                            textos.bodyMedium!.copyWith(
                              color: ColoresGranja.crema,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                            700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (cuentas.ventas > 0) ...[
            const SizedBox(height: e12),
            const Divider(height: 1, color: ColoresGranja.textoSobreTinta),
            const SizedBox(height: e12),
            Text(
              'Vendido hasta hoy: ${plata(cuentas.ventas)} · '
              '${miles(cuentas.vendidos)} pollos, ${decimal(cuentas.librasVendidas)} lb',
              style: conPeso(textos.bodyMedium!.copyWith(color: ColoresGranja.crema), 700),
            ),
            Text(
              cuentas.ganancia >= 0
                  ? 'Ya recuperaste lo invertido y vas ganando ${plata(cuentas.ganancia)}.'
                  : 'Faltan ${plata(-cuentas.ganancia)} para recuperar lo invertido.',
              style: textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta),
            ),
          ],
        ],
      ),
    );
  }
}

class _BotonesRegistrar extends StatelessWidget {
  const _BotonesRegistrar({required this.loteId});

  final String loteId;

  @override
  Widget build(BuildContext context) {
    final botones = [
      (
        'Alimento',
        'Bultos',
        const IconoModulo(Figura.bulto, tamano: 42),
        '/lotes/$loteId/alimento',
      ),
      (
        'Venta',
        'Por libras',
        const IconoModulo(
          Figura.balanza,
          fondo: ColoresGranja.pastoClaro,
          color: ColoresGranja.pasto,
          tamano: 42,
        ),
        '/lotes/$loteId/venta',
      ),
      (
        'Mortalidad',
        'Pollos muertos',
        const IconoModulo(
          Figura.muerto,
          fondo: ColoresGranja.graneroClaro,
          color: ColoresGranja.granero,
          tamano: 42,
        ),
        '/lotes/$loteId/muertos',
      ),
      (
        'Medicina',
        'Si enferman',
        const IconoModulo(
          Figura.capsula,
          fondo: ColoresGranja.lilaClaro,
          color: ColoresGranja.lilaOscuro,
          tamano: 42,
        ),
        '/lotes/$loteId/medicina',
      ),
    ];
    final textos = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, medidas) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (titulo, ayuda, icono, ruta) in botones)
            SizedBox(
              width: (medidas.maxWidth - 10) / 2,
              child: Pulsable(
                onTap: () => context.push(ruta),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ColoresGranja.papel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ColoresGranja.borde),
                  ),
                  child: Row(
                    children: [
                      icono,
                      const SizedBox(width: e12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(titulo, style: textos.titleMedium),
                            Text(ayuda, style: textos.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Movimientos extends ConsumerWidget {
  const _Movimientos({required this.granja, required this.loteId});

  final Granja granja;
  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registros = [
      for (final registro in ref.watch(registrosProvider).asData?.value ?? const <Registro>[])
        if (registro.loteId == loteId) registro,
    ];
    if (registros.isEmpty) return const SizedBox.shrink();
    final miId = ref.watch(usuarioIdProvider);
    // Sin señal no hay nombres, y basta con decir que lo anotó otra persona.
    final nombres = {
      for (final miembro in ref.watch(miembrosProvider(granja.id)).asData?.value ?? const <Miembro>[])
        miembro.usuarioId: ?miembro.nombre,
    };
    final clientes = {
      for (final cuenta in ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[])
        cuenta.cliente.id: cuenta.cliente.nombre,
    };
    final nombreDeMarca = ref.watch(nombreDeMarcaProvider);
    String quien(Registro registro) => switch (registro.creadoPor) {
          final id? when id == miId => 'registraste tú',
          final id? when nombres[id] != null => 'registró ${nombres[id]}',
          _ => 'registró otra persona',
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(e20, e24, e20, e12),
          child: Text('Últimos movimientos', style: Theme.of(context).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: e16),
          child: _Lista(
            filas: [
              for (final registro in registros)
                _FilaMovimiento(
                  registro: registro,
                  quien: quien(registro),
                  cliente: registro is Venta ? clientes[registro.clienteId] : null,
                  marca: registro is CompraAlimento ? nombreDeMarca(registro) : null,
                  alTocar: registro.puedeCambiarlo(
                    administra: granja.rol.administra,
                    usuarioId: miId,
                  )
                      ? () => context.push(_rutaParaCorregir(registro))
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _rutaParaCorregir(Registro registro) => switch (registro) {
        CompraAlimento() => '/lotes/$loteId/alimento/${registro.id}',
        Mortalidad() => '/lotes/$loteId/muertos/${registro.id}',
        Medicamento() => '/lotes/$loteId/medicina/${registro.id}',
        Venta() => '/lotes/$loteId/venta/${registro.id}',
      };
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.registro,
    required this.quien,
    required this.alTocar,
    this.cliente,
    this.marca,
  });

  final Registro registro;
  final String quien;

  /// A quién se le vendió, si es una venta.
  final String? cliente;

  /// El nombre de la marca como está en la lista, si es una compra.
  final String? marca;

  /// Null si la persona no puede corregir este registro.
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final (icono, titulo, valor, colorValor) = switch (registro) {
      CompraAlimento c => (
          c.tipo == TipoAlimento.inicio
              ? const IconoModulo(Figura.bulto, tamano: 40)
              : const IconoModulo(
                  Figura.bulto,
                  fondo: ColoresGranja.granero,
                  color: ColoresGranja.papel,
                  tamano: 40,
                ),
          '${c.bultos} ${c.bultos == 1 ? 'bulto' : 'bultos'} de ${c.tipo.name} · ${marca ?? c.marca}',
          plata(c.total),
          ColoresGranja.tinta,
        ),
      Mortalidad m => (
          const IconoModulo(
            Figura.muerto,
            fondo: ColoresGranja.graneroClaro,
            color: ColoresGranja.granero,
            tamano: 40,
          ),
          [
            '${m.cantidad} ${m.cantidad == 1 ? 'muerto' : 'muertos'}',
            if (m.causa case final causa?) causa.etiqueta.toLowerCase(),
          ].join(' · '),
          '−${m.cantidad}',
          ColoresGranja.granero,
        ),
      Medicamento m => (
          const IconoModulo(
            Figura.capsula,
            fondo: ColoresGranja.lilaClaro,
            color: ColoresGranja.lilaOscuro,
            tamano: 40,
          ),
          m.nombre,
          plata(m.costo),
          ColoresGranja.tinta,
        ),
      Venta v => (
          const IconoModulo(
            Figura.balanza,
            fondo: ColoresGranja.pastoClaro,
            color: ColoresGranja.pasto,
            tamano: 40,
          ),
          [
            '${v.pollos} ${v.pollos == 1 ? 'pollo' : 'pollos'}',
            ?cliente,
            if (v.fiado) 'fiado',
          ].join(' · '),
          plata(v.total),
          ColoresGranja.pasto,
        ),
    };

    return Pulsable(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: e16, vertical: 14),
        child: Row(
          children: [
            icono,
            const SizedBox(width: e12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: textos.titleMedium, maxLines: 2),
                  Text('${fechaCorta(registro.fecha)} · $quien', style: textos.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: e8),
            Text(
              valor,
              style: conPeso(
                textos.bodyLarge!.copyWith(
                  color: colorValor,
                  fontFeatures: const [FontFeature.tabularFigures()],
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

/// Tarjeta blanca con filas separadas por una línea fina.
class _Lista extends StatelessWidget {
  const _Lista({required this.filas});

  final List<Widget> filas;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioTarjeta),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Column(
        children: [
          for (final (i, fila) in filas.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: e16,
                endIndent: e16,
                color: ColoresGranja.borde,
              ),
            fila,
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
