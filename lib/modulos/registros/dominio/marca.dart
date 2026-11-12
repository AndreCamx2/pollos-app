// DOMINIO: las marcas de alimento de la granja, en Dart puro.

import '../../../compartido/cifras.dart';
import 'registro.dart';

class Marca {
  const Marca.reconstruir({
    required this.id,
    required this.granjaId,
    required this.nombre,
    this.kilosPorBulto,
    this.enUso = true,
    this.creadoPor,
  });

  /// Crea una marca, o la corrige si [id] ya existe. [otras] son las marcas
  /// que ya tiene la granja.
  factory Marca.nueva({
    required String id,
    required String granjaId,
    required String nombre,
    double? kilosPorBulto,
    bool enUso = true,
    required Iterable<Marca> otras,
  }) {
    final limpio = nombre.trim();
    if (limpio.isEmpty) {
      throw const RegistroInvalido('Escribe el nombre de la marca.', campo: 'nombre');
    }
    if (otras.any((o) => o.id != id && o.nombre.toLowerCase() == limpio.toLowerCase())) {
      throw const RegistroInvalido('Ya tienes una marca con ese nombre.', campo: 'nombre');
    }
    final kilos = kilosPorBulto;
    if (kilos != null && (kilos <= 0 || kilos > Topes.kilosPorBulto)) {
      throw const RegistroInvalido(
        'Los kilos por bulto deben estar entre 1 y 100.',
        campo: 'kilos',
      );
    }
    return Marca.reconstruir(
      id: id,
      granjaId: granjaId,
      nombre: limpio,
      kilosPorBulto: kilos,
      enUso: enUso,
    );
  }

  final String id;
  final String granjaId;
  final String nombre;

  /// Lo que trae un bulto normalmente; se pone solo al elegir la marca.
  final double? kilosPorBulto;

  /// Las que ya no se usan van al final de la lista en vez de borrarse.
  final bool enUso;
  final String? creadoPor;

  bool puedeCambiarla({required bool administra, required String? usuarioId}) =>
      administra || (usuarioId != null && creadoPor == usuarioId);

  @override
  bool operator ==(Object other) => other is Marca && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Una marca con lo que se le ha comprado. [ultimoPrecio] es el precio por
/// bulto de su compra más reciente.
typedef MarcaConCompras = ({Marca marca, int compras, int? ultimoPrecio});

/// Primero las que se usan, y luego por nombre.
int ordenDeMarcas(MarcaConCompras a, MarcaConCompras b) {
  if (a.marca.enUso != b.marca.enUso) return a.marca.enUso ? -1 : 1;
  return a.marca.nombre.toLowerCase().compareTo(b.marca.nombre.toLowerCase());
}

/// [compras] vienen de la más reciente a la más antigua.
List<MarcaConCompras> marcasConCompras(
  Iterable<Marca> marcas,
  List<CompraAlimento> compras,
) =>
    [
      for (final marca in marcas)
        if (compras.where((c) => c.marcaId == marca.id).toList() case final suyas)
          (
            marca: marca,
            compras: suyas.length,
            ultimoPrecio: suyas.firstOrNull?.precioPorBulto,
          ),
    ]..sort(ordenDeMarcas);
