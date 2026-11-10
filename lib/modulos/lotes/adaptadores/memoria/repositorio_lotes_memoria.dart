// ADAPTADOR: una forma concreta de cumplir el puerto RepositorioLotes.
// Este guarda los lotes en memoria (se borran al cerrar la app). Sirve para
// las pruebas.

import '../../dominio/lote.dart';
import '../../puertos/repositorio_lotes.dart';

class RepositorioLotesMemoria implements RepositorioLotes {
  final _lotes = <String, Lote>{};

  @override
  Future<void> guardar(Lote lote) async {
    _lotes[lote.id] = lote;
  }

  @override
  Future<void> borrar(Lote lote) async {
    _lotes.remove(lote.id);
  }

  @override
  Future<Lote?> buscarPorId(String id) async => _lotes[id];

  @override
  Future<Lote?> abiertoEn(String galponId) async => _lotes.values
      .where((lote) => lote.galponId == galponId && lote.abierto)
      .firstOrNull;

  @override
  Future<List<Lote>> listar(String granjaId) async => _lotes.values
      .where((lote) => lote.granjaId == granjaId)
      .toList()
    ..sort((a, b) => b.fechaLlegada.compareTo(a.fechaLlegada));
}
