import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/formulario.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../dominio/cliente.dart';

/// Agregar un cliente o corregir uno que ya existe. Al guardar devuelve el id
/// del cliente, para elegirlo de una vez en la venta que lo pidió.
class PantallaFormularioCliente extends ConsumerStatefulWidget {
  const PantallaFormularioCliente({super.key, this.clienteId});

  /// Null para agregar uno nuevo.
  final String? clienteId;

  @override
  ConsumerState<PantallaFormularioCliente> createState() =>
      _PantallaFormularioClienteState();
}

class _PantallaFormularioClienteState extends ConsumerState<PantallaFormularioCliente>
    with FormularioGranja {
  final _nombre = TextEditingController();
  final _detalle = TextEditingController();
  final _telefono = TextEditingController();
  final _precio = TextEditingController();
  var _recurrente = true;
  CuentaCliente? _original;
  var _guardando = false;

  @override
  String get firma => [_nombre.text, _detalle.text, _telefono.text, _precio.text, _recurrente].join('|');

  List<CuentaCliente> get _cuentas =>
      ref.read(cuentasClientesProvider).asData?.value ?? const [];

  @override
  void initState() {
    super.initState();
    if (_cuentas.where((c) => c.cliente.id == widget.clienteId).firstOrNull
        case final cuenta?) {
      final cliente = cuenta.cliente;
      final precio = cliente.precioLibraSugerido;
      _original = cuenta;
      _nombre.text = cliente.nombre;
      _detalle.text = cliente.detalle ?? '';
      _telefono.text = cliente.telefono ?? '';
      _precio.text = precio == null ? '' : miles(precio);
      _recurrente = cliente.recurrente;
    }
    // El aviso de nombre repetido aparece mientras la persona escribe.
    _nombre.addListener(_redibujar);
    recordarInicio();
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    for (final campo in [_nombre, _detalle, _telefono, _precio]) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final granja = ref.read(granjaActualProvider);
    if (granja == null) return;
    setState(() {
      _guardando = true;
      limpiarError();
    });
    try {
      final cliente = Cliente.nuevo(
        id: _original?.cliente.id ?? nuevoId(),
        granjaId: granja.id,
        nombre: _nombre.text,
        detalle: _detalle.text,
        telefono: _telefono.text,
        precioLibraSugerido: leerEntero(_precio.text),
        recurrente: _recurrente,
      );
      await ref.read(repositorioClientesProvider).guardarCliente(cliente);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop(cliente.id);
    } on ClienteInvalido catch (e) {
      mostrarError(e.mensaje, e.campo);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Cliente cliente) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar a ${cliente.nombre}?',
      detalle: 'Desaparece de la lista para todos en la granja. No se puede deshacer.',
      accion: 'Borrar cliente',
    );
    if (!acepto) return;
    await ref.read(repositorioClientesProvider).borrarCliente(cliente);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final original = _original;
    final nombre = _nombre.text.trim().toLowerCase();
    final repetido = nombre.isNotEmpty &&
        _cuentas.any(
          (c) => c.cliente.id != original?.cliente.id && c.cliente.nombre.toLowerCase() == nombre,
        );

    return ProtegerCambios(
      hayCambios: hayCambios,
      child: Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(
              titulo: original == null ? 'Nuevo cliente' : 'Corregir cliente',
              subtitulo: 'Solo el nombre es obligatorio',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoGranja(
                  etiqueta: 'Nombre',
                  controller: _nombre,
                  error: errorDe('nombre'),
                  pista: 'Ej.: Luz Marina Ospina',
                  mayusculas: TextCapitalization.words,
                ),
                if (repetido) ...[
                  const SizedBox(height: e8),
                  const AvisoAtencion(
                    'Ya tienes un cliente que se llama así. Agrega el negocio para distinguirlos.',
                  ),
                ],
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Negocio o cómo lo reconoces',
                  controller: _detalle,
                  opcional: true,
                  pista: 'Ej.: Asadero del parque',
                  mayusculas: TextCapitalization.sentences,
                ),
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Celular',
                  controller: _telefono,
                  error: errorDe('telefono'),
                  opcional: true,
                  pista: '300 000 0000',
                  teclado: TextInputType.phone,
                  formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
                ),
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Precio por libra',
                  controller: _precio,
                  error: errorDe('precio'),
                  opcional: true,
                  pista: 'Ej.: 5.600',
                  ayuda: 'Se sugiere en su primera venta; después se usa el de la última.',
                  teclado: TextInputType.number,
                  formatos: const [MilesAlEscribir()],
                ),
                const SizedBox(height: e16),
                _InterruptorRecurrente(
                  recurrente: _recurrente,
                  alCambiar: (valor) => setState(() => _recurrente = valor),
                ),
                if (errorGeneral case final error?) ...[
                  const SizedBox(height: e12),
                  AvisoError(error),
                ],
                const SizedBox(height: e20),
                BotonPrincipal(
                  texto: 'Guardar cliente',
                  cargando: _guardando,
                  onPressed: _guardar,
                ),
                if (original != null && original.sePuedeBorrar)
                  Center(
                    child: TextButton(
                      onPressed: () => _borrar(original.cliente),
                      child: const Text('Borrar este cliente'),
                    ),
                  )
                else if (original != null) ...[
                  const SizedBox(height: e12),
                  Text(
                    'Tiene ventas o abonos, así que no se puede borrar. Si ya no te '
                    'compra, márcalo como no recurrente y pasa al final de la lista.',
                    style: textos.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _InterruptorRecurrente extends StatelessWidget {
  const _InterruptorRecurrente({required this.recurrente, required this.alCambiar});

  final bool recurrente;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Pulsable(
        onTap: () => alCambiar(!recurrente),
        child: Container(
          padding: const EdgeInsets.fromLTRB(e16, e12, e8, e12),
          decoration: BoxDecoration(
            color: ColoresGranja.papel,
            borderRadius: BorderRadius.circular(radioCampo),
            border: Border.all(color: ColoresGranja.borde),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente no recurrente', style: conPeso(textos.bodyMedium!, 700)),
                    Text(
                      'Compró una vez y no se espera que vuelva. Va al final de las listas.',
                      style: textos.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: !recurrente,
                onChanged: (noRecurrente) => alCambiar(!noRecurrente),
                activeTrackColor: ColoresGranja.granero,
                activeThumbColor: ColoresGranja.papel,
                inactiveTrackColor: ColoresGranja.surco,
                inactiveThumbColor: ColoresGranja.tintaSuave,
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
