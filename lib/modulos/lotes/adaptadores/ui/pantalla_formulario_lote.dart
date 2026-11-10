import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../registros/dominio/cuentas_lote.dart';
import '../../dominio/lote.dart';

/// Registrar los pollitos que llegaron, o corregir un lote que ya existe.
class PantallaFormularioLote extends ConsumerStatefulWidget {
  const PantallaFormularioLote({super.key, this.loteId, this.galponId});

  /// Null para registrar un lote nuevo.
  final String? loteId;

  /// El galpón ya elegido, cuando se llega desde su pantalla.
  final String? galponId;

  @override
  ConsumerState<PantallaFormularioLote> createState() =>
      _PantallaFormularioLoteState();
}

class _PantallaFormularioLoteState extends ConsumerState<PantallaFormularioLote> {
  final _pollitos = TextEditingController();
  final _precio = TextEditingController();
  late DateTime _llegada;
  String? _galponId;
  Lote? _original;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _llegada = DateTime(hoy.year, hoy.month, hoy.day);
    _galponId = widget.galponId;
    final lotes = ref.read(lotesProvider).asData?.value ?? const <Lote>[];
    if (lotes.where((l) => l.id == widget.loteId).firstOrNull case final lote?) {
      final llegada = lote.fechaLlegada;
      _original = lote;
      _galponId = lote.galponId;
      _llegada = DateTime(llegada.year, llegada.month, llegada.day);
      _pollitos.text = miles(lote.cantidadInicial);
      _precio.text = miles(lote.precioCompraTotal);
    }
    // El costo por pollito se calcula mientras la persona escribe.
    _pollitos.addListener(_redibujar);
    _precio.addListener(_redibujar);
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    _pollitos.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final granja = ref.read(granjaActualProvider);
    final galponId = _galponId;
    final pollitos = leerEntero(_pollitos.text);
    final precio = leerEntero(_precio.text);
    if (granja == null) return;
    if (galponId == null) {
      setState(() => _error = 'Elige el galpón donde van a vivir.');
      return;
    }
    if (pollitos == null || precio == null) {
      setState(
        () => _error = pollitos == null
            ? 'Escribe cuántos pollitos llegaron.'
            : 'Escribe cuánto pagaste por todos.',
      );
      return;
    }
    final original = _original;
    if (original != null) {
      final cuentas = _cuentas(original);
      final primero = cuentas.primerRegistro;
      if (pollitos < cuentas.muertos + cuentas.vendidos) {
        setState(
          () => _error = 'Ya salieron ${miles(cuentas.muertos + cuentas.vendidos)} '
              'pollos de este lote entre muertos y vendidos.',
        );
        return;
      }
      if (primero != null &&
          DateTime.utc(_llegada.year, _llegada.month, _llegada.day).isAfter(primero)) {
        setState(
          () => _error = 'Hay registros desde el ${fechaCorta(primero)}: '
              'los pollitos tuvieron que llegar antes.',
        );
        return;
      }
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (original == null) {
        await ref.read(crearLoteProvider)(
          granjaId: granja.id,
          galponId: galponId,
          fechaLlegada: _llegada,
          cantidadInicial: pollitos,
          precioCompraTotal: precio,
        );
      } else {
        await ref.read(repositorioLotesProvider).guardar(
              Lote.nuevo(
                id: original.id,
                granjaId: original.granjaId,
                galponId: original.galponId,
                fechaLlegada: _llegada,
                cantidadInicial: pollitos,
                precioCompraTotal: precio,
                hoy: DateTime.now(),
              ),
            );
      }
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on LoteInvalido catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  CuentasLote _cuentas(Lote lote) =>
      CuentasLote(lote, ref.read(registrosProvider).asData?.value ?? const []);

  Future<void> _borrar(Lote lote) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar el lote del ${fechaCorta(lote.fechaLlegada)}?',
      detalle: 'Úsalo solo si se registró por error. No se puede deshacer.',
      accion: 'Borrar lote',
    );
    if (!acepto) return;
    await ref.read(repositorioLotesProvider).borrar(lote);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final galpones = ref.watch(galponesProvider).asData?.value ?? const <GalponConLote>[];
    final original = _original;
    final pollitos = leerEntero(_pollitos.text);
    final elegido = galpones.where((g) => g.galpon.id == _galponId).firstOrNull?.galpon;
    final caben = elegido?.capacidad;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(
              titulo: original == null ? 'Nuevo lote' : 'Corregir lote',
              subtitulo: original == null ? 'Llegaron pollitos nuevos' : elegido?.nombre,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (original == null) ...[
                  Text('Galpón', style: conPeso(textos.bodyMedium!, 700)),
                  const SizedBox(height: e8),
                  if (galpones.isEmpty)
                    Text('Primero agrega un galpón.', style: textos.bodySmall)
                  else
                    LayoutBuilder(
                      builder: (context, medidas) => Wrap(
                        spacing: e12,
                        runSpacing: e12,
                        children: [
                          for (final (:galpon, :lote, cuentas: _) in galpones)
                            SizedBox(
                              width: (medidas.maxWidth - e12) / 2,
                              child: _OpcionGalpon(
                                nombre: galpon.nombre,
                                diasDelLote: lote?.diasDeEdad(DateTime.now()),
                                elegido: galpon.id == _galponId,
                                alElegir: () => setState(() => _galponId = galpon.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.push('/galpones/nuevo'),
                      child: const Text('Agregar otro galpón'),
                    ),
                  ),
                  const SizedBox(height: e8),
                ],
                CampoGranja(
                  etiqueta: 'Pollitos que llegaron',
                  controller: _pollitos,
                  pista: 'Ej.: 500',
                  teclado: TextInputType.number,
                  formatos: const [MilesAlEscribir()],
                ),
                if (caben != null && pollitos != null && pollitos > caben) ...[
                  const SizedBox(height: e8),
                  AvisoAtencion(
                    'En ${elegido?.nombre} caben ${miles(caben)} pollos y este '
                    'lote trae ${miles(pollitos)}.',
                  ),
                ],
                const SizedBox(height: e16),
                Text('Fecha de llegada', style: conPeso(textos.bodyMedium!, 700)),
                const SizedBox(height: e8),
                SelectorFecha(
                  fecha: _llegada,
                  alCambiar: (fecha) => setState(() => _llegada = fecha),
                ),
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Lo que pagaste por todos',
                  controller: _precio,
                  pista: 'Ej.: 1.750.000',
                  teclado: TextInputType.number,
                  formatos: const [MilesAlEscribir()],
                ),
                const SizedBox(height: e20),
                _ResumenLote(
                  pollitos: pollitos,
                  precio: leerEntero(_precio.text),
                  llegada: _llegada,
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: e12),
                  AvisoError(error),
                ],
                const SizedBox(height: e20),
                BotonPrincipal(
                  texto: 'Guardar lote',
                  cargando: _guardando,
                  onPressed: _guardar,
                ),
                // Un lote con registros no se borra: se corrige o se cierra.
                if (original != null && !_cuentas(original).tieneRegistros)
                  Center(
                    child: TextButton(
                      onPressed: () => _borrar(original),
                      child: const Text('Borrar este lote'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionGalpon extends StatelessWidget {
  const _OpcionGalpon({
    required this.nombre,
    required this.diasDelLote,
    required this.elegido,
    required this.alElegir,
  });

  final String nombre;

  /// Null si el galpón está libre.
  final int? diasDelLote;
  final bool elegido;
  final VoidCallback alElegir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final ocupado = diasDelLote != null;
    return Semantics(
      selected: elegido,
      inMutuallyExclusiveGroup: true,
      child: Pulsable(
        onTap: ocupado ? null : alElegir,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: e12, vertical: e12),
          decoration: BoxDecoration(
            color: ocupado ? ColoresGranja.surco : ColoresGranja.papel,
            borderRadius: BorderRadius.circular(e16),
            border: Border.all(
              color: elegido ? ColoresGranja.granero : ColoresGranja.borde,
              width: elegido ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: textos.titleMedium!.copyWith(
                  color: ocupado ? ColoresGranja.tintaSuave : ColoresGranja.tinta,
                ),
                maxLines: 2,
              ),
              Text(
                ocupado ? 'Ocupado · día $diasDelLote' : 'Libre',
                style: ocupado
                    ? textos.bodySmall
                    : conPeso(textos.bodySmall!.copyWith(color: ColoresGranja.pasto), 600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenLote extends StatelessWidget {
  const _ResumenLote({
    required this.pollitos,
    required this.precio,
    required this.llegada,
  });

  final int? pollitos;
  final int? precio;
  final DateTime llegada;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final pollitos = this.pollitos;
    final precio = this.precio;
    String? costo;
    String? cuenta;
    if (pollitos != null && pollitos > 0 && precio != null) {
      costo = plata((precio / pollitos).round());
      cuenta = '${plata(precio)} ÷ ${miles(pollitos)} '
          '${pollitos == 1 ? 'pollito' : 'pollitos'}';
    }
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    final dato = conPeso(textos.bodyMedium!.copyWith(color: ColoresGranja.crema), 700);

    Widget fila(String etiqueta, int dia) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiqueta, style: apoyo),
            Text(
              '${fechaCorta(DateTime(llegada.year, llegada.month, llegada.day + dia))} · día $dia',
              style: dato,
            ),
          ],
        );

    return TarjetaTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CifraTicket(
            etiqueta: 'Cada pollito te costó',
            cifra: costo ?? '—',
            detalle: cuenta,
          ),
          const SizedBox(height: e12),
          fila('Cambio a engorde', 22),
          const SizedBox(height: e8),
          fila('Venta cerca del', 45),
        ],
      ),
    );
  }
}
