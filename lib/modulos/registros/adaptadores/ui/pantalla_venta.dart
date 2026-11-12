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
import '../../../../compartido/diseno/selector_fecha.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/cifras.dart';
import '../../../../compartido/formato.dart';
import '../../../clientes/dominio/cliente.dart';
import '../../dominio/registro.dart';
import 'marco_registro.dart';

/// Anotar una venta de pollos por libras, o corregirla.
class PantallaVenta extends ConsumerStatefulWidget {
  const PantallaVenta({super.key, required this.loteId, this.registroId});

  final String loteId;

  /// Null para anotar una nueva.
  final String? registroId;

  @override
  ConsumerState<PantallaVenta> createState() => _PantallaVentaState();
}

class _PantallaVentaState extends ConsumerState<PantallaVenta>
    with FormularioGranja {
  final _pollos = TextEditingController();
  final _libras = TextEditingController();
  final _precio = TextEditingController();
  var _fecha = DateTime.now();
  var _fiado = false;
  String? _clienteId;
  Venta? _original;
  var _guardando = false;

  @override
  String get firma => [
        _clienteId,
        _pollos.text,
        _libras.text,
        _precio.text,
        _fiado,
        fechaCorta(_fecha),
      ].join('|');

  // Al elegir cliente se pone su precio, pero no encima de uno que la
  // persona ya escribió.
  var _precioEscrito = false;

  List<CuentaCliente> get _cuentas =>
      ref.read(cuentasClientesProvider).asData?.value ?? const [];

  @override
  void initState() {
    super.initState();
    if (registroGuardado<Venta>(ref, widget.registroId) case final venta?) {
      _original = venta;
      _clienteId = venta.clienteId;
      _pollos.text = miles(venta.pollos);
      _libras.text = decimal(venta.libras);
      _precio.text = miles(venta.precioLibra);
      _fecha = venta.fecha;
      _fiado = venta.fiado;
      _precioEscrito = true;
    }
    for (final campo in [_pollos, _libras]) {
      campo.addListener(_redibujar);
    }
    _precio.addListener(() {
      _precioEscrito = _precio.text.isNotEmpty;
      _redibujar();
    });
    recordarInicio();
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    for (final campo in [_pollos, _libras, _precio]) {
      campo.dispose();
    }
    super.dispose();
  }

  void _elegirCliente(String? id) {
    setState(() => _clienteId = id);
    final sugerido = _cuentas.where((c) => c.cliente.id == id).firstOrNull?.precioSugerido;
    if (sugerido != null && !_precioEscrito) {
      _precio.text = miles(sugerido);
      _precioEscrito = false;
    }
  }

  Future<void> _nuevoCliente() async {
    final id = await context.push<String>('/clientes/nuevo');
    if (id == null || !mounted) return;
    // Espera a que la lista de clientes ya traiga al nuevo.
    await ref.read(cuentasClientesProvider.future);
    if (mounted) _elegirCliente(id);
  }

  CuentaCliente? _cuenta(String? id) =>
      _cuentas.where((c) => c.cliente.id == id).firstOrNull;

  /// Lo que debe el cliente sin contar esta venta.
  int _debeSinEsta(CuentaCliente cuenta) {
    final original = _original;
    return cuenta.debe -
        (original != null && original.clienteId == cuenta.cliente.id
            ? original.fiadoPorCobrar
            : 0);
  }

  Future<void> _guardar(LoteAbierto abierto) async {
    final cuenta = _cuenta(_clienteId);
    final pollos = leerEntero(_pollos.text);
    final libras = leerDecimal(_libras.text);
    final precio = leerEntero(_precio.text);
    if (cuenta == null) {
      mostrarError('Elige a quién le vendiste.', 'cliente');
      return;
    }
    if (pollos == null) {
      mostrarError('Escribe cuántos pollos se vendieron.', 'pollos');
      return;
    }
    if (libras == null) {
      mostrarError('Escribe cuántas libras pesaron, por ejemplo 50,5.', 'libras');
      return;
    }
    if (precio == null) {
      mostrarError('Escribe el precio de la libra.', 'precio');
      return;
    }
    setState(() {
      _guardando = true;
      limpiarError();
    });
    try {
      // Si la venta pasó a otro cliente, el anterior no puede quedar con
      // abonos de más.
      final original = _original;
      if (original != null && original.clienteId != cuenta.cliente.id) {
        if (_cuenta(original.clienteId) case final anterior?) {
          revisarQueNoQuedeAFavor(
            anterior.cliente,
            anterior.debe - original.fiadoPorCobrar,
          );
        }
      }
      final venta = Venta.nueva(
        id: original?.id ?? nuevoId(),
        lote: abierto.lote,
        cliente: cuenta.cliente,
        fecha: _fecha,
        pollos: pollos,
        libras: libras,
        precioLibra: precio,
        fiado: _fiado,
        vivosSinEsta: abierto.cuentas.vivosSin(original),
        debeSinEsta: _debeSinEsta(cuenta),
        hoy: DateTime.now(),
      );
      await ref.read(repositorioRegistrosProvider).guardar(venta);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on RegistroInvalido catch (e) {
      mostrarError(e.mensaje, e.campo);
    } on ClienteInvalido catch (e) {
      mostrarError(e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Venta venta) async {
    final cuenta = _cuenta(venta.clienteId);
    if (cuenta != null && cuenta.debe - venta.fiadoPorCobrar < 0) {
      mostrarError(
        'No se puede borrar: ${cuenta.cliente.nombre} ya abonó parte de '
        'esta venta. Borra o corrige primero esos abonos.',
      );
      return;
    }
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar la venta de ${venta.pollos} pollos del ${fechaCorta(venta.fecha)}?',
      detalle: 'Esos pollos vuelven a contar como vivos'
          '${venta.fiado ? ' y la deuda del cliente baja ${plata(venta.total)}' : ''}.',
      accion: 'Borrar venta',
    );
    if (!acepto) return;
    await ref.read(repositorioRegistrosProvider).borrar(venta);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final abierto = loteAbierto(ref, widget.loteId);
    if (abierto == null) return const LoteNoDisponible();
    final (:galpon, :lote, :cuentas) = abierto;
    final original = _original;
    final clientes = ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[];
    final cuenta = clientes.where((c) => c.cliente.id == _clienteId).firstOrNull;
    final ultimoPrecioGranja = [
      for (final r in ref.watch(registrosProvider).asData?.value ?? const <Registro>[])
        if (r is Venta && r.id != original?.id) r.precioLibra,
    ].firstOrNull;
    final disponibles = cuentas.vivosSin(original);
    final pollos = leerEntero(_pollos.text) ?? 0;
    final libras = leerDecimal(_libras.text) ?? 0;
    final precio = leerEntero(_precio.text) ?? 0;
    final total = totalVenta(libras, precio);
    final porPollo = pollos > 0 ? libras / pollos : 0.0;
    final textos = Theme.of(context).textTheme;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    final dato = conPeso(textos.bodyMedium!.copyWith(color: ColoresGranja.crema), 700);

    return MarcoRegistro(
      titulo: original == null ? 'Nueva venta' : 'Corregir venta',
      subtitulo: '${galpon.nombre} · quedan ${miles(disponibles)} vivos',
      textoGuardar: 'Guardar venta',
      guardando: _guardando,
      alGuardar: () => _guardar(abierto),
      error: errorGeneral,
      hayCambios: hayCambios,
      alBorrar: original == null ? null : () => _borrar(original),
      campos: [
        const EtiquetaCampo('Cliente'),
        _MenuClientes(
          clientes: clientes,
          elegido: _clienteId,
          alElegir: _elegirCliente,
        ),
        if (errorDe('cliente') case final mensaje?) ...[
          const SizedBox(height: e8),
          AvisoError(mensaje),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _nuevoCliente, child: const Text('Nuevo cliente')),
        ),
        if (cuenta?.ultimoPrecio case final ultimo?) ...[
          Text(
            'La última vez le vendiste a ${plata(ultimo)} la libra.',
            style: textos.bodySmall,
          ),
          const SizedBox(height: e8),
        ],
        const SizedBox(height: e8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: CampoGranja(
                etiqueta: 'Pollos',
                controller: _pollos,
                pista: 'Ingresa los pollos',
                teclado: TextInputType.number,
                formatos: soloCantidad,
                error: errorDe('pollos'),
              ),
            ),
            const SizedBox(width: e12),
            Expanded(
              child: CampoGranja(
                etiqueta: 'Libras en total',
                controller: _libras,
                pista: 'Ingresa las libras',
                teclado: const TextInputType.numberWithOptions(decimal: true),
                formatos: soloDecimal,
                error: errorDe('libras'),
              ),
            ),
          ],
        ),
        const SizedBox(height: e16),
        CampoGranja(
          etiqueta: 'Precio por libra',
          controller: _precio,
          pista: 'Ingresa el precio por libra',
          teclado: TextInputType.number,
          formatos: const [MilesAlEscribir()],
          error: errorDe('precio'),
        ),
        if (avisoCifraRara(
          precio,
          cuenta?.ultimoPrecio ?? ultimoPrecioGranja,
          comparadoCon: cuenta?.ultimoPrecio != null
              ? 'tu última venta a ${cuenta!.cliente.nombre}'
              : 'tu última venta',
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
        const SizedBox(height: e16),
        const EtiquetaCampo('Pago'),
        FichasOpcion<bool>(
          opciones: const [false, true],
          elegida: _fiado,
          etiqueta: (fiado) => fiado ? 'Fiado' : 'Contado',
          alElegir: (fiado) => setState(() => _fiado = fiado),
        ),
        if (_fiado && cuenta != null) ...[
          const SizedBox(height: e8),
          Text(
            '${cuenta.cliente.nombre} quedará debiendo '
            '${plata(_debeSinEsta(cuenta) + total)}. '
            '${_debeSinEsta(cuenta) <= 0 ? 'Hoy está al día.' : 'Hoy debe ${plata(_debeSinEsta(cuenta))}.'}',
            style: textos.bodySmall,
          ),
        ],
      ],
      resumen: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TarjetaTicket(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CifraTicket(
                  etiqueta: 'Total de la venta',
                  cifra: plata(total),
                  detalle: '${decimal(libras)} lb × ${plata(precio)}',
                ),
                const SizedBox(height: e12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${decimal(porPollo)} lb por pollo', style: dato),
                    Text(
                      'Quedarán ${miles(max(0, disponibles - pollos))}',
                      style: dato,
                    ),
                  ],
                ),
                const SizedBox(height: e4),
                Text('en ${galpon.nombre}', style: apoyo, textAlign: TextAlign.end),
              ],
            ),
          ),
          if (original == null && pollos > 0)
            if (avisoRepetido<Venta>(
              ref,
              loteId: lote.id,
              fecha: _fecha,
              excepto: null,
              parecido: (v) => v.pollos == pollos && v.clienteId == _clienteId,
              describir: (v) => 'una venta de ${v.pollos} ${v.pollos == 1 ? 'pollo' : 'pollos'} a este cliente',
            )
                case final aviso?) ...[
              const SizedBox(height: e12),
              AvisoAtencion(aviso),
            ],
          if (pollos > disponibles) ...[
            const SizedBox(height: e12),
            AvisoAtencion('Solo quedan ${miles(disponibles)} vivos en este galpón.'),
          ] else if (pollos > 0 && libras > 0 && (porPollo < 2 || porPollo > 8)) ...[
            const SizedBox(height: e12),
            AvisoAtencion(
              '${decimal(porPollo)} lb por pollo es raro. Revisa las libras y los pollos.',
            ),
          ],
        ],
      ),
    );
  }
}

