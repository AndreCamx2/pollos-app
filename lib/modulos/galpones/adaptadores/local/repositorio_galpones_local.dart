// ADAPTADOR: guarda los galpones en la base del celular. De ahí el
// sincronizador los sube cuando hay señal.

import '../../../../compartido/local/base_local.dart';
import '../../dominio/galpon.dart';

class RepositorioGalponesLocal {
  RepositorioGalponesLocal(this._local, {required this.autor});

  final BaseLocal _local;

  /// Quien está usando la app; queda como autor de lo que cree.
  final String? autor;

  Future<void> guardar(Galpon galpon) => _local.guardarFila(
        'galpones',
        {
          'id': galpon.id,
          'granja_id': galpon.granjaId,
          'nombre': galpon.nombre,
          'capacidad': galpon.capacidad,
          'largo_m': galpon.largoM,
          'ancho_m': galpon.anchoM,
          'ubicacion': galpon.ubicacion,
        },
        titulo: galpon.nombre,
        autor: autor,
      );

  Future<void> borrar(Galpon galpon) => _local.borrarFila(
        'galpones',
        galpon.id,
        granjaId: galpon.granjaId,
        titulo: galpon.nombre,
      );

  /// Los galpones de la granja, en el orden en que se crearon.
  Future<List<Galpon>> listar(String granjaId) async {
    final filas = await _local.filas(
      'galpones',
      granjaId: granjaId,
      orden: 'creado_en',
    );
    return [
      for (final fila in filas)
        Galpon.reconstruir(
          id: fila['id']! as String,
          granjaId: fila['granja_id']! as String,
          nombre: fila['nombre']! as String,
          capacidad: fila['capacidad'] as int?,
          largoM: (fila['largo_m'] as num?)?.toDouble(),
          anchoM: (fila['ancho_m'] as num?)?.toDouble(),
          ubicacion: fila['ubicacion'] as String?,
        ),
    ];
  }
}
