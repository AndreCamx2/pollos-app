// DOMINIO: los números de un lote, sacados de lo que se ha anotado en él.

import 'dart:math';

import '../../lotes/dominio/lote.dart';
import 'registro.dart';

/// Lo que se le vendió a un cliente en un lote.
typedef VentasACliente = ({String clienteId, int pollos, double libras, int total});

class CuentasLote {
  /// Se queda solo con los [registros] de este lote.
  CuentasLote(this.lote, Iterable<Registro> registros) {
    final porCliente = <String, VentasACliente>{};
    for (final registro in registros) {
      if (registro.loteId != lote.id) continue;
      final fecha = registro.fecha;
      if (_primerRegistro == null || fecha.isBefore(_primerRegistro!)) {
        _primerRegistro = fecha;
      }
      switch (registro) {
        case Mortalidad(causa: CausaMuerte.faltante, :final cantidad):
          _faltantes += cantidad;
        case Mortalidad(:final cantidad, :final causa):
          _muertos += cantidad;
          _causas[causa] = (_causas[causa] ?? 0) + cantidad;
        case CompraAlimento(tipo: TipoAlimento.inicio, :final total, :final bultos, :final kilos):
          _alimentoInicio += total;
          _bultosInicio += bultos;
          _kilosInicio += kilos;
        case CompraAlimento(tipo: TipoAlimento.engorde, :final total, :final bultos, :final kilos):
          _alimentoEngorde += total;
          _bultosEngorde += bultos;
          _kilosEngorde += kilos;
          if (_primerEngorde == null || fecha.isBefore(_primerEngorde!)) _primerEngorde = fecha;
        case Medicamento(:final costo):
          _medicina += costo;
          _medicinas++;
        case Venta(:final pollos, :final libras, :final total, :final clienteId):
          _vendidos += pollos;
          _librasVendidas += libras;
          _ventas += total;
          final antes = porCliente[clienteId];
          porCliente[clienteId] = (
            clienteId: clienteId,
            pollos: (antes?.pollos ?? 0) + pollos,
            libras: (antes?.libras ?? 0) + libras,
            total: (antes?.total ?? 0) + total,
          );
          if (_primeraVenta == null || fecha.isBefore(_primeraVenta!.fecha)) {
            _primeraVenta = (fecha: fecha, clienteId: clienteId);
          }
      }
    }
    ventasPorCliente = porCliente.values.toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  final Lote lote;

  var _muertos = 0;
  var _faltantes = 0;
  final _causas = <CausaMuerte?, int>{};
  var _alimentoInicio = 0;
  var _alimentoEngorde = 0;
  var _bultosInicio = 0;
  var _bultosEngorde = 0;
  var _kilosInicio = 0.0;
  var _kilosEngorde = 0.0;
  var _medicina = 0;
  var _medicinas = 0;
  var _vendidos = 0;
  var _librasVendidas = 0.0;
  var _ventas = 0;
  DateTime? _primerRegistro;
  DateTime? _primerEngorde;
  ({DateTime fecha, String clienteId})? _primeraVenta;

  /// A quién se le vendió, el que más compró primero.
  late final List<VentasACliente> ventasPorCliente;

  /// Los que se murieron. Los faltantes van aparte.
  int get muertos => _muertos;

  /// Los que no aparecieron al cerrar el lote: robados, perdidos o mal contados.
  int get faltantes => _faltantes;

  /// Cuántos murieron por cada causa; null es sin causa.
  Map<CausaMuerte?, int> get causas => Map.unmodifiable(_causas);

  int get vendidos => _vendidos;
  double get librasVendidas => _librasVendidas;

  /// Todos los que ya no están en el galpón.
  int get salieron => muertos + faltantes + vendidos;

  /// Lo que suman las ventas, fiadas o de contado.
  int get ventas => _ventas;

  /// Lo vendido menos lo invertido; negativo mientras no se ha recuperado.
  int get ganancia => ventas - invertido;

  /// Nunca menos de cero, aunque lo que llegue del servidor no cuadre.
  int get vivos => max(0, lote.cantidadInicial - salieron);

  /// Muertos sobre los que llegaron, de 0 a 100.
  double get mortalidad => muertos * 100 / lote.cantidadInicial;

  int get alimentoInicio => _alimentoInicio;
  int get alimentoEngorde => _alimentoEngorde;
  int get alimento => _alimentoInicio + _alimentoEngorde;
  int get bultosInicio => _bultosInicio;
  int get bultosEngorde => _bultosEngorde;
  double get kilosInicio => _kilosInicio;
  double get kilosEngorde => _kilosEngorde;
  double get kilosAlimento => _kilosInicio + _kilosEngorde;
  int get medicina => _medicina;

  /// Cuántas medicinas se anotaron.
  int get medicinas => _medicinas;

  /// Lo que se ha puesto en el lote: pollitos, alimento y medicina.
  int get invertido => lote.precioCompraTotal + alimento + medicina;

  /// La ganancia sobre lo vendido, de 0 a 100; null si no se ha vendido.
  double? get margen => ventas == 0 ? null : ganancia * 100 / ventas;

  /// Libras por pollo vendido.
  double? get pesoPromedio => vendidos == 0 ? null : librasVendidas / vendidos;

  double? get precioPromedioLibra => librasVendidas == 0 ? null : ventas / librasVendidas;

  /// Kilos de alimento por cada kilo de pollo vendido. Lo normal en pollo de
  /// engorde es de 1,6 a 1,9; más alto es alimento desperdiciado o pollo liviano.
  double? get conversion =>
      librasVendidas == 0 || kilosAlimento == 0 ? null : kilosAlimento / (librasVendidas * _kilosPorLibra);

  static const _kilosPorLibra = 0.45359237;
  static const conversionNormal = 1.9;

  int? get costoPorPollo => vendidos == 0 ? null : (invertido / vendidos).round();
  int? get costoPorLibra => librasVendidas == 0 ? null : (invertido / librasVendidas).round();
  int? get gananciaPorPollo => vendidos == 0 ? null : (ganancia / vendidos).round();

  bool get tieneRegistros => _primerRegistro != null;

  /// La fecha del registro más antiguo; la llegada del lote no puede ser después.
  DateTime? get primerRegistro => _primerRegistro;

  /// Cuándo se compró el primer bulto de engorde.
  DateTime? get primerEngorde => _primerEngorde;

  ({DateTime fecha, String clienteId})? get primeraVenta => _primeraVenta;

  /// Días desde la llegada hasta el cierre, o hasta [hoy] si sigue abierto.
  int dias(DateTime hoy) => lote.diasDeEdad(lote.cerradoEn?.toLocal() ?? hoy);

  /// Ya pasó el día 21 y todavía no se ha comprado alimento de engorde.
  bool tocaCambiarAEngorde(DateTime hoy) =>
      lote.etapaAlimento(hoy) != EtapaAlimento.inicio && _primerEngorde == null;

  /// Los vivos sin contar [registro], para corregirlo sin contarlo dos veces.
  int vivosSin(Registro? registro) =>
      vivos +
      switch (registro) {
        Mortalidad(:final cantidad) => cantidad,
        Venta(:final pollos) => pollos,
        _ => 0,
      };
}
