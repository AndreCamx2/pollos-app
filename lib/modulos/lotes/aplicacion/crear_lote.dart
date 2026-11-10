// APLICACIÓN (caso de uso): una acción que el usuario hace en la app.
// Junta el dominio (las reglas) con el puerto (dónde se guarda), sin saber
// si detrás hay Supabase, memoria o cualquier otra cosa.

import '../dominio/lote.dart';
import '../puertos/repositorio_lotes.dart';

class CrearLote {
  CrearLote({
    required RepositorioLotes repositorio,
    required String Function() generarId,
    required DateTime Function() reloj,
  })  : _repositorio = repositorio,
        _generarId = generarId,
        _reloj = reloj;

  final RepositorioLotes _repositorio;
  final String Function() _generarId;
  final DateTime Function() _reloj;

  /// Crea el lote y lo guarda. Si algún dato rompe una regla, lanza
  /// [LoteInvalido] y no se guarda nada.
  Future<Lote> call({
    required String galpon,
    required DateTime fechaLlegada,
    required int cantidadInicial,
    required int precioCompraTotal,
  }) async {
    final lote = Lote.nuevo(
      id: _generarId(),
      galpon: galpon,
      fechaLlegada: fechaLlegada,
      cantidadInicial: cantidadInicial,
      precioCompraTotal: precioCompraTotal,
      hoy: _reloj(),
    );
    await _repositorio.guardar(lote);
    return lote;
  }
}
