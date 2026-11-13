// ADAPTADOR: guarda los lotes en la base del celular. De ahí el
// sincronizador los sube cuando hay señal.

import '../../../../compartido/formato.dart';
import '../../../../compartido/local/base_local.dart';
import '../../dominio/lote.dart';
import '../../puertos/repositorio_lotes.dart';

class RepositorioLotesLocal implements RepositorioLotes {
  RepositorioLotesLocal(this._local, {required this.autor});

  final BaseLocal _local;

  /// Quien está usando la app; queda como autor de lo que cree.
  final String? autor;

  @override
  Future<void> guardar(Lote lote) => _local.guardarFila(
        'lotes',
        {
          'id': lote.id,
          'granja_id': lote.granjaId,
          'galpon_id': lote.galponId,
          'fecha_llegada': lote.fechaLlegada.toIso8601String().substring(0, 10),
          'cantidad_inicial': lote.cantidadInicial,
          'precio_compra_total': lote.precioCompraTotal,
          'cerrado_en': lote.cerradoEn?.toUtc().toIso8601String(),
        },
        titulo: _titulo(lote),
        autor: autor,
      );

  @override
  Future<void> borrar(Lote lote) => _local.borrarFila(
        'lotes',
        lote.id,
        granjaId: lote.granjaId,
        titulo: _titulo(lote),
      );

  @override
  Future<Lote?> buscarPorId(String id) async {
    final fila = await _local.fila('lotes', id);
    return fila == null ? null : _aLote(fila);
  }

  @override
  Future<Lote?> abiertoEn(String galponId) async {
    final galpon = await _local.fila('galpones', galponId);
    if (galpon == null) return null;
    final lotes = await listar(galpon['granja_id']! as String);
    return lotes.where((l) => l.galponId == galponId && l.abierto).firstOrNull;
  }

  @override
  Future<List<Lote>> listar(String granjaId) async {
    final filas = await _local.filas(
      'lotes',
      granjaId: granjaId,
      orden: 'fecha_llegada desc',
    );
    return filas.map(_aLote).toList();
  }

  String _titulo(Lote lote) => 'Lote del ${fechaCorta(lote.fechaLlegada)}';

  Lote _aLote(Map<String, Object?> fila) {
    final cierre = fila['cerrado_en'] as String?;
    return Lote.reconstruir(
      id: fila['id']! as String,
      granjaId: fila['granja_id']! as String,
      galponId: fila['galpon_id']! as String,
      fechaLlegada: DateTime.parse(fila['fecha_llegada']! as String),
      cantidadInicial: fila['cantidad_inicial']! as int,
      precioCompraTotal: fila['precio_compra_total']! as int,
      cerradoEn: cierre == null ? null : DateTime.parse(cierre),
    );
  }
}
