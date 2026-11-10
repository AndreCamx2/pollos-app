import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// Estas columnas las llena el servidor; el celular nunca las manda.
const columnasDeAutoria = [
  'creado_por',
  'creado_en',
  'actualizado_por',
  'actualizado_en',
];

/// Las tablas que se sincronizan y sus columnas, con los mismos nombres que en
/// Supabase. Van los padres antes que los hijos y la primera columna es el id.
const columnasLocales = {
  'galpones': [
    'id',
    'granja_id',
    'nombre',
    'capacidad',
    'largo_m',
    'ancho_m',
    'ubicacion',
    ...columnasDeAutoria,
  ],
  'lotes': [
    'id',
    'granja_id',
    'galpon_id',
    'fecha_llegada',
    'cantidad_inicial',
    'precio_compra_total',
    'cerrado_en',
    ...columnasDeAutoria,
  ],
};

enum Operacion { guardar, borrar }

/// Un cambio hecho en el celular que todavía no está en el servidor.
/// [error] trae el motivo cuando el servidor lo rechazó. [cambio] sube cada
/// vez que la persona vuelve a tocar la misma fila.
typedef Pendiente = ({
  int orden,
  int cambio,
  String tabla,
  String filaId,
  Operacion operacion,
  String titulo,
  String? error,
});

/// La copia de los datos que vive en el celular, con la cola de lo que falta
/// por subir. Todo lo que la app lee y escribe pasa por aquí, haya señal o no.
class BaseLocal {
  BaseLocal(this._db);

  final Database _db;

  static Future<BaseLocal> abrir() async => BaseLocal(
        await openDatabase('pollos.db', version: 1, onCreate: crearTablas),
      );

  static Future<void> crearTablas(Database db, int version) async {
    for (final MapEntry(key: tabla, value: columnas) in columnasLocales.entries) {
      await db.execute(
        'create table $tabla (id text primary key, ${columnas.skip(1).join(', ')})',
      );
    }
    // Una sola fila por registro: si se toca dos veces antes de subir, se
    // manda una vez con lo último.
    await db.execute('''
      create table pendientes (
        orden integer primary key autoincrement,
        granja_id text not null,
        tabla text not null,
        fila_id text not null,
        operacion text not null,
        titulo text not null,
        cambio integer not null default 0,
        error text,
        unique (tabla, fila_id)
      )''');
    await db.execute(
      'create table datos_guardados (clave text primary key, valor text not null)',
    );
  }

  Future<void> cerrar() => _db.close();

  Future<List<Map<String, Object?>>> filas(
    String tabla, {
    required String granjaId,
    String? orden,
  }) =>
      _db.query(tabla, where: 'granja_id = ?', whereArgs: [granjaId], orderBy: orden);

  Future<Map<String, Object?>?> fila(String tabla, String id) async {
    final encontradas = await _db.query(tabla, where: 'id = ?', whereArgs: [id]);
    return encontradas.firstOrNull;
  }

  /// Guarda la fila en el celular y la deja en la cola para subirla.
  /// [titulo] es como se le nombra a la persona si el servidor la rechaza.
  Future<void> guardarFila(
    String tabla,
    Map<String, Object?> fila, {
    required String titulo,
    required String? autor,
  }) =>
      _db.transaction((tx) async {
        final id = fila['id']! as String;
        final cambiadas =
            await tx.update(tabla, fila, where: 'id = ?', whereArgs: [id]);
        if (cambiadas == 0) {
          await tx.insert(tabla, {
            ...fila,
            'creado_por': autor,
            'creado_en': DateTime.now().toUtc().toIso8601String(),
          });
        }
        // Si ya estaba en la cola conserva su turno: un lote nuevo debe subir
        // después de su galpón aunque el galpón se haya corregido luego.
        await tx.rawInsert(
          'insert or ignore into pendientes (granja_id, tabla, fila_id, operacion, titulo) '
          "values (?, ?, ?, 'guardar', ?)",
          [fila['granja_id'], tabla, id, titulo],
        );
        await tx.rawUpdate(
          "update pendientes set operacion = 'guardar', titulo = ?, error = null, "
          'cambio = cambio + 1 where tabla = ? and fila_id = ?',
          [titulo, tabla, id],
        );
      });

  /// Borra la fila del celular y deja el borrado al final de la cola, para
  /// que suba después de los borrados de lo que dependía de ella.
  Future<void> borrarFila(
    String tabla,
    String id, {
    required String granjaId,
    required String titulo,
  }) =>
      _db.transaction((tx) async {
        await tx.delete(tabla, where: 'id = ?', whereArgs: [id]);
        await tx.delete(
          'pendientes',
          where: 'tabla = ? and fila_id = ?',
          whereArgs: [tabla, id],
        );
        await tx.insert('pendientes', {
          'granja_id': granjaId,
          'tabla': tabla,
          'fila_id': id,
          'operacion': Operacion.borrar.name,
          'titulo': titulo,
        });
      });

