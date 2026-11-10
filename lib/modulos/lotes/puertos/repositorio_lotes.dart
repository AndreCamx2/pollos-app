// PUERTO: lo que la aplicación necesita para guardar y leer lotes.
// Es solo un contrato: dice QUÉ se puede hacer, no CÓMO. El cómo lo pone
// cada adaptador (en memoria para las pruebas, Supabase en la app real).

import '../dominio/lote.dart';

abstract interface class RepositorioLotes {
  Future<void> guardar(Lote lote);

  /// Devuelve el lote, o null si no existe.
  Future<Lote?> buscarPorId(String id);

  Future<List<Lote>> listar();
}
