// DOMINIO: los números de un lote, sacados de lo que se ha anotado en él.

import 'dart:math';

import '../../lotes/dominio/lote.dart';
import 'registro.dart';

class CuentasLote {
  /// Se queda solo con los [registros] de este lote.
  CuentasLote(this.lote, Iterable<Registro> registros) {
    for (final registro in registros) {
      if (registro.loteId != lote.id) continue;
      final fecha = registro.fecha;
      if (_primerRegistro == null || fecha.isBefore(_primerRegistro!)) {
        _primerRegistro = fecha;
      }
      switch (registro) {
        case Mortalidad(:final cantidad):
          _muertos += cantidad;
        case CompraAlimento(tipo: TipoAlimento.inicio, :final total):
          _alimentoInicio += total;
        case CompraAlimento(tipo: TipoAlimento.engorde, :final total):
          _alimentoEngorde += total;
          _comproEngorde = true;
        case Medicamento(:final costo):
          _medicina += costo;
        case Venta(:final pollos, :final libras, :final total):
          _vendidos += pollos;
          _librasVendidas += libras;
          _ventas += total;
      }
    }
  }

  final Lote lote;

  var _muertos = 0;
  var _alimentoInicio = 0;
  var _alimentoEngorde = 0;
  var _medicina = 0;
  var _vendidos = 0;
  var _librasVendidas = 0.0;
  var _ventas = 0;
  var _comproEngorde = false;
  DateTime? _primerRegistro;

  int get muertos => _muertos;

  int get vendidos => _vendidos;
  double get librasVendidas => _librasVendidas;

  /// Lo que suman las ventas, fiadas o de contado.
  int get ventas => _ventas;

  /// Lo vendido menos lo invertido; negativo mientras no se ha recuperado.
  int get ganancia => ventas - invertido;

  /// Nunca menos de cero, aunque lo que llegue del servidor no cuadre.
  int get vivos => max(0, lote.cantidadInicial - muertos - vendidos);

  /// Muertos sobre los que llegaron, de 0 a 100.
  double get mortalidad => muertos * 100 / lote.cantidadInicial;

  int get alimentoInicio => _alimentoInicio;
  int get alimentoEngorde => _alimentoEngorde;
  int get alimento => _alimentoInicio + _alimentoEngorde;
  int get medicina => _medicina;

  /// Lo que se ha puesto en el lote: pollitos, alimento y medicina.
  int get invertido => lote.precioCompraTotal + alimento + medicina;

  bool get tieneRegistros => _primerRegistro != null;

  /// La fecha del registro más antiguo; la llegada del lote no puede ser después.
  DateTime? get primerRegistro => _primerRegistro;

  /// Ya pasó el día 21 y todavía no se ha comprado alimento de engorde.
  bool tocaCambiarAEngorde(DateTime hoy) =>
      lote.etapaAlimento(hoy) != EtapaAlimento.inicio && !_comproEngorde;

  /// Los vivos sin contar [registro], para corregirlo sin contarlo dos veces.
  int vivosSin(Registro? registro) =>
      vivos +
      switch (registro) {
        Mortalidad(:final cantidad) => cantidad,
        Venta(:final pollos) => pollos,
        _ => 0,
      };
}
