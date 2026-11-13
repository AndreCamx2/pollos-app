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
  'clientes': [
    'id',
    'granja_id',
    'nombre',
    'detalle',
    'telefono',
    'precio_libra_sugerido',
    'recurrente',
    'cupo_fiado',
    ...columnasDeAutoria,
  ],
  'marcas': [
    'id',
    'granja_id',
    'nombre',
    'kilos_por_bulto',
    'en_uso',
    ...columnasDeAutoria,
  ],
  'compras_alimento': [
    'id',
    'granja_id',
    'lote_id',
    'fecha',
    'tipo',
    'marca',
    'marca_id',
    'kilos_por_bulto',
    'bultos',
    'precio_por_bulto',
    ...columnasDeAutoria,
  ],
  'mortalidad': [
    'id',
    'granja_id',
    'lote_id',
    'fecha',
    'cantidad',
    'causa',
    'nota',
    ...columnasDeAutoria,
  ],
  'medicamentos': [
    'id',
    'granja_id',
    'lote_id',
    'fecha',
    'nombre',
    'costo',
    'nota',
    ...columnasDeAutoria,
  ],
  'ventas': [
    'id',
    'granja_id',
    'lote_id',
    'cliente_id',
    'fecha',
    'pollos',
    'libras',
    'precio_libra',
    'total',
    'fiado',
    ...columnasDeAutoria,
  ],
  'abonos': [
    'id',
    'granja_id',
    'cliente_id',
    'fecha',
    'valor',
    'recibido_por',
    ...columnasDeAutoria,
  ],
};

/// SQLite no tiene sí/no: en el celular estas columnas van como 1 y 0, y en
/// Supabase como true y false.
const columnasSiNo = {'fiado', 'recurrente', 'en_uso'};

/// Una fila del celular como la espera Supabase.
Map<String, Object?> filaParaServidor(Map<String, Object?> fila) => {
      for (final MapEntry(key: columna, value: valor) in fila.entries)
        columna: columnasSiNo.contains(columna) && valor is int ? valor == 1 : valor,
    };

/// Una fila de Supabase como la guarda el celular.
Map<String, Object?> filaParaCelular(Map<String, Object?> fila) => {
      for (final MapEntry(key: columna, value: valor) in fila.entries)
        columna: valor is bool ? (valor ? 1 : 0) : valor,
    };

enum Operacion { guardar, borrar }

/// Un cambio hecho en el celular que todavía no está en el servidor.
/// [datos] es la fila tal como quedó con ese cambio (null si es un borrado).
/// [error] trae el motivo cuando el servidor lo rechazó.
typedef Pendiente = ({
  int orden,
  int cambio,
  String tabla,
  String filaId,
  Operacion operacion,
  Map<String, Object?>? datos,
  String titulo,
  String? error,
});

/// La copia de los datos que vive en el celular, con la cola de lo que falta
/// por subir. Todo lo que la app lee y escribe pasa por aquí, haya señal o no.
class BaseLocal {
  BaseLocal(this._db);

  final Database _db;

  static Future<BaseLocal> abrir() async => BaseLocal(
        await openDatabase(
          'pollos.db',
          version: 5,
          onCreate: crearTablas,
          onUpgrade: actualizarTablas,
        ),
      );

  static Future<void> crearTablas(Database db, int version) async {
    for (final MapEntry(key: tabla, value: columnas) in columnasLocales.entries) {
      await db.execute(
        'create table if not exists $tabla '
        '(id text primary key, ${columnas.skip(1).join(', ')})',
      );
    }
    // La cola guarda cada cambio con la fila como quedó en ese momento y se
    // sube en el mismo orden en que se hizo.
    await db.execute('''
      create table if not exists pendientes (
        orden integer primary key autoincrement,
        granja_id text not null,
        tabla text not null,
        fila_id text not null,
        operacion text not null,
        datos text,
        titulo text not null,
        cambio integer not null default 0,
        error text
      )''');
    await db.execute(
      'create table if not exists datos_guardados '
      '(clave text primary key, valor text not null)',
    );
  }

  static Future<void> actualizarTablas(Database db, int anterior, int nueva) async {
    // La cola de la versión 1 no guardaba la fila de cada cambio. Solo
    // existió en celulares de prueba, así que se arma de nuevo.
    if (anterior < 2) await db.execute('drop table if exists pendientes');
    // En la versión 1 no existía la tabla de compras: la crea crearTablas.
    if (anterior >= 2 && anterior < 4) {
      // El servidor llenó marca_id en las compras viejas: se vuelven a bajar
      // todas para que el celular también lo tenga.
      await db.execute('alter table compras_alimento add column marca_id');
      await db.execute(
        "delete from datos_guardados where clave like 'bajado:%:compras_alimento'",
      );
    }
    await crearTablas(db, nueva);
    // El cupo de fiado llegó en la versión 5. Los clientes se vuelven a bajar
    // para traer el cupo que otro celular ya les haya puesto.
    if (anterior >= 2 && anterior < 5) {
      final columnas = await db.rawQuery('pragma table_info(clientes)');
      if (!columnas.any((columna) => columna['name'] == 'cupo_fiado')) {
        await db.execute('alter table clientes add column cupo_fiado');
      }
      await db.execute(
        "delete from datos_guardados where clave like 'bajado:%:clientes'",
      );
    }
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
        // Esta versión reemplaza lo que el servidor había rechazado de la fila.
        await tx.delete(
          'pendientes',
          where: 'tabla = ? and fila_id = ? and error is not null',
          whereArgs: [tabla, id],
        );
        final ultimo = (await tx.query(
          'pendientes',
          where: 'granja_id = ?',
          whereArgs: [fila['granja_id']],
          orderBy: 'orden desc',
          limit: 1,
        ))
            .firstOrNull;
        // Corregir lo último que se hizo no necesita otro envío. Si después
        // vino otra cosa, va al final: cerrar un lote tiene que subir después
        // de lo que se anotó en él.
        if (ultimo != null &&
            ultimo['tabla'] == tabla &&
            ultimo['fila_id'] == id &&
            ultimo['operacion'] == Operacion.guardar.name) {
          await tx.rawUpdate(
            'update pendientes set datos = ?, titulo = ?, cambio = cambio + 1 '
            'where orden = ?',
            [jsonEncode(fila), titulo, ultimo['orden']],
          );
        } else {
          await tx.insert('pendientes', {
            'granja_id': fila['granja_id'],
            'tabla': tabla,
            'fila_id': id,
            'operacion': Operacion.guardar.name,
            'datos': jsonEncode(fila),
            'titulo': titulo,
          });
        }
      });

  /// Borra la fila del celular y deja el borrado al final de la cola. Lo que
  /// faltaba por subir de esa fila ya no hace falta.
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
          datos: switch (f['datos']) {
            final String datos => jsonDecode(datos) as Map<String, Object?>,
            _ => null,
          },
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

  /// Saca de la cola todo lo de esa fila y la deja como está en el servidor
  /// ([enServidor] null si allá no existe).
  Future<void> descartar(Pendiente pendiente, Map<String, dynamic>? enServidor) =>
      _db.transaction((tx) async {
        await tx.delete(
          'pendientes',
          where: 'tabla = ? and fila_id = ?',
          whereArgs: [pendiente.tabla, pendiente.filaId],
        );
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
        filaParaCelular({
          for (final columna in columnasLocales[tabla]!) columna: fila[columna],
        }),
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
