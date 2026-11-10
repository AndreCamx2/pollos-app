import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../galpones/dominio/galpon.dart';
import '../../../lotes/dominio/lote.dart';
import '../../dominio/cuentas_lote.dart';
import '../../dominio/registro.dart';

typedef LoteAbierto = ({Galpon galpon, Lote lote, CuentasLote cuentas});

/// El lote donde se va a anotar. Null si ya no está abierto: alguien lo
/// cerró o lo borró mientras tanto.
LoteAbierto? loteAbierto(WidgetRef ref, String loteId) {
  final galpones = ref.watch(galponesProvider).asData?.value ?? const <GalponConLote>[];
  for (final (:galpon, :lote, :cuentas) in galpones) {
    if (lote != null && cuentas != null && lote.id == loteId) {
      return (galpon: galpon, lote: lote, cuentas: cuentas);
    }
  }
  return null;
}

/// El registro que se va a corregir, o null si es uno nuevo.
T? registroGuardado<T extends Registro>(WidgetRef ref, String? id) =>
    (ref.read(registrosProvider).asData?.value ?? const <Registro>[])
        .whereType<T>()
        .where((registro) => registro.id == id)
        .firstOrNull;

/// Lo que comparten los formularios de alimento, muertos y medicina.
class MarcoRegistro extends StatelessWidget {
  const MarcoRegistro({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.campos,
    required this.resumen,
    required this.textoGuardar,
    required this.guardando,
    required this.alGuardar,
    this.error,
    this.alBorrar,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> campos;

  /// La tarjeta oscura con lo que va a quedar al guardar.
  final Widget resumen;
  final String textoGuardar;
  final bool guardando;
  final VoidCallback alGuardar;
  final String? error;

  /// Solo al corregir un registro que la persona puede cambiar.
  final VoidCallback? alBorrar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: e24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(titulo: titulo, subtitulo: subtitulo),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(e16, e20, e16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...campos,
                const SizedBox(height: e20),
                resumen,
                if (error case final error?) ...[
                  const SizedBox(height: e12),
                  AvisoError(error),
                ],
                const SizedBox(height: e20),
                BotonPrincipal(
                  texto: textoGuardar,
                  cargando: guardando,
                  onPressed: alGuardar,
                ),
                if (alBorrar != null)
                  Center(
                    child: TextButton(
                      onPressed: alBorrar,
                      child: const Text('Borrar este registro'),
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

/// Para cuando el lote se cerró o se borró mientras la persona anotaba.
class LoteNoDisponible extends StatelessWidget {
  const LoteNoDisponible({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(e24),
          child: Text(
            'Este lote ya está cerrado o ya no existe, así que no se puede anotar en él.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Etiqueta en negrilla encima de un grupo de opciones.
class EtiquetaCampo extends StatelessWidget {
  const EtiquetaCampo(this.texto, {super.key, this.opcional = false});

  final String texto;
  final bool opcional;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.only(bottom: e8),
      child: Text.rich(
        TextSpan(
          text: texto,
          style: conPeso(estilo, 700),
          children: [
            if (opcional)
              TextSpan(
                text: ' (opcional)',
                style: conPeso(estilo.copyWith(color: ColoresGranja.tintaSuave), 500),
              ),
          ],
        ),
      ),
    );
  }
}
