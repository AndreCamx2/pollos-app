import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/fichas.dart';
import '../../../../compartido/diseno/formulario.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/formato.dart';
import '../../dominio/registro.dart';
import 'marco_registro.dart';

/// Anotar los pollos que se murieron, o corregir lo anotado.
class PantallaMuertos extends ConsumerStatefulWidget {
  const PantallaMuertos({super.key, required this.loteId, this.registroId});

  final String loteId;

  /// Null para anotar uno nuevo.
  final String? registroId;

  @override
  ConsumerState<PantallaMuertos> createState() => _PantallaMuertosState();
}

class _PantallaMuertosState extends ConsumerState<PantallaMuertos>
    with FormularioGranja {
  final _cantidad = TextEditingController(text: '1');
  final _nota = TextEditingController();
  CausaMuerte? _causa;
  var _fecha = DateTime.now();
  Mortalidad? _original;
  var _guardando = false;

  @override
  String get firma => [_cantidad.text, _nota.text, _causa, fechaCorta(_fecha)].join('|');

  @override
  void initState() {
    super.initState();
    if (registroGuardado<Mortalidad>(ref, widget.registroId) case final registro?) {
      _original = registro;
      _cantidad.text = '${registro.cantidad}';
      _nota.text = registro.nota ?? '';
      _causa = registro.causa;
      _fecha = registro.fecha;
    }
    // Lo que quedará vivo se calcula mientras la persona escribe.
    _cantidad.addListener(_redibujar);
    recordarInicio();
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    _cantidad.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _sumar(int cuanto) {
    final nueva = max(1, (leerEntero(_cantidad.text) ?? 0) + cuanto);
    _cantidad.text = '$nueva';
  }

  Future<void> _guardar(LoteAbierto abierto) async {
    setState(() {
      _guardando = true;
      limpiarError();
    });
    try {
      final registro = Mortalidad.nueva(
        id: _original?.id ?? nuevoId(),
        lote: abierto.lote,
        fecha: _fecha,
        cantidad: leerEntero(_cantidad.text) ?? 0,
        causa: _causa,
        nota: _nota.text,
        vivosSinEste: abierto.cuentas.vivosSin(_original),
        hoy: DateTime.now(),
      );
      await ref.read(repositorioRegistrosProvider).guardar(registro);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on RegistroInvalido catch (e) {
      mostrarError(e.mensaje, e.campo);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Mortalidad registro) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar los ${registro.cantidad} muertos del ${fechaCorta(registro.fecha)}?',
      detalle: 'Esos pollos vuelven a contar como vivos.',
      accion: 'Borrar',
    );
    if (!acepto) return;
    await ref.read(repositorioRegistrosProvider).borrar(registro);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final abierto = loteAbierto(ref, widget.loteId);
    if (abierto == null) return const LoteNoDisponible();
    final (:galpon, :lote, :cuentas) = abierto;
    final original = _original;
    final disponibles = cuentas.vivosSin(original);
    final cantidad = leerEntero(_cantidad.text) ?? 0;
    final muertosAntes = lote.cantidadInicial - disponibles;
    final textos = Theme.of(context).textTheme;

    String porcentaje(int muertos) => '${decimal(muertos * 100 / lote.cantidadInicial)} %';

    return MarcoRegistro(
      titulo: 'Pollos muertos',
      subtitulo: '${galpon.nombre} · quedan ${miles(disponibles)} vivos',
      textoGuardar: 'Guardar',
      guardando: _guardando,
      alGuardar: () => _guardar(abierto),
      error: errorGeneral,
      hayCambios: hayCambios,
      alBorrar: original == null ? null : () => _borrar(original),
      campos: [
        const EtiquetaCampo('Cuántos se murieron'),
        Row(
          children: [
            _BotonContador(
              icono: Icons.remove_rounded,
              ayuda: 'Uno menos',
              alTocar: () => _sumar(-1),
            ),
            const SizedBox(width: e12),
            Expanded(
              child: TextField(
                controller: _cantidad,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: soloCantidad,
                style: textos.headlineSmall,
                decoration: InputDecoration(errorText: errorDe('cantidad'), errorMaxLines: 3),
              ),
            ),
            const SizedBox(width: e12),
            _BotonContador(
              icono: Icons.add_rounded,
              ayuda: 'Uno más',
              alTocar: () => _sumar(1),
            ),
          ],
        ),
        const SizedBox(height: e16),
        const EtiquetaCampo('Causa', opcional: true),
        FichasOpcion<CausaMuerte>(
          opciones: CausaMuerte.values,
          elegida: _causa,
          etiqueta: (causa) => causa.etiqueta,
          alElegir: (causa) => setState(() => _causa = causa == _causa ? null : causa),
        ),
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Nota',
          controller: _nota,
          opcional: true,
          pista: 'Ej.: amanecieron junto al bebedero del fondo',
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
        if (errorDe('fecha') case final mensaje?) ...[
          const SizedBox(height: e8),
          AvisoError(mensaje),
        ],
      ],
      resumen: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TarjetaTicket(
            child: CifraTicket(
              etiqueta: 'Quedarán vivos',
              cifra: miles(max(0, disponibles - cantidad)),
              detalle: 'Mortalidad del lote: ${porcentaje(muertosAntes)} → '
                  '${porcentaje(muertosAntes + min(cantidad, disponibles))}',
            ),
          ),
          if (original == null && cantidad > 0)
            if (avisoRepetido<Mortalidad>(
              ref,
              loteId: lote.id,
              fecha: _fecha,
              excepto: null,
              parecido: (m) => m.cantidad == cantidad,
              describir: (m) => '${m.cantidad} ${m.cantidad == 1 ? 'muerto' : 'muertos'}',
            )
                case final aviso?) ...[
              const SizedBox(height: e12),
              AvisoAtencion(aviso),
            ],
          if (cantidad > disponibles) ...[
            const SizedBox(height: e12),
            AvisoAtencion('Solo quedan ${miles(disponibles)} vivos en este galpón.'),
          ] else if (cantidad >= 10) ...[
            const SizedBox(height: e12),
            const AvisoAtencion(
              'Son muchos en un día. Si siguen muriendo, conviene llamar al veterinario.',
            ),
          ],
        ],
      ),
    );
  }
}

class _BotonContador extends StatelessWidget {
  const _BotonContador({
    required this.icono,
    required this.ayuda,
    required this.alTocar,
  });

  final IconData icono;
  final String ayuda;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: ayuda,
      child: Pulsable(
        onTap: alTocar,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ColoresGranja.papel,
            borderRadius: BorderRadius.circular(e16),
            border: Border.all(color: ColoresGranja.borde),
          ),
          child: Icon(icono, color: ColoresGranja.tinta),
        ),
      ),
    );
  }
}
