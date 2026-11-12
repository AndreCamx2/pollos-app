import 'package:supabase_flutter/supabase_flutter.dart';

import '../errores.dart';
import '../local/base_local.dart';
import 'remoto.dart';

/// Pone de acuerdo el celular con el servidor: sube lo que está en la cola y
/// baja lo que cambiaron los demás.
class Sincronizador {
  Sincronizador(this._local, this._remoto);

  final BaseLocal _local;
  final Remoto _remoto;

  // Se vuelve a pedir desde un poco antes de lo último que se vio: una fila
  // guardada en una transacción lenta aparece con una hora que ya pasó.
  static const _margen = Duration(minutes: 5);

  /// Si no hay señal lanza el error de red y la cola queda como estaba.
  Future<void> sincronizar(String granjaId) async {
    await _subir(granjaId);
    await _bajar(granjaId);
  }

  /// Deshace un cambio que el servidor rechazó.
  Future<void> descartar(Pendiente pendiente) async {
    final enServidor = await _remoto.buscar(pendiente.tabla, pendiente.filaId);
    await _local.descartar(pendiente, enServidor);
  }

  Future<void> _subir(String granjaId) async {
    for (final pendiente in await _local.pendientes(granjaId)) {
      try {
        if (pendiente.datos case final fila?) {
          await _remoto.guardar(pendiente.tabla, filaParaServidor(fila));
        } else {
          await _remoto.borrar(pendiente.tabla, pendiente.filaId);
        }
        await _local.quitarPendiente(pendiente);
      } on PostgrestException catch (e) {
        // PGRST3xx es la sesión vencida, no el dato: se intenta más tarde.
        if (e.code?.startsWith('PGRST3') ?? false) rethrow;
        await _local.rechazar(pendiente, mensajeDeError(e));
      }
    }
  }

  Future<void> _bajar(String granjaId) async {
    final marcaBorrados = 'bajado:$granjaId:borrados';
    final borrados = await _remoto.borrados(granjaId, await _desde(marcaBorrados));
    for (final tabla in columnasLocales.keys) {
      final marca = 'bajado:$granjaId:$tabla';
      final cambiadas = await _remoto.cambios(tabla, granjaId, await _desde(marca));
      await _local.recibir(
        tabla,
        cambiadas: cambiadas,
        borradas: [
          for (final b in borrados)
            if (b['tabla'] == tabla) b['fila_id'] as String,
        ],
      );
      await _avanzar(marca, [for (final f in cambiadas) f['cambiado_en'] as String]);
    }
    await _avanzar(marcaBorrados, [for (final b in borrados) b['borrado_en'] as String]);
  }

  Future<DateTime?> _desde(String marca) async {
    final ultima = await _local.leerDato(marca) as String?;
    return ultima == null ? null : DateTime.parse(ultima).subtract(_margen);
  }

  Future<void> _avanzar(String marca, List<String> fechas) async {
    if (fechas.isEmpty) return;
    final ultima = fechas
        .map(DateTime.parse)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    await _local.guardarDato(marca, ultima.toUtc().toIso8601String());
  }
}
