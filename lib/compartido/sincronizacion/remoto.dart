import 'package:supabase_flutter/supabase_flutter.dart';

/// Lo que el sincronizador necesita del servidor.
abstract interface class Remoto {
  /// Crea la fila o la reemplaza si ya existe.
  Future<void> guardar(String tabla, Map<String, Object?> fila);

  Future<void> borrar(String tabla, String id);

  Future<Map<String, dynamic>?> buscar(String tabla, String id);

  /// Filas de la granja creadas o cambiadas después de [desde]; todas si es null.
  Future<List<Map<String, dynamic>>> cambios(
    String tabla,
    String granjaId,
    DateTime? desde,
  );

  /// Lo que se borró en la granja después de [desde], de cualquier tabla.
  Future<List<Map<String, dynamic>>> borrados(String granjaId, DateTime? desde);
}

class RemotoSupabase implements Remoto {
  RemotoSupabase(this._supabase);

  final SupabaseClient _supabase;

  // Supabase entrega máximo 1000 filas por consulta.
  static const _porPagina = 1000;

  @override
  Future<void> guardar(String tabla, Map<String, Object?> fila) async {
    await _supabase.from(tabla).upsert(fila);
  }

  @override
  Future<void> borrar(String tabla, String id) async {
    await _supabase.from(tabla).delete().eq('id', id);
  }

  @override
  Future<Map<String, dynamic>?> buscar(String tabla, String id) =>
      _supabase.from(tabla).select().eq('id', id).maybeSingle();

  @override
  Future<List<Map<String, dynamic>>> cambios(
    String tabla,
    String granjaId,
    DateTime? desde,
  ) =>
      _todasLasPaginas(tabla, granjaId, 'cambiado_en', desde, ordenadaPor: 'id');

  @override
  Future<List<Map<String, dynamic>>> borrados(String granjaId, DateTime? desde) =>
      _todasLasPaginas('borrados', granjaId, 'borrado_en', desde, ordenadaPor: 'fila_id');

  Future<List<Map<String, dynamic>>> _todasLasPaginas(
    String tabla,
    String granjaId,
    String columnaDeFecha,
    DateTime? desde, {
    required String ordenadaPor,
  }) async {
    final todas = <Map<String, dynamic>>[];
    while (true) {
      var consulta = _supabase.from(tabla).select().eq('granja_id', granjaId);
      if (desde != null) {
        consulta = consulta.gt(columnaDeFecha, desde.toUtc().toIso8601String());
      }
      final pagina = await consulta
          .order(ordenadaPor)
          .range(todas.length, todas.length + _porPagina - 1);
      todas.addAll(pagina);
      if (pagina.length < _porPagina) return todas;
    }
  }
}