  /// Lo que falta por subir, en el orden en que se hizo. Con [rechazados],
  /// lo que el servidor no aceptó.
  Future<List<Pendiente>> pendientes(
    String granjaId, {
    bool rechazados = false,
  }) async {
    final filas = await _db.query(
      'pendientes',
      where: 'granja_id = ? and error is ${rechazados ? 'not null' : 'null'}',
      whereArgs: [granjaId],
      orderBy: 'orden',
    );
    return [
      for (final f in filas)
        (
          orden: f['orden']! as int,
          cambio: f['cambio']! as int,
          tabla: f['tabla']! as String,
          filaId: f['fila_id']! as String,
          operacion: Operacion.values.byName(f['operacion']! as String),
          titulo: f['titulo']! as String,
          error: f['error'] as String?,
        ),
    ];
  }

  Future<({int porSubir, int rechazados})> cuentaPendientes(String granjaId) async {
    final cuenta = await _db.rawQuery(
      'select count(*) - count(error) as por_subir, count(error) as rechazados '
      'from pendientes where granja_id = ?',
      [granjaId],
    );
    return (
      porSubir: cuenta.first['por_subir']! as int,
      rechazados: cuenta.first['rechazados']! as int,
    );
  }

  // Estas dos no hacen nada si la persona volvió a tocar la fila mientras
  // subía: ese cambio nuevo todavía tiene que subir.
  Future<void> quitarPendiente(Pendiente pendiente) => _db.delete(
        'pendientes',
        where: 'orden = ? and cambio = ?',
        whereArgs: [pendiente.orden, pendiente.cambio],
      );

  Future<void> rechazar(Pendiente pendiente, String motivo) => _db.update(
        'pendientes',
        {'error': motivo},
        where: 'orden = ? and cambio = ?',
        whereArgs: [pendiente.orden, pendiente.cambio],
      );

  Future<void> reintentar(Pendiente pendiente) => _db.update(
        'pendientes',
        {'error': null},
        where: 'orden = ?',
        whereArgs: [pendiente.orden],
      );

  /// Saca el cambio de la cola y deja la fila como está en el servidor
  /// ([enServidor] null si allá no existe).
  Future<void> descartar(Pendiente pendiente, Map<String, dynamic>? enServidor) =>
      _db.transaction((tx) async {
        await tx.delete('pendientes', where: 'orden = ?', whereArgs: [pendiente.orden]);
        if (enServidor == null) {
          await tx.delete(
            pendiente.tabla,
            where: 'id = ?',
            whereArgs: [pendiente.filaId],
          );
        } else {
          await _reemplazar(tx, pendiente.tabla, enServidor);
        }
      });

  /// Aplica lo que llegó del servidor, sin pisar lo que está en la cola.
  Future<void> recibir(
    String tabla, {
    required List<Map<String, dynamic>> cambiadas,
    required List<String> borradas,
  }) =>
      _db.transaction((tx) async {
        final enCola = {
          for (final p in await tx.query(
            'pendientes',
            columns: ['fila_id'],
            where: 'tabla = ?',
            whereArgs: [tabla],
          ))
            p['fila_id'],
        };
        for (final fila in cambiadas) {
          if (!enCola.contains(fila['id'])) await _reemplazar(tx, tabla, fila);
        }
        for (final id in borradas) {
          if (!enCola.contains(id)) {
            await tx.delete(tabla, where: 'id = ?', whereArgs: [id]);
          }
        }
      });

  // Solo las columnas conocidas: si el servidor estrena una columna, las
  // apps que no se han actualizado siguen funcionando.
  Future<void> _reemplazar(
    Transaction tx,
    String tabla,
    Map<String, dynamic> fila,
  ) =>
      tx.insert(
        tabla,
        {for (final columna in columnasLocales[tabla]!) columna: fila[columna]},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  /// Datos sueltos que deben sobrevivir al cerrar la app: hasta dónde se ha
  /// bajado, el nombre y las granjas de quien entró.
  Future<Object?> leerDato(String clave) async {
    final filas = await _db.query(
      'datos_guardados',
      where: 'clave = ?',
      whereArgs: [clave],
    );
    return filas.isEmpty ? null : jsonDecode(filas.first['valor']! as String);
  }

  Future<void> guardarDato(String clave, Object valor) => _db.insert(
        'datos_guardados',
        {'clave': clave, 'valor': jsonEncode(valor)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
