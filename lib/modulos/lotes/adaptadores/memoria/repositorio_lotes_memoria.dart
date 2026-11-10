// ADAPTADOR: una forma concreta de cumplir el puerto RepositorioLotes.
// Este guarda los lotes en memoria (se borran al cerrar la app). Sirve para
// las pruebas y para avanzar antes de conectar Supabase.

import '../../dominio/lote.dart';
import '../../puertos/repositorio_lotes.dart';

class RepositorioLotesMemoria implements RepositorioLotes {
  final _lotes = <String, Lote>{};

  @override
  Future<void> guardar(Lote lote) async {
    _lotes[lote.id] = lote;
  }

  @override
  Future<Lote?> buscarPorId(String id) async => _lotes[id];

  @override
  Future<List<Lote>> listar() async => _lotes.values.toList();
}
