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
import '../../../../compartido/diseno/fichas.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../granja/dominio/granja.dart';
import '../../dominio/cliente.dart';

/// Anotar la plata que pagó un cliente de lo que debía, o corregirla.
class PantallaAbono extends ConsumerStatefulWidget {
  const PantallaAbono({super.key, required this.clienteId, this.abonoId});

  final String clienteId;

  /// Null para anotar uno nuevo.
  final String? abonoId;

  @override
  ConsumerState<PantallaAbono> createState() => _PantallaAbonoState();
}

class _PantallaAbonoState extends ConsumerState<PantallaAbono> {
  final _valor = TextEditingController();
  var _fecha = DateTime.now();
  String? _recibio;
  Abono? _original;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recibio = ref.read(usuarioIdProvider);
    final cuenta = ref.read(cuentaClienteProvider(widget.clienteId));
    if (cuenta?.abonos.where((a) => a.id == widget.abonoId).firstOrNull case final abono?) {
      _original = abono;
      _valor.text = miles(abono.valor);
      _fecha = abono.fecha;
      _recibio = abono.recibidoPor;
    }
    _valor.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _guardar(CuentaCliente cuenta) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final abono = Abono.nuevo(
        id: _original?.id ?? nuevoId(),
        cliente: cuenta.cliente,
        fecha: _fecha,
        valor: leerEntero(_valor.text) ?? 0,
        recibidoPor: _recibio,
        debeSinEste: cuenta.debeSin(_original),
        hoy: DateTime.now(),
      );
      await ref
          .read(repositorioClientesProvider)
          .guardarAbono(abono, nombreCliente: cuenta.cliente.nombre);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on ClienteInvalido catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Abono abono, Cliente cliente) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar el abono de ${plata(abono.valor)} del ${fechaCorta(abono.fecha)}?',
      detalle: '${cliente.nombre} vuelve a deber esa plata.',
      accion: 'Borrar abono',
    );
    if (!acepto) return;
    await ref
        .read(repositorioClientesProvider)
        .borrarAbono(abono, nombreCliente: cliente.nombre);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = ref.watch(cuentaClienteProvider(widget.clienteId));
    if (cuenta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final cliente = cuenta.cliente;
    final original = _original;
    final debe = cuenta.debeSin(original);
    final valor = leerEntero(_valor.text) ?? 0;
    final teDeben = (ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[])
        .fold(0, (suma, c) => suma + (c.alDia ? 0 : c.debe));
    final teDebenSinEste = teDeben - cuenta.debe + debe;
    final granja = ref.watch(granjaActualProvider);
    final miId = ref.watch(usuarioIdProvider);
    final personas = granja == null
        ? const <Miembro>[]
        : ref.watch(miembrosProvider(granja.id)).asData?.value ?? const <Miembro>[];
    final quienes = [
      ?miId,
      for (final persona in personas)
        if (persona.usuarioId != miId) persona.usuarioId,
    ];
    final nombres = {for (final p in personas) p.usuarioId: p.nombre};
    final rapidos = {
      debe,
      for (final monto in [200000, 100000, 50000])
        if (monto < debe) monto,
    }.toList();
    final textos = Theme.of(context).textTheme;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(
              titulo: 'Abono de ${cliente.nombre}',
              subtitulo: [?cliente.detalle, 'debe ${plata(debe)}'].join(' · '),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoGranja(
                  etiqueta: 'Cuánto pagó',
                  controller: _valor,
                  pista: 'Ej.: 200.000',
                  teclado: TextInputType.number,
                  formatos: const [MilesAlEscribir()],
                ),
                if (debe > 0) ...[
                  const SizedBox(height: e8),
                  FichasOpcion<int>(
                    opciones: rapidos,
                    elegida: valor,
                    etiqueta: (monto) =>
                        monto == debe ? 'Todo · ${plata(monto)}' : plata(monto),
                    alElegir: (monto) => _valor.text = miles(monto),
                  ),
                ],
                if (quienes.length > 1) ...[
                  const SizedBox(height: e16),
                  Text('Quién recibió la plata', style: conPeso(textos.bodyMedium!, 700)),
                  const SizedBox(height: e8),
                  FichasOpcion<String>(
                    opciones: quienes,
                    elegida: _recibio,
                    etiqueta: (id) => id == miId ? 'Tú' : nombres[id] ?? 'Sin nombre',
                    alElegir: (id) => setState(() => _recibio = id),
                  ),
                ],
                const SizedBox(height: e16),
                Text('Fecha del pago', style: conPeso(textos.bodyMedium!, 700)),
                const SizedBox(height: e8),
                SelectorFecha(
                  fecha: _fecha,
                  alCambiar: (fecha) => setState(() => _fecha = fecha),
                ),
                const SizedBox(height: e20),
                TarjetaTicket(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CifraTicket(
                        etiqueta: debe - valor == 0 ? 'Queda' : 'Quedará debiendo',
                        cifra: debe - valor == 0 ? 'Al día' : plata(debe - valor),
                        detalle: '${plata(debe)} − ${plata(valor)}',
                        color: debe - valor == 0 ? ColoresGranja.pastoClaro : ColoresGranja.maiz,
                      ),
                      const SizedBox(height: e12),
                      Text(
                        'Te deberán en total: ${plata(teDebenSinEste - (valor > debe ? 0 : valor))}',
                        style: apoyo,
                      ),
                    ],
                  ),
                ),
                if (valor > debe) ...[
                  const SizedBox(height: e12),
                  AvisoAtencion('${cliente.nombre} solo debe ${plata(debe)}. Revisa el valor.'),
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: e12),
                  AvisoError(error),
                ],
                const SizedBox(height: e20),
                BotonPrincipal(
                  texto: 'Guardar abono',
                  cargando: _guardando,
                  onPressed: () => _guardar(cuenta),
                ),
                if (original != null)
                  Center(
                    child: TextButton(
                      onPressed: () => _borrar(original, cliente),
                      child: const Text('Borrar este abono'),
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
