import 'package:flutter/material.dart';
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
import '../../dominio/registro.dart';
import 'marco_registro.dart';

const _lasDeSiempre = ['Vitaminas', 'Electrolitos', 'Antibiótico', 'Vacuna'];

/// Anotar una medicina comprada para el lote, o corregirla.
class PantallaMedicina extends ConsumerStatefulWidget {
  const PantallaMedicina({super.key, required this.loteId, this.registroId});

  final String loteId;

  /// Null para anotar una nueva.
  final String? registroId;

  @override
  ConsumerState<PantallaMedicina> createState() => _PantallaMedicinaState();
}

class _PantallaMedicinaState extends ConsumerState<PantallaMedicina> {
  final _nombre = TextEditingController();
  final _costo = TextEditingController();
  final _nota = TextEditingController();
  var _fecha = DateTime.now();
  Medicamento? _original;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (registroGuardado<Medicamento>(ref, widget.registroId) case final medicina?) {
      _original = medicina;
      _nombre.text = medicina.nombre;
      _costo.text = miles(medicina.costo);
      _nota.text = medicina.nota ?? '';
      _fecha = medicina.fecha;
    }
    _nombre.addListener(_redibujar);
    _costo.addListener(_redibujar);
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    _nombre.dispose();
    _costo.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar(LoteAbierto abierto) async {
    final costo = leerEntero(_costo.text);
    if (costo == null) {
      setState(() => _error = 'Escribe cuánto costó.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final medicina = Medicamento.nueva(
        id: _original?.id ?? nuevoId(),
        lote: abierto.lote,
        fecha: _fecha,
        nombre: _nombre.text,
        costo: costo,
        nota: _nota.text,
        hoy: DateTime.now(),
      );
      await ref.read(repositorioRegistrosProvider).guardar(medicina);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on RegistroInvalido catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Medicamento medicina) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar ${medicina.nombre} del ${fechaCorta(medicina.fecha)}?',
      detalle: 'Su costo deja de contar en lo invertido del lote.',
      accion: 'Borrar',
    );
    if (!acepto) return;
    await ref.read(repositorioRegistrosProvider).borrar(medicina);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final abierto = loteAbierto(ref, widget.loteId);
    if (abierto == null) return const LoteNoDisponible();
    final (:galpon, :lote, :cuentas) = abierto;
    final original = _original;
    final usadas = [
      for (final registro in ref.watch(registrosProvider).asData?.value ?? const <Registro>[])
        if (registro is Medicamento) registro.nombre,
    ];
    final sugerencias = {..._lasDeSiempre, ...usadas}.take(6).toList();
    final costo = leerEntero(_costo.text) ?? 0;
    final antes = cuentas.medicina - (original?.costo ?? 0);
    final invertido = cuentas.invertido - (original?.costo ?? 0) + costo;
    final apoyo = Theme.of(context)
        .textTheme
        .bodySmall!
        .copyWith(color: ColoresGranja.textoSobreTinta);

    return MarcoRegistro(
      titulo: 'Medicina',
      subtitulo: '${galpon.nombre} · día ${lote.diasDeEdad(DateTime.now())}',
      textoGuardar: 'Guardar medicina',
      guardando: _guardando,
      alGuardar: () => _guardar(abierto),
      error: _error,
      alBorrar: original == null ? null : () => _borrar(original),
      campos: [
        CampoGranja(
          etiqueta: 'Qué compraste',
          controller: _nombre,
          pista: 'Nombre del producto',
          mayusculas: TextCapitalization.sentences,
        ),
        const SizedBox(height: e8),
        FichasOpcion<String>(
          opciones: sugerencias,
          elegida: _nombre.text.trim(),
          etiqueta: (nombre) => nombre,
          alElegir: (nombre) => _nombre.text = nombre,
        ),
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Cuánto costó',
          controller: _costo,
          pista: 'Ej.: 45.000',
          teclado: TextInputType.number,
          formatos: const [MilesAlEscribir()],
        ),
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Para qué o cómo se da',
          controller: _nota,
          opcional: true,
          pista: 'Ej.: 1 sobre por galón de agua, 5 días',
          mayusculas: TextCapitalization.sentences,
          lineas: 3,
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
              etiqueta: 'Medicina del lote',
              cifra: plata(antes + costo),
              detalle: 'Antes ${plata(antes)} · esta compra ${plata(costo)}',
            ),
            const SizedBox(height: e12),
            Text('Invertido hasta hoy: ${plata(invertido)}', style: apoyo),
          ],
        ),
      ),
    );
  }
}
