import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/compartido/local/base_local.dart';
import 'package:pollos_app/compartido/sincronizacion/remoto.dart';
import 'package:pollos_app/compartido/sincronizacion/sincronizador.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const granja = 'granja-1';

/// Un servidor de mentira: guarda en memoria, pone autor y fechas como lo
/// hace Supabase y se le puede quitar la señal.
class RemotoDePrueba implements Remoto {
  final tablas = <String, Map<String, Map<String, dynamic>>>{
    'galpones': {},
    'lotes': {},
  };
  final _borrados = <Map<String, dynamic>>[];
  var _reloj = DateTime.utc(2026, 10, 10, 8);

  var sinSenal = false;
  var guardadas = 0;

  /// Guarda la próxima fila pero corta la respuesta, como cuando la señal
  /// se cae justo después de enviar.
  var cortarDespuesDeGuardar = false;

  /// Motivo con el que se rechaza la fila que tenga este id.
  final rechazos = <String, PostgrestException>{};

  String _ahora() {
    _reloj = _reloj.add(const Duration(seconds: 1));
    return _reloj.toIso8601String();
  }

  void _revisarSenal() {
    if (sinSenal) throw const SocketException('Failed host lookup');
  }

  /// Lo que hace otra persona de la granja desde su celular.
  void otroGuarda(String tabla, Map<String, Object?> fila) {
    final anterior = tablas[tabla]![fila['id']];
    final ahora = _ahora();
    tablas[tabla]![fila['id']! as String] = {
      ...fila,
      'creado_por': anterior?['creado_por'] ?? 'beto',
      'creado_en': anterior?['creado_en'] ?? ahora,
      'actualizado_por': anterior == null ? null : 'beto',
      'actualizado_en': anterior == null ? null : ahora,
      'cambiado_en': ahora,
    };
  }

  void otroBorra(String tabla, String id) {
    tablas[tabla]!.remove(id);
    _borrados.add({'tabla': tabla, 'fila_id': id, 'granja_id': granja, 'borrado_en': _ahora()});
  }

  @override
  Future<void> guardar(String tabla, Map<String, Object?> fila) async {
    _revisarSenal();
    final rechazo = rechazos[fila['id']];
    if (rechazo != null) throw rechazo;
    otroGuarda(tabla, fila);
    guardadas++;
    if (cortarDespuesDeGuardar) {
      cortarDespuesDeGuardar = false;
      throw const SocketException('Connection reset');
    }
  }

  @override
  Future<void> borrar(String tabla, String id) async {
    _revisarSenal();
    otroBorra(tabla, id);
  }

  @override
  Future<Map<String, dynamic>?> buscar(String tabla, String id) async {
    _revisarSenal();
    return tablas[tabla]![id];
  }

  @override
  Future<List<Map<String, dynamic>>> cambios(
    String tabla,
    String granjaId,
    DateTime? desde,
  ) async {
    _revisarSenal();
    return _despuesDe(tablas[tabla]!.values, 'cambiado_en', granjaId, desde);
  }

  @override
  Future<List<Map<String, dynamic>>> borrados(String granjaId, DateTime? desde) async {
    _revisarSenal();
    return _despuesDe(_borrados, 'borrado_en', granjaId, desde);
  }

  List<Map<String, dynamic>> _despuesDe(
    Iterable<Map<String, dynamic>> filas,
    String columna,
    String granjaId,
    DateTime? desde,
  ) =>
      [
        for (final fila in filas)
          if (fila['granja_id'] == granjaId &&
              (desde == null ||
                  DateTime.parse(fila[columna] as String).isAfter(desde)))
            fila,
      ];
}

Map<String, Object?> galpon(String id, String nombre, {int? capacidad}) => {
      'id': id,
      'granja_id': granja,
      'nombre': nombre,
      'capacidad': capacidad,
      'largo_m': null,
      'ancho_m': null,
      'ubicacion': null,
    };

