// DOMINIO: las reglas del galpón, en Dart puro.

import '../../../compartido/cifras.dart';

/// Error cuando un dato del galpón rompe una regla del negocio.
class GalponInvalido implements Exception {
  const GalponInvalido(this.mensaje, {this.campo});

  final String mensaje;

  /// El campo del formulario donde está el error, para señalarlo ahí.
  final String? campo;

  @override
  String toString() => 'GalponInvalido: $mensaje';
}

/// El lugar donde vive un lote. Solo el nombre es obligatorio; la capacidad y
/// las medidas sirven para avisar si un lote trae más pollitos de los que caben.
class Galpon {
  const Galpon.reconstruir({
    required this.id,
    required this.granjaId,
    required this.nombre,
    this.capacidad,
    this.largoM,
    this.anchoM,
    this.ubicacion,
  });

  /// Crea un galpón, o lo corrige si [id] ya existe, revisando las reglas.
  /// [otros] son los galpones que ya tiene la granja.
  factory Galpon.nuevo({
    required String id,
    required String granjaId,
    required String nombre,
    int? capacidad,
    double? largoM,
    double? anchoM,
    String? ubicacion,
    required Iterable<Galpon> otros,
  }) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw const GalponInvalido('El galpón necesita un nombre.', campo: 'nombre');
    }
    final repetido = otros.any(
      (otro) => otro.id != id && otro.nombre.toLowerCase() == limpio.toLowerCase(),
    );
    if (repetido) {
      throw const GalponInvalido('Ya tienes un galpón con ese nombre.', campo: 'nombre');
    }
    if (capacidad != null && capacidad <= 0) {
      throw const GalponInvalido('La capacidad debe ser mayor que cero.', campo: 'capacidad');
    }
    if (capacidad != null && capacidad > Topes.pollos) {
      throw const GalponInvalido(
        'Más de 100.000 pollos en un galpón no parece correcto. Revisa la cifra.',
        campo: 'capacidad',
      );
    }
    if ((largoM != null && largoM <= 0) || (anchoM != null && anchoM <= 0)) {
      throw const GalponInvalido('Las medidas deben ser mayores que cero.', campo: 'medidas');
    }
    if ((largoM ?? 0) > Topes.metros || (anchoM ?? 0) > Topes.metros) {
      throw const GalponInvalido(
        'Más de 1.000 metros no parece correcto. Revisa las medidas.',
        campo: 'medidas',
      );
    }
    final donde = ubicacion?.trim() ?? '';
    return Galpon.reconstruir(
      id: id,
      granjaId: granjaId,
      nombre: limpio,
      capacidad: capacidad,
      largoM: largoM,
      anchoM: anchoM,
      ubicacion: donde.isEmpty ? null : donde,
    );
  }

  final String id;
  final String granjaId;
  final String nombre;

  /// Cuántos pollos caben.
  final int? capacidad;
  final double? largoM;
  final double? anchoM;

  /// Dónde queda dentro de la granja, por ejemplo "detrás del tanque".
  final String? ubicacion;

  double? get areaM2 {
    final largo = largoM;
    final ancho = anchoM;
    return largo == null || ancho == null ? null : largo * ancho;
  }

  /// Pollos por metro cuadrado con el galpón lleno.
  double? get densidad {
    final caben = capacidad;
    final area = areaM2;
    return caben == null || area == null ? null : caben / area;
  }

  @override
  bool operator ==(Object other) => other is Galpon && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
