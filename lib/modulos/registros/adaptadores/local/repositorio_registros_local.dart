// ADAPTADOR: guarda los registros del lote en la base del celular. De ahí el
// sincronizador los sube cuando hay señal.

import '../../../../compartido/fechas.dart';
import '../../../../compartido/formato.dart';
import '../../../../compartido/local/base_local.dart';
import '../../dominio/registro.dart';

class RepositorioRegistrosLocal {
  RepositorioRegistrosLocal(this._local, {required this.autor});

  final BaseLocal _local;

  /// Quien está usando la app; queda como autor de lo que anote.
  final String? autor;

  Future<void> guardar(Registro registro) => _local.guardarFila(
        _tabla(registro),
        {
          'id': registro.id,
          'granja_id': registro.granjaId,
          'lote_id': registro.loteId,
          'fecha': fechaParaBase(registro.fecha),
          ...switch (registro) {
            CompraAlimento c => {
                'tipo': c.tipo.name,
                'marca': c.marca,
                'kilos_por_bulto': c.kilosPorBulto,
                'bultos': c.bultos,
                'precio_por_bulto': c.precioPorBulto,
              },
            Mortalidad m => {
                'cantidad': m.cantidad,
                'causa': m.causa?.name,
                'nota': m.nota,
              },
            Medicamento m => {
                'nombre': m.nombre,
                'costo': m.costo,
                'nota': m.nota,
              },
          },
        },
        titulo: _titulo(registro),
        autor: autor,
      );

  Future<void> borrar(Registro registro) => _local.borrarFila(
        _tabla(registro),
        registro.id,
        granjaId: registro.granjaId,
        titulo: _titulo(registro),
      );

  /// Todo lo anotado en la granja, lo más reciente primero.
  Future<List<Registro>> listar(String granjaId) async {
    final registros = <Registro>[
      for (final f in await _local.filas('compras_alimento', granjaId: granjaId))
        CompraAlimento.reconstruir(
          id: f['id']! as String,
          granjaId: granjaId,
          loteId: f['lote_id']! as String,
          fecha: DateTime.parse(f['fecha']! as String),
          tipo: TipoAlimento.values.byName(f['tipo']! as String),
          marca: f['marca']! as String,
          kilosPorBulto: (f['kilos_por_bulto']! as num).toDouble(),
          bultos: f['bultos']! as int,
          precioPorBulto: f['precio_por_bulto']! as int,
          creadoPor: f['creado_por'] as String?,
          creadoEn: _fechaHora(f['creado_en']),
        ),
      for (final f in await _local.filas('mortalidad', granjaId: granjaId))
        Mortalidad.reconstruir(
          id: f['id']! as String,
          granjaId: granjaId,
          loteId: f['lote_id']! as String,
          fecha: DateTime.parse(f['fecha']! as String),
          cantidad: f['cantidad']! as int,
          causa: switch (f['causa']) {
            final String causa => CausaMuerte.values.byName(causa),
            _ => null,
          },
          nota: f['nota'] as String?,
          creadoPor: f['creado_por'] as String?,
          creadoEn: _fechaHora(f['creado_en']),
        ),
      for (final f in await _local.filas('medicamentos', granjaId: granjaId))
        Medicamento.reconstruir(
          id: f['id']! as String,
          granjaId: granjaId,
          loteId: f['lote_id']! as String,
          fecha: DateTime.parse(f['fecha']! as String),
          nombre: f['nombre']! as String,
          costo: f['costo']! as int,
          nota: f['nota'] as String?,
          creadoPor: f['creado_por'] as String?,
          creadoEn: _fechaHora(f['creado_en']),
        ),
    ];
    final nunca = DateTime.utc(2000);
    registros.sort((a, b) {
      final porFecha = b.fecha.compareTo(a.fecha);
      return porFecha != 0
          ? porFecha
          : (b.creadoEn ?? nunca).compareTo(a.creadoEn ?? nunca);
    });
    return registros;
  }

  String _tabla(Registro registro) => switch (registro) {
        CompraAlimento() => 'compras_alimento',
        Mortalidad() => 'mortalidad',
        Medicamento() => 'medicamentos',
      };

  String _titulo(Registro registro) {
    final dia = fechaCorta(registro.fecha);
    return switch (registro) {
      CompraAlimento(:final bultos, :final tipo) =>
        '$bultos ${bultos == 1 ? 'bulto' : 'bultos'} de ${tipo.name} del $dia',
      Mortalidad(:final cantidad) =>
        '$cantidad ${cantidad == 1 ? 'muerto' : 'muertos'} del $dia',
      Medicamento(:final nombre) => '$nombre del $dia',
    };
  }

  DateTime? _fechaHora(Object? texto) =>
      texto is String ? DateTime.tryParse(texto) : null;
}
