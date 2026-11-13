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
import '../../../../compartido/diseno/formulario.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../dominio/marca.dart';
import '../../dominio/registro.dart';

/// Agregar una marca de alimento o corregir una que ya existe. Al guardar
/// devuelve el id de la marca, para elegirla de una vez en la compra.
class PantallaFormularioMarca extends ConsumerStatefulWidget {
  const PantallaFormularioMarca({super.key, this.marcaId});

  /// Null para agregar una nueva.
  final String? marcaId;

  @override
  ConsumerState<PantallaFormularioMarca> createState() => _PantallaFormularioMarcaState();
}

class _PantallaFormularioMarcaState extends ConsumerState<PantallaFormularioMarca>
    with FormularioGranja {
  final _nombre = TextEditingController();
  final _kilos = TextEditingController();
  var _enUso = true;
  MarcaConCompras? _original;
  var _guardando = false;

  @override
  String get firma => [_nombre.text, _kilos.text, _enUso].join('|');

  List<MarcaConCompras> get _marcas => ref.read(marcasProvider).asData?.value ?? const [];

  @override
  void initState() {
    super.initState();
    if (_marcas.where((m) => m.marca.id == widget.marcaId).firstOrNull case final original?) {
      final kilos = original.marca.kilosPorBulto;
      _original = original;
      _nombre.text = original.marca.nombre;
      _kilos.text = kilos == null ? '' : decimal(kilos);
      _enUso = original.marca.enUso;
    }
    recordarInicio();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _kilos.dispose();
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
      final marca = Marca.nueva(
        id: _original?.marca.id ?? nuevoId(),
        granjaId: granja.id,
        nombre: _nombre.text,
        kilosPorBulto: leerDecimal(_kilos.text),
        enUso: _enUso,
        otras: [for (final m in _marcas) m.marca],
      );
      await ref.read(repositorioRegistrosProvider).guardarMarca(marca);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop(marca.id);
    } on RegistroInvalido catch (e) {
      mostrarError(e.mensaje, e.campo);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Marca marca) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar la marca ${marca.nombre}?',
      detalle: 'Desaparece de la lista para todos en la granja.',
      accion: 'Borrar marca',
    );
    if (!acepto) return;
    await ref.read(repositorioRegistrosProvider).borrarMarca(marca);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final original = _original;
    return ProtegerCambios(
      hayCambios: hayCambios,
      child: Scaffold(
        body: ListView(
          padding: const EdgeInsets.only(bottom: e24),
          children: [
            EncabezadoMaiz(
              child: TitularPantalla(
                titulo: original == null ? 'Nueva marca' : 'Corregir marca',
                subtitulo: original == null
                    ? 'De alimento para los pollos'
                    : 'El cambio se ve en sus ${original.compras} compras',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CampoGranja(
                    etiqueta: 'Nombre de la marca',
                    controller: _nombre,
                    pista: 'Ej.: Solla',
                    mayusculas: TextCapitalization.words,
                    error: errorDe('nombre'),
                  ),
                  const SizedBox(height: e16),
                  CampoGranja(
                    etiqueta: 'Kilos que trae el bulto',
                    controller: _kilos,
                    opcional: true,
                    pista: 'Ej.: 40',
                    ayuda: 'Se ponen solos al elegir la marca en una compra.',
                    teclado: const TextInputType.numberWithOptions(decimal: true),
                    formatos: soloDecimal,
                    error: errorDe('kilos'),
                  ),
                  if (original != null) ...[
                    const SizedBox(height: e16),
                    MergeSemantics(
                      child: Pulsable(
                        onTap: () => setState(() => _enUso = !_enUso),
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
                                    Text('Ya no la uso', style: conPeso(textos.bodyMedium!, 700)),
                                    Text(
                                      'Pasa al final de la lista. Sus compras no cambian.',
                                      style: textos.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: !_enUso,
                                onChanged: (yaNo) => setState(() => _enUso = !yaNo),
                                activeTrackColor: ColoresGranja.granero,
                                activeThumbColor: ColoresGranja.papel,
                                inactiveTrackColor: ColoresGranja.surco,
                                inactiveThumbColor: ColoresGranja.tintaSuave,
                                trackOutlineColor:
                                    const WidgetStatePropertyAll(Colors.transparent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (errorGeneral case final mensaje?) ...[
                    const SizedBox(height: e12),
                    AvisoError(mensaje),
                  ],
                  const SizedBox(height: e20),
                  BotonPrincipal(texto: 'Guardar marca', cargando: _guardando, onPressed: _guardar),
                  if (original != null && original.compras == 0)
                    Center(
                      child: TextButton(
                        onPressed: () => _borrar(original.marca),
                        child: const Text('Borrar esta marca'),
                      ),
                    )
                  else if (original != null) ...[
                    const SizedBox(height: e12),
                    Text(
                      'Tiene compras anotadas, así que no se puede borrar. Si ya no la '
                      'compras, marca "Ya no la uso".',
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