/// El desplegable para elegir a quién se le vende. Los no recurrentes van al
/// final y se puede escribir para buscar.
class _MenuClientes extends StatelessWidget {
  const _MenuClientes({
    required this.clientes,
    required this.elegido,
    required this.alElegir,
  });

  /// Ya vienen ordenadas: recurrentes primero.
  final List<CuentaCliente> clientes;
  final String? elegido;
  final ValueChanged<String?> alElegir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return DropdownMenu<String>(
      // Cambia de llave al elegir desde afuera (un cliente recién creado),
      // para que el texto del campo se actualice.
      key: ValueKey(elegido),
      initialSelection: elegido,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      hintText: 'Elige o escribe el nombre',
      textStyle: conPeso(textos.bodyLarge!, 700),
      menuHeight: 320,
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(ColoresGranja.papel),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
      onSelected: alElegir,
      dropdownMenuEntries: [
        for (final cuenta in clientes)
          DropdownMenuEntry(
            value: cuenta.cliente.id,
            label: cuenta.cliente.nombre,
            labelWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cuenta.cliente.nombre,
                  style: conPeso(
                    textos.bodyLarge!.copyWith(
                      color: cuenta.cliente.recurrente
                          ? ColoresGranja.tinta
                          : ColoresGranja.tintaSuave,
                    ),
                    700,
                  ),
                ),
                if ([
                  ?cuenta.cliente.detalle,
                  if (!cuenta.cliente.recurrente) 'No recurrente',
                  if (!cuenta.alDia) 'debe ${plata(cuenta.debe)}',
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
