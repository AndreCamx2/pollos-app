import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/cifras.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/fichas.dart';
import '../../../../compartido/diseno/formulario.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../lotes/dominio/lote.dart';
import '../../dominio/marca.dart';
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

class _PantallaCompraAlimentoState extends ConsumerState<PantallaCompraAlimento>
    with FormularioGranja {
  final _bultos = TextEditingController();
  final _kilos = TextEditingController();
  final _precio = TextEditingController();
  var _tipo = TipoAlimento.inicio;
  var _fecha = DateTime.now();
  String? _marcaId;
  CompraAlimento? _original;
  var _guardando = false;

  @override
  String get firma => [
        _tipo,
        _marcaId,
        _bultos.text,
        _kilos.text,
        _precio.text,
        fechaCorta(_fecha),
      ].join('|');

  List<MarcaConCompras> get _marcas =>
      ref.read(marcasProvider).asData?.value ?? const [];

  List<CompraAlimento> get _compras =>
      (ref.read(registrosProvider).asData?.value ?? const <Registro>[])
          .whereType<CompraAlimento>()
          .toList();

  @override
  void initState() {
    super.initState();
    if (registroGuardado<CompraAlimento>(ref, widget.registroId) case final compra?) {
      _original = compra;
      _tipo = compra.tipo;
      _marcaId = compra.marcaId ?? _marcaConNombre(compra.marca)?.id;
      _bultos.text = '${compra.bultos}';
      _kilos.text = decimal(compra.kilosPorBulto);
      _precio.text = miles(compra.precioPorBulto);
      _fecha = compra.fecha;
    } else {
      final lote = loteAbierto(ref, widget.loteId)?.lote;
      if (lote != null && lote.etapaAlimento(DateTime.now()) != EtapaAlimento.inicio) {
        _tipo = TipoAlimento.engorde;
      }
      // Casi siempre se compra lo mismo que la vez pasada.
      final anterior = _compras.where((c) => c.tipo == _tipo).firstOrNull;
      if (anterior != null) {
        _marcaId = anterior.marcaId ?? _marcaConNombre(anterior.marca)?.id;
        _kilos.text = decimal(anterior.kilosPorBulto);
        _precio.text = miles(anterior.precioPorBulto);
      }
    }
    for (final campo in [_bultos, _kilos, _precio]) {
      campo.addListener(_redibujar);
    }
    recordarInicio();
  }

  Marca? _marcaConNombre(String nombre) => _marcas
      .where((m) => m.marca.nombre.toLowerCase() == nombre.trim().toLowerCase())
      .firstOrNull
      ?.marca;

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    for (final campo in [_bultos, _kilos, _precio]) {
      campo.dispose();
    }
    super.dispose();
  }

  /// Al elegir una marca se ponen sus kilos y el precio de su última compra.
  void _elegirMarca(String? id) {
    setState(() => _marcaId = id);
    final elegida = _marcas.where((m) => m.marca.id == id).firstOrNull;
    if (elegida == null) return;
    if (elegida.marca.kilosPorBulto case final kilos?) _kilos.text = decimal(kilos);
    if (elegida.ultimoPrecio case final precio?) _precio.text = miles(precio);
  }

  Future<void> _abrirMarca([String? id]) async {
    final elegida = await context.push<String>(id == null ? '/marcas/nueva' : '/marcas/$id/editar');
    if (elegida == null || !mounted) return;
    // Espera a que la lista ya traiga la marca nueva o corregida.
    await ref.read(marcasProvider.future);
    if (mounted) _elegirMarca(elegida);
  }

  Future<void> _guardar(LoteAbierto abierto) async {
    final bultos = leerEntero(_bultos.text);
    final kilos = leerDecimal(_kilos.text);
    final precio = leerEntero(_precio.text);
    if (bultos == null) {
      mostrarError('Escribe cuántos bultos compraste.', 'bultos');
      return;
    }
    if (kilos == null) {
      mostrarError('Escribe cuántos kilos trae cada bulto.', 'kilos');
      return;
    }
    if (precio == null) {
      mostrarError('Escribe el precio de cada bulto.', 'precio');
      return;
    }
    setState(() {
      _guardando = true;
      limpiarError();
    });
    try {
      final compra = CompraAlimento.nueva(
        id: _original?.id ?? nuevoId(),
        lote: abierto.lote,
        fecha: _fecha,
        tipo: _tipo,
        marca: _marcas.where((m) => m.marca.id == _marcaId).firstOrNull?.marca,
        kilosPorBulto: kilos,
        bultos: bultos,
        precioPorBulto: precio,
        hoy: DateTime.now(),
      );
      await ref.read(repositorioRegistrosProvider).guardar(compra);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on RegistroInvalido catch (e) {
      mostrarError(e.mensaje, e.campo);
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
    final marcas = ref.watch(marcasProvider).asData?.value ?? const <MarcaConCompras>[];
    final elegida = marcas.where((m) => m.marca.id == _marcaId).firstOrNull;
    final granja = ref.watch(granjaActualProvider);
    final puedeCorregirMarca = elegida != null &&
        granja != null &&
        elegida.marca.puedeCambiarla(
          administra: granja.rol.administra,
          usuarioId: ref.watch(usuarioIdProvider),
        );
    final textos = Theme.of(context).textTheme;

    final bultos = leerEntero(_bultos.text) ?? 0;
    final kilos = leerDecimal(_kilos.text) ?? 0;
    final precio = leerEntero(_precio.text) ?? 0;
    final total = bultos * precio;
    final invertido = cuentas.invertido - (original?.total ?? 0) + total;
    final precioAnterior = elegida?.ultimoPrecio ??
        _compras.where((c) => c.tipo == _tipo && c.id != original?.id).firstOrNull?.precioPorBulto;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);

    return MarcoRegistro(
      titulo: 'Compra de alimento',
      subtitulo: '${galpon.nombre} · día $dias',
      textoGuardar: 'Guardar compra',
      guardando: _guardando,
      alGuardar: () => _guardar(abierto),
      hayCambios: hayCambios,
      error: errorGeneral,
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
        const EtiquetaCampo('Marca'),
        MenuMarcas(marcas: marcas, elegida: _marcaId, alElegir: _elegirMarca),
        if (errorDe('marca') case final mensaje?) ...[
          const SizedBox(height: e8),
          AvisoError(mensaje),
        ],
        Row(
          children: [
            TextButton(onPressed: _abrirMarca, child: const Text('Nueva marca')),
            if (puedeCorregirMarca)
              TextButton(
                onPressed: () => _abrirMarca(elegida.marca.id),
                child: const Text('Corregir marca'),
              ),
          ],
        ),
        const SizedBox(height: e8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CampoGranja(
                etiqueta: 'Bultos',
                controller: _bultos,
                pista: 'Ej.: 10',
                teclado: TextInputType.number,
                formatos: soloCantidad,
                error: errorDe('bultos'),
              ),
            ),
            const SizedBox(width: e12),
            Expanded(
              child: CampoGranja(
                etiqueta: 'Kilos por bulto',
                controller: _kilos,
                pista: 'Ej.: 40',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formatos: soloDecimal,
                error: errorDe('kilos'),
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
          error: errorDe('precio'),
        ),
        if (avisoCifraRara(
          precio,
          precioAnterior,
          comparadoCon: elegida?.ultimoPrecio != null
              ? 'la última compra de ${elegida!.marca.nombre}'
              : 'tu última compra de ${_tipo.name}',
        )
            case final aviso?) ...[
          const SizedBox(height: e8),
          AvisoAtencion(aviso),
        ],
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
        if (original == null && bultos > 0)
          if (avisoRepetido<CompraAlimento>(
            ref,
            loteId: lote.id,
            fecha: _fecha,
            excepto: null,
            parecido: (c) => c.bultos == bultos && c.tipo == _tipo,
            describir: (c) =>
                '${c.bultos} ${c.bultos == 1 ? 'bulto' : 'bultos'} de ${c.tipo.name}',
          )
              case final aviso?) ...[
            const SizedBox(height: e12),
            AvisoAtencion(aviso),
          ],
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

/// El desplegable de marcas, con las que ya no se usan al final. Se puede
/// escribir para buscar.
class MenuMarcas extends StatelessWidget {
  const MenuMarcas({
    super.key,
    required this.marcas,
    required this.elegida,
    required this.alElegir,
  });

  /// Ya vienen ordenadas: las que se usan primero.
  final List<MarcaConCompras> marcas;
  final String? elegida;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return DropdownMenu<String>(
      // Cambia de llave al elegir desde afuera (una marca recién creada),
      // para que el texto del campo se actualice.
      key: ValueKey(elegida),
      initialSelection: elegida,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      hintText: marcas.isEmpty ? 'Todavía no hay marcas: crea una' : 'Elige o escribe la marca',
      textStyle: conPeso(textos.bodyLarge!, 700),
      menuHeight: 320,
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(ColoresGranja.papel),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      onSelected: alElegir,
      dropdownMenuEntries: [
        for (final (:marca, compras: _, ultimoPrecio: _) in marcas)
          DropdownMenuEntry(
            value: marca.id,
            label: marca.nombre,
            labelWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  marca.nombre,
                  style: conPeso(
                    textos.bodyLarge!.copyWith(
                      color: marca.enUso ? ColoresGranja.tinta : ColoresGranja.tintaSuave,
                    ),
                    700,
                  ),
                ),
                if ([
                  if (marca.kilosPorBulto case final kilos?) '${decimal(kilos)} kg el bulto',
                  if (!marca.enUso) 'Ya no la usas',
                ]
                    case final datos when datos.isNotEmpty)
                  Text(datos.join(' · '), style: textos.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