void main() {
  late BaseLocal local;
  late RemotoDePrueba remoto;
  late Sincronizador sincronizador;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    local = BaseLocal(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: BaseLocal.crearTablas,
          singleInstance: false,
        ),
      ),
    );
    remoto = RemotoDePrueba();
    sincronizador = Sincronizador(local, remoto);
  });

  tearDown(() => local.cerrar());

  Future<void> guardarGalpon(String id, String nombre, {int? capacidad}) =>
      local.guardarFila(
        'galpones',
        galpon(id, nombre, capacidad: capacidad),
        titulo: nombre,
        autor: 'ana',
      );

  Future<String?> nombreLocal(String id) async =>
      (await local.fila('galpones', id))?['nombre'] as String?;

  test('lo que se guarda sin señal espera en la cola y sube cuando vuelve', () async {
    remoto.sinSenal = true;
    await guardarGalpon('g4', 'Galpón 4', capacidad: 600);

    await expectLater(
      sincronizador.sincronizar(granja),
      throwsA(isA<SocketException>()),
    );
    expect((await local.cuentaPendientes(granja)).porSubir, 1);
    expect(await nombreLocal('g4'), 'Galpón 4');

    remoto.sinSenal = false;
    await sincronizador.sincronizar(granja);

    expect(remoto.tablas['galpones']!['g4']!['capacidad'], 600);
    expect((await local.cuentaPendientes(granja)).porSubir, 0);
  });

  test('si la señal se cae justo después de enviar, al reintentar no se duplica', () async {
    await guardarGalpon('g4', 'Galpón 4');
    remoto.cortarDespuesDeGuardar = true;

    await expectLater(
      sincronizador.sincronizar(granja),
      throwsA(isA<SocketException>()),
    );
    await sincronizador.sincronizar(granja);

    expect(remoto.tablas['galpones'], hasLength(1));
    expect((await local.cuentaPendientes(granja)).porSubir, 0);
  });

  test('tocar dos veces la misma fila antes de subir manda solo lo último', () async {
    await guardarGalpon('g4', 'Galpon 4');
    await guardarGalpon('g4', 'Galpón 4');

    await sincronizador.sincronizar(granja);

    expect(remoto.guardadas, 1);
    expect(remoto.tablas['galpones']!['g4']!['nombre'], 'Galpón 4');
  });

  test('lo que el servidor rechaza queda marcado con el motivo y lo demás sube', () async {
    await guardarGalpon('g4', 'Galpón 4');
    await guardarGalpon('g5', 'Galpón 5');
    remoto.rechazos['g4'] = PostgrestException(
      message: 'duplicate key value violates unique constraint "galpones_nombre_unico"',
      code: '23505',
    );

    await sincronizador.sincronizar(granja);

    final rechazados = await local.pendientes(granja, rechazados: true);
    expect(rechazados.single.titulo, 'Galpón 4');
    expect(rechazados.single.error, 'Ya existe uno con ese nombre.');
    expect(remoto.tablas['galpones']!.keys, ['g5']);
    expect((await local.cuentaPendientes(granja)).porSubir, 0);
  });

  test('corregir una fila rechazada la vuelve a poner en la cola', () async {
    await guardarGalpon('g4', 'Galpón 1');
    remoto.rechazos['g4'] = PostgrestException(message: 'duplicate', code: '23505');
    await sincronizador.sincronizar(granja);

    remoto.rechazos.clear();
    await guardarGalpon('g4', 'Galpón 4');
    await sincronizador.sincronizar(granja);

    expect(await local.pendientes(granja, rechazados: true), isEmpty);
    expect(remoto.tablas['galpones']!['g4']!['nombre'], 'Galpón 4');
  });

  test('descartar un cambio rechazado deja la fila como está en el servidor', () async {
    remoto.otroGuarda('galpones', galpon('g1', 'Galpón 1'));
    await sincronizador.sincronizar(granja);
    await guardarGalpon('g1', 'Galpón 2');
    remoto.rechazos['g1'] = PostgrestException(message: 'duplicate', code: '23505');
    await sincronizador.sincronizar(granja);

    final rechazado = (await local.pendientes(granja, rechazados: true)).single;
    await sincronizador.descartar(rechazado);

    expect(await nombreLocal('g1'), 'Galpón 1');
    expect(await local.pendientes(granja, rechazados: true), isEmpty);
  });

  test('descartar algo que nunca llegó al servidor lo quita del celular', () async {
    await guardarGalpon('g4', 'Galpón 1');
    remoto.rechazos['g4'] = PostgrestException(message: 'duplicate', code: '23505');
    await sincronizador.sincronizar(granja);

    await sincronizador.descartar((await local.pendientes(granja, rechazados: true)).single);

    expect(await local.fila('galpones', 'g4'), isNull);
  });

  test('baja lo que otra persona creó, corrigió y borró', () async {
    remoto.otroGuarda('galpones', galpon('g1', 'Galpón 1'));
    remoto.otroGuarda('galpones', galpon('g2', 'Galpón 2'));
    await sincronizador.sincronizar(granja);
    expect(await local.filas('galpones', granjaId: granja), hasLength(2));

    remoto.otroGuarda('galpones', galpon('g1', 'Galpón grande'));
    remoto.otroBorra('galpones', 'g2');
    await sincronizador.sincronizar(granja);

    expect(await nombreLocal('g1'), 'Galpón grande');
    expect(await local.fila('galpones', 'g2'), isNull);
  });

  test('lo que baja no pisa un cambio del celular que todavía no ha subido', () async {
    remoto.otroGuarda('galpones', galpon('g1', 'Galpón 1'));
    await sincronizador.sincronizar(granja);
    await guardarGalpon('g1', 'Galpón de atrás');
    remoto.rechazos['g1'] = PostgrestException(message: 'duplicate', code: '23505');
    remoto.otroGuarda('galpones', galpon('g1', 'Galpón uno'));

    await sincronizador.sincronizar(granja);

    expect(await nombreLocal('g1'), 'Galpón de atrás');
  });

  test('borrar sin señal sube el borrado después', () async {
    remoto.otroGuarda('galpones', galpon('g1', 'Galpón 1'));
    await sincronizador.sincronizar(granja);
    remoto.sinSenal = true;

    await local.borrarFila('galpones', 'g1', granjaId: granja, titulo: 'Galpón 1');
    expect(await local.fila('galpones', 'g1'), isNull);

    remoto.sinSenal = false;
    await sincronizador.sincronizar(granja);

    expect(remoto.tablas['galpones'], isEmpty);
    expect(await local.fila('galpones', 'g1'), isNull);
  });

  test('al subir, el autor y las fechas los pone el servidor', () async {
    await guardarGalpon('g4', 'Galpón 4');
    expect((await local.fila('galpones', 'g4'))!['creado_por'], 'ana');

    await sincronizador.sincronizar(granja);

    expect((await local.fila('galpones', 'g4'))!['creado_por'], 'beto');
  });

  test('una sesión vencida no cuenta como rechazo: la fila sigue en la cola', () async {
    await guardarGalpon('g4', 'Galpón 4');
    remoto.rechazos['g4'] = PostgrestException(message: 'JWT expired', code: 'PGRST301');

    await expectLater(
      sincronizador.sincronizar(granja),
      throwsA(isA<PostgrestException>()),
    );

    expect((await local.cuentaPendientes(granja)).porSubir, 1);
  });

  test('lo guardado en el celular sobrevive entre una lectura y otra', () async {
    await local.guardarDato('granjas:ana', [
      {'id': granja, 'nombre': 'Granja La Esperanza', 'rol': 'dueno'},
    ]);

    final guardado = await local.leerDato('granjas:ana') as List;

    expect(guardado.single['nombre'], 'Granja La Esperanza');
    expect(await local.leerDato('nombre:ana'), isNull);
  });
}
