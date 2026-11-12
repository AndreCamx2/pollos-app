import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/fichas.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/formato.dart';
import '../../../lotes/dominio/lote.dart';
import '../../dominio/registro.dart';
import 'marco_registro.dart';

/// Anotar una compra de bultos para el lote, o corregirla.
class PantallaCompraAlimento extends ConsumerStatefulWidget {
  const PantallaCompraAlimento({super.key, required this.loteId, this.registroId});

  final String loteId;

  /// Null para anotar una nueva.
  final String? registroId;

  @override
  ConsumerState<PantallaCompraAlimento> createState() =>
      _PantallaCompraAlimentoState();
}

class _PantallaCompraAlimentoState extends ConsumerState<PantallaCompraAlimento> {
  final _marca = TextEditingController();
  final _bultos = TextEditingController();
  final _kilos = TextEditingController(text: '40');
  final _precio = TextEditingController();
  var _tipo = TipoAlimento.inicio;
  var _fecha = DateTime.now();
  CompraAlimento? _original;
  var _guardando = false;
  String? _error;

  List<CompraAlimento> get _compras =>
      (ref.read(registrosProvider).asData?.value ?? const <Registro>[])
          .whereType<CompraAlimento>()
          .toList();

  @override
  void initState() {
    super.initState();
    if (registroGuardado<CompraAlimento>(ref, widget.registroId) case final compra?) {
      _original = compra;
      _llenar(compra);
      _bultos.text = '${compra.bultos}';
      _fecha = compra.fecha;
    } else {
      final lote = loteAbierto(ref, widget.loteId)?.lote;
      if (lote != null && lote.etapaAlimento(DateTime.now()) != EtapaAlimento.inicio) {
        _tipo = TipoAlimento.engorde;
      }
      // Casi siempre se compra lo mismo que la vez pasada.
      final anterior = _compras.where((c) => c.tipo == _tipo).firstOrNull;
      if (anterior != null) _llenar(anterior);
    }
    for (final campo in [_bultos, _kilos, _precio]) {
      campo.addListener(_redibujar);
    }
  }

  void _llenar(CompraAlimento compra) {
    _tipo = compra.tipo;
    _marca.text = compra.marca;
    _kilos.text = decimal(compra.kilosPorBulto);
    _precio.text = miles(compra.precioPorBulto);
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    for (final campo in [_marca, _bultos, _kilos, _precio]) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar(LoteAbierto abierto) async {
    final bultos = leerEntero(_bultos.text);
    final kilos = leerDecimal(_kilos.text);
    final precio = leerEntero(_precio.text);
    if (bultos == null || kilos == null || precio == null) {
      setState(() => _error = 'Escribe los bultos, los kilos de cada uno y el precio.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final compra = CompraAlimento.nueva(
        id: _original?.id ?? nuevoId(),
        lote: abierto.lote,
        fecha: _fecha,
        tipo: _tipo,
        marca: _marca.text,
        kilosPorBulto: kilos,
        bultos: bultos,
        precioPorBulto: precio,
        hoy: DateTime.now(),
      );
      await ref.read(repositorioRegistrosProvider).guardar(compra);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on RegistroInvalido catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(CompraAlimento compra) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar la compra de ${compra.bultos} bultos del ${fechaCorta(compra.fecha)}?',
      detalle: 'Su valor deja de contar en lo invertido del lote.',
      accion: 'Borrar',
    );
    if (!acepto) return;
    await ref.read(repositorioRegistrosProvider).borrar(compra);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final abierto = loteAbierto(ref, widget.loteId);
    if (abierto == null) return const LoteNoDisponible();
    final (:galpon, :lote, :cuentas) = abierto;
    final original = _original;
    final hoy = DateTime.now();
    final dias = lote.diasDeEdad(hoy);
    final sugerido = lote.etapaAlimento(hoy) == EtapaAlimento.inicio
        ? TipoAlimento.inicio
        : TipoAlimento.engorde;
    final marcas = {for (final compra in _compras) compra.marca}.take(4).toList();
    final textos = Theme.of(context).textTheme;

    final bultos = leerEntero(_bultos.text) ?? 0;
    final kilos = leerDecimal(_kilos.text) ?? 0;
    final precio = leerEntero(_precio.text) ?? 0;
    final total = bultos * precio;
    final invertido = cuentas.invertido - (original?.total ?? 0) + total;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);

    return MarcoRegistro(
      titulo: 'Compra de alimento',
      subtitulo: '${galpon.nombre} · día $dias',
      textoGuardar: 'Guardar compra',
      guardando: _guardando,
      alGuardar: () => _guardar(abierto),
      error: _error,
      alBorrar: original == null ? null : () => _borrar(original),
      campos: [
        const EtiquetaCampo('Tipo de bulto'),
        FichasOpcion<TipoAlimento>(
          opciones: TipoAlimento.values,
          elegida: _tipo,
          etiqueta: (tipo) => tipo == TipoAlimento.inicio
              ? 'Inicio · hasta día 21'
              : 'Engorde · desde día 22',
          alElegir: (tipo) => setState(() => _tipo = tipo),
        ),
        if (_tipo != sugerido) ...[
          const SizedBox(height: e8),
          Text(
            'El lote va en el día $dias: te sugerimos ${sugerido.name}.',
            style: textos.bodySmall,
          ),
        ],
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Marca',
          controller: _marca,
          pista: 'Ej.: Marca A',
          mayusculas: TextCapitalization.words,
        ),
        if (marcas.isNotEmpty) ...[
          const SizedBox(height: e8),
          FichasOpcion<String>(
            opciones: marcas,
            elegida: _marca.text.trim(),
            etiqueta: (marca) => marca,
            alElegir: (marca) => setState(() => _marca.text = marca),
          ),
        ],
        const SizedBox(height: e16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CampoGranja(
                etiqueta: 'Bultos',
                controller: _bultos,
                pista: 'Ej.: 10',
                teclado: TextInputType.number,
                formatos: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: e12),
            Expanded(
              child: CampoGranja(
                etiqueta: 'Kilos por bulto',
                controller: _kilos,
                pista: 'Ej.: 40',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
              ),
            ),
          ],
        ),
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Precio por bulto',
          controller: _precio,
          pista: 'Ej.: 104.000',
          teclado: TextInputType.number,
          formatos: const [MilesAlEscribir()],
        ),
        const SizedBox(height: e16),
        const EtiquetaCampo('Fecha'),
        SelectorFecha(
          fecha: _fecha,
          desde: lote.fechaLlegada,
          alCambiar: (fecha) => setState(() => _fecha = fecha),
        ),
      ],
      resumen: TarjetaTicket(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CifraTicket(
              etiqueta: 'Total de la compra',
              cifra: plata(total),
              detalle: '$bultos ${bultos == 1 ? 'bulto' : 'bultos'} × ${plata(precio)}'
                  ' · ${decimal(bultos * kilos)} kg',
            ),
            const SizedBox(height: e12),
            Text('Invertido en el lote con esta compra: ${plata(invertido)}', style: apoyo),
          ],
        ),
      ),
    );
  }
}
