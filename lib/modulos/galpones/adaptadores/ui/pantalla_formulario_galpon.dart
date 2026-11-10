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
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/formato.dart';
import '../../../lotes/dominio/lote.dart';
import '../../dominio/galpon.dart';

/// Agregar un galpón o corregir uno que ya existe.
class PantallaFormularioGalpon extends ConsumerStatefulWidget {
  const PantallaFormularioGalpon({super.key, this.galponId});

  /// Null para agregar uno nuevo.
  final String? galponId;

  @override
  ConsumerState<PantallaFormularioGalpon> createState() =>
      _PantallaFormularioGalponState();
}

class _PantallaFormularioGalponState
    extends ConsumerState<PantallaFormularioGalpon> {
  final _nombre = TextEditingController();
  final _capacidad = TextEditingController();
  final _largo = TextEditingController();
  final _ancho = TextEditingController();
  final _donde = TextEditingController();
  var _guardando = false;
  String? _error;

  List<TextEditingController> get _campos =>
      [_nombre, _capacidad, _largo, _ancho, _donde];

  List<Galpon> get _galpones => [
        for (final g in ref.read(galponesProvider).asData?.value ?? const <GalponConLote>[])
          g.galpon,
      ];

  Galpon? get _original =>
      _galpones.where((g) => g.id == widget.galponId).firstOrNull;

  @override
  void initState() {
    super.initState();
    if (_original case final galpon?) {
      final caben = galpon.capacidad;
      final largo = galpon.largoM;
      final ancho = galpon.anchoM;
      _nombre.text = galpon.nombre;
      _capacidad.text = caben == null ? '' : miles(caben);
      _largo.text = largo == null ? '' : decimal(largo);
      _ancho.text = ancho == null ? '' : decimal(ancho);
      _donde.text = galpon.ubicacion ?? '';
    }
    // El resumen de abajo se va armando mientras la persona escribe.
    for (final campo in _campos) {
      campo.addListener(_redibujar);
    }
  }

  void _redibujar() => setState(() {});

  @override
  void dispose() {
    for (final campo in _campos) {
      campo.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final granja = ref.read(granjaActualProvider);
    if (granja == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final galpon = Galpon.nuevo(
        id: widget.galponId ?? nuevoId(),
        granjaId: granja.id,
        nombre: _nombre.text,
        capacidad: leerEntero(_capacidad.text),
        largoM: leerDecimal(_largo.text),
        anchoM: leerDecimal(_ancho.text),
        ubicacion: _donde.text,
        otros: _galpones,
      );
      await ref.read(repositorioGalponesProvider).guardar(galpon);
      await ref.read(sincronizacionProvider.notifier).huboCambios();
      if (mounted) context.pop();
    } on GalponInvalido catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar(Galpon galpon) async {
    final acepto = await confirmar(
      context,
      titulo: '¿Borrar ${galpon.nombre}?',
      detalle: 'Desaparece de la granja para todos. No se puede deshacer.',
      accion: 'Borrar galpón',
    );
    if (!acepto) return;
    await ref.read(repositorioGalponesProvider).borrar(galpon);
    await ref.read(sincronizacionProvider.notifier).huboCambios();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final original = _original;
    final tuvoLotes = (ref.watch(lotesProvider).asData?.value ?? const <Lote>[])
        .any((lote) => lote.galponId == widget.galponId);
    const metros = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(
              titulo: original == null ? 'Agregar galpón' : 'Corregir galpón',
              subtitulo: 'Solo el nombre es obligatorio',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CampoGranja(
                  etiqueta: 'Nombre del galpón',
                  controller: _nombre,
                  pista: 'Ej.: Galpón 1',
                  mayusculas: TextCapitalization.sentences,
                ),
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Cuántos pollos caben',
                  controller: _capacidad,
                  opcional: true,
                  pista: 'Ej.: 600',
                  ayuda: 'Sirve para avisarte si un lote trae más pollitos de los que caben.',
                  teclado: TextInputType.number,
                  formatos: const [MilesAlEscribir()],
                ),
                const SizedBox(height: e16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: CampoGranja(
                        etiqueta: 'Largo en metros',
                        controller: _largo,
                        pista: 'Ej.: 12',
                        teclado: metros,
                        formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                      ),
                    ),
                    const SizedBox(width: e12),
                    Expanded(
                      child: CampoGranja(
                        etiqueta: 'Ancho en metros',
                        controller: _ancho,
                        pista: 'Ej.: 6',
                        teclado: metros,
                        formatos: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: e16),
                CampoGranja(
                  etiqueta: 'Dónde queda',
                  controller: _donde,
                  opcional: true,
                  pista: 'Ej.: detrás del tanque',
                  mayusculas: TextCapitalization.sentences,
                ),
                const SizedBox(height: e20),
                _ResumenGalpon(
                  nombre: _nombre.text.trim(),
                  donde: _donde.text.trim(),
                  caben: leerEntero(_capacidad.text),
                  largo: leerDecimal(_largo.text),
                  ancho: leerDecimal(_ancho.text),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: e12),
                  AvisoError(error),
                ],
                const SizedBox(height: e20),
                BotonPrincipal(
                  texto: 'Guardar galpón',
                  cargando: _guardando,
                  onPressed: _guardar,
                ),
                if (original != null && !tuvoLotes)
                  Center(
                    child: TextButton(
                      onPressed: () => _borrar(original),
                      child: const Text('Borrar este galpón'),
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

class _ResumenGalpon extends StatelessWidget {
  const _ResumenGalpon({
    required this.nombre,
    required this.donde,
    required this.caben,
    required this.largo,
    required this.ancho,
  });

  final String nombre;
  final String donde;
  final int? caben;
  final double? largo;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final caben = this.caben;
    final largo = this.largo;
    final ancho = this.ancho;
    final area = largo == null || ancho == null ? null : largo * ancho;
    final apoyo = textos.bodySmall!.copyWith(color: ColoresGranja.textoSobreTinta);
    final dato = textos.titleMedium!.copyWith(color: ColoresGranja.crema);

    return TarjetaTicket(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombre.isEmpty ? 'Nombre del galpón' : nombre,
            style: textos.titleLarge!.copyWith(color: ColoresGranja.maiz),
          ),
          Text(donde.isEmpty ? 'Libre, listo para un lote' : donde, style: apoyo),
          const SizedBox(height: e12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Caben', style: apoyo),
                    Text(
                      caben == null || caben == 0 ? 'Sin dato' : '${miles(caben)} pollos',
                      style: dato,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Área', style: apoyo),
                    Text(
                      area == null || area == 0 ? 'Sin dato' : '${decimal(area)} m²',
                      style: dato,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (caben != null && caben > 0 && area != null && area > 0) ...[
            const SizedBox(height: e8),
            Text(
              'Lleno quedaría a ${decimal(caben / area)} pollos por metro cuadrado.',
              style: apoyo,
            ),
          ],
        ],
      ),
    );
  }
}
