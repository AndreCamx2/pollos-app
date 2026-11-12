import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/lotes/adaptadores/memoria/repositorio_lotes_memoria.dart';
import 'package:pollos_app/modulos/lotes/aplicacion/crear_lote.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';

void main() {
  late RepositorioLotesMemoria repositorio;
  late CrearLote crearLote;
  var creados = 0;

  setUp(() {
    creados = 0;
    repositorio = RepositorioLotesMemoria();
    crearLote = CrearLote(
      repositorio: repositorio,
      generarId: () => 'lote-${++creados}',
      reloj: () => DateTime(2026, 10, 10),
    );
  });

  Future<Lote> llegan500({String galponId = 'galpon-1'}) => crearLote(
        granjaId: 'granja-1',
        galponId: galponId,
        fechaLlegada: DateTime(2026, 9, 17),
        cantidadInicial: 500,
        precioCompraTotal: 1750000,
      );

  test('crea el lote y lo guarda', () async {
    final lote = await llegan500();

    expect(lote.id, 'lote-1');
    expect(await repositorio.buscarPorId('lote-1'), lote);
  });

  test('si un dato es inválido no guarda nada', () async {
    await expectLater(
      crearLote(
        granjaId: 'granja-1',
        galponId: 'galpon-1',
        fechaLlegada: DateTime(2026, 9, 17),
        cantidadInicial: 0,
        precioCompraTotal: 1750000,
      ),
      throwsA(isA<LoteInvalido>()),
    );
    expect(await repositorio.listar('granja-1'), isEmpty);
  });

  test('no recibe pollitos en un galpón que todavía tiene un lote abierto', () async {
    await llegan500();

    await expectLater(llegan500(), throwsA(isA<LoteInvalido>()));
    expect(await repositorio.listar('granja-1'), hasLength(1));
  });

  test('con el lote anterior cerrado, el galpón recibe otro', () async {
    final anterior = await llegan500();
    await repositorio.guardar(anterior.cerrar(DateTime(2026, 10, 10)));

    final nuevo = await llegan500();

    expect((await repositorio.abiertoEn('galpon-1'))?.id, nuevo.id);
  });

  test('cada galpón lleva su propio lote', () async {
    await llegan500();
    await llegan500(galponId: 'galpon-2');

    expect(await repositorio.listar('granja-1'), hasLength(2));
  });
}
