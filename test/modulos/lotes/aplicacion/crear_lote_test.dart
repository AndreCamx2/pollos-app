import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/lotes/adaptadores/memoria/repositorio_lotes_memoria.dart';
import 'package:pollos_app/modulos/lotes/aplicacion/crear_lote.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';

void main() {
  late RepositorioLotesMemoria repositorio;
  late CrearLote crearLote;

  setUp(() {
    repositorio = RepositorioLotesMemoria();
    crearLote = CrearLote(
      repositorio: repositorio,
      generarId: () => 'lote-1',
      reloj: () => DateTime(2026, 10, 10),
    );
  });

  test('crea el lote y lo guarda', () async {
    final lote = await crearLote(
      galpon: 'Galpón 1',
      fechaLlegada: DateTime(2026, 9, 17),
      cantidadInicial: 500,
      precioCompraTotal: 1750000,
    );

    expect(lote.id, 'lote-1');
    expect(await repositorio.buscarPorId('lote-1'), lote);
  });

  test('si un dato es inválido no guarda nada', () async {
    await expectLater(
      crearLote(
        galpon: 'Galpón 1',
        fechaLlegada: DateTime(2026, 9, 17),
        cantidadInicial: 0,
        precioCompraTotal: 1750000,
      ),
      throwsA(isA<LoteInvalido>()),
    );
    expect(await repositorio.listar(), isEmpty);
  });
}
