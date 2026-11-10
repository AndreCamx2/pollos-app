// DOMINIO: lo que se anota en un lote día a día, en Dart puro.

import '../../../compartido/fechas.dart';
import '../../../compartido/formato.dart';
import '../../lotes/dominio/lote.dart';

enum TipoAlimento {
  inicio('Inicio'),
  engorde('Engorde');

  const TipoAlimento(this.etiqueta);

  final String etiqueta;
}

/// Los nombres coinciden con los valores de la columna mortalidad.causa.
enum CausaMuerte {
  calor('Calor'),
  enfermedad('Enfermedad'),
  aplastamiento('Aplastamiento'),
  otra('Otra');

  const CausaMuerte(this.etiqueta);

  final String etiqueta;
}

/// Error cuando un dato del registro rompe una regla del negocio.
class RegistroInvalido implements Exception {
  const RegistroInvalido(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'RegistroInvalido: $mensaje';
}

/// Algo que se anotó en un lote: una compra de alimento, unos muertos o una
/// medicina. Cada clase tiene un constructor `nueva` que revisa las reglas
/// (también sirve para corregir uno que ya existe, con su mismo id) y uno
/// `reconstruir` para lo que ya estaba guardado.
sealed class Registro {
  Registro({
    required this.id,
    required this.granjaId,
    required this.loteId,
    required DateTime fecha,
    this.creadoPor,
    this.creadoEn,
  }) : fecha = soloFecha(fecha);

  final String id;
  final String granjaId;
  final String loteId;
  final DateTime fecha;

  /// Quién lo anotó; null mientras no se ha guardado.
  final String? creadoPor;
  final DateTime? creadoEn;

  /// El dueño y el administrador cambian cualquier registro; el trabajador,
  /// solo los que anotó él.
  bool puedeCambiarlo({required bool administra, required String? usuarioId}) =>
      administra || (usuarioId != null && creadoPor == usuarioId);
}

void _revisarLoteYFecha(Lote lote, DateTime fecha, DateTime hoy) {
  if (!lote.abierto) {
    throw const RegistroInvalido(
      'Este lote ya está cerrado. Reábrelo para registrar cambios.',
    );
  }
  if (soloFecha(fecha).isBefore(lote.fechaLlegada)) {
    throw RegistroInvalido(
      'La fecha no puede ser anterior a la llegada del lote (${fechaCorta(lote.fechaLlegada)}).',
    );
  }
  if (soloFecha(fecha).isAfter(soloFecha(hoy))) {
    throw const RegistroInvalido('La fecha no puede ser en el futuro.');
  }
}

String? _sinVacio(String? texto) {
  final limpio = texto?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

final class CompraAlimento extends Registro {
  CompraAlimento.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.tipo,
    required this.marca,
    required this.kilosPorBulto,
    required this.bultos,
    required this.precioPorBulto,
    super.creadoPor,
    super.creadoEn,
  });

  factory CompraAlimento.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required TipoAlimento tipo,
    required String marca,
    required double kilosPorBulto,
    required int bultos,
    required int precioPorBulto,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    final nombre = _sinVacio(marca);
    if (nombre == null) {
      throw const RegistroInvalido('Escribe la marca del alimento.');
    }
    if (bultos <= 0) {
      throw const RegistroInvalido('Los bultos deben ser más de cero.');
    }
    if (kilosPorBulto <= 0) {
      throw const RegistroInvalido('Los kilos por bulto deben ser más de cero.');
    }
    if (precioPorBulto < 0) {
      throw const RegistroInvalido('El precio no puede ser negativo.');
    }
    return CompraAlimento.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      tipo: tipo,
      marca: nombre,
      kilosPorBulto: kilosPorBulto,
      bultos: bultos,
      precioPorBulto: precioPorBulto,
    );
  }

  final TipoAlimento tipo;
  final String marca;
  final double kilosPorBulto;
  final int bultos;

  /// En pesos enteros, como toda la plata de la app.
  final int precioPorBulto;

  int get total => bultos * precioPorBulto;

  double get kilos => bultos * kilosPorBulto;
}

final class Mortalidad extends Registro {
  Mortalidad.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.cantidad,
    this.causa,
    this.nota,
    super.creadoPor,
    super.creadoEn,
  });

  /// [vivosSinEste] son los vivos del lote contando todo menos este registro,
  /// para que al corregirlo no se cuente dos veces.
  factory Mortalidad.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required int cantidad,
    CausaMuerte? causa,
    String? nota,
    required int vivosSinEste,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    if (cantidad <= 0) {
      throw const RegistroInvalido('Escribe cuántos se murieron.');
    }
    if (cantidad > vivosSinEste) {
      throw RegistroInvalido('Solo quedan $vivosSinEste pollos vivos en este lote.');
    }
    return Mortalidad.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      cantidad: cantidad,
      causa: causa,
      nota: _sinVacio(nota),
    );
  }

  final int cantidad;
  final CausaMuerte? causa;
  final String? nota;
}

final class Medicamento extends Registro {
  Medicamento.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.nombre,
    required this.costo,
    this.nota,
    super.creadoPor,
    super.creadoEn,
  });

  factory Medicamento.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required String nombre,
    required int costo,
    String? nota,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    final limpio = _sinVacio(nombre);
    if (limpio == null) {
      throw const RegistroInvalido('Escribe qué medicina se compró.');
    }
    if (costo < 0) {
      throw const RegistroInvalido('El costo no puede ser negativo.');
    }
    return Medicamento.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      nombre: limpio,
      costo: costo,
      nota: _sinVacio(nota),
    );
  }

  final String nombre;
  final int costo;

  /// Para qué es o cómo se da.
  final String? nota;
}
