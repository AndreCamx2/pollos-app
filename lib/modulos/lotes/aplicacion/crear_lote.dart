// APLICACIÓN (caso de uso): una acción que el usuario hace en la app.
// Junta el dominio (las reglas) con el puerto (dónde se guarda), sin saber
// si detrás hay una base de datos, memoria o cualquier otra cosa.

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

  /// Crea el lote y lo guarda. Si algún dato rompe una regla, o el galpón
  /// todavía tiene un lote abierto, lanza [LoteInvalido] y no se guarda nada.
  Future<Lote> call({
    required String granjaId,
    required String galponId,
    required DateTime fechaLlegada,
    required int cantidadInicial,
    required int precioCompraTotal,
  }) async {
    if (await _repositorio.abiertoEn(galponId) != null) {
      throw const LoteInvalido(
        'Ese galpón todavía tiene un lote abierto. Ciérralo antes de recibir pollitos nuevos.',
      );
    }
    final lote = Lote.nuevo(
      id: _generarId(),
      granjaId: granjaId,
      galponId: galponId,
      fechaLlegada: fechaLlegada,
      cantidadInicial: cantidadInicial,
      precioCompraTotal: precioCompraTotal,
      hoy: _reloj(),
    );
    await _repositorio.guardar(lote);
    return lote;
  }
}
