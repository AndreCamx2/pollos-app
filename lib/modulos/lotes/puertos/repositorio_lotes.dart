// PUERTO: lo que la aplicación necesita para guardar y leer lotes.
// Es solo un contrato: dice QUÉ se puede hacer, no CÓMO. El cómo lo pone
// cada adaptador (en memoria para las pruebas, la base local en la app real).

import '../dominio/lote.dart';

abstract interface class RepositorioLotes {
  Future<void> guardar(Lote lote);

  Future<void> borrar(Lote lote);

  /// Devuelve el lote, o null si no existe.
  Future<Lote?> buscarPorId(String id);

  /// El lote que está ocupando el galpón, o null si el galpón está libre.
  Future<Lote?> abiertoEn(String galponId);

  /// Los lotes de la granja, del más reciente al más antiguo.
  Future<List<Lote>> listar(String granjaId);
}
