import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';
import 'package:pollos_app/modulos/lotes/dominio/recordatorios.dart';

void main() {
  final lote = Lote.reconstruir(
    id: 'lote-1',
    granjaId: 'granja-1',
    galponId: 'galpon-1',
    fechaLlegada: DateTime(2026, 9, 17),
    cantidadInicial: 500,
    precioCompraTotal: 1750000,
  );

  List<Recordatorio> recordatorios(DateTime ahora, {Lote? de, bool engorde = false}) =>
      recordatoriosDe(de ?? lote, galpon: 'Galpón 1', yaComproEngorde: engorde, ahora: ahora);

  test('un lote recién llegado avisa el día 22 y el día 45, a las 7', () {
    final avisos = recordatorios(DateTime(2026, 9, 18));
    expect([for (final a in avisos) a.cuando], [DateTime(2026, 10, 9, 7), DateTime(2026, 11, 1, 7)]);
    expect(avisos.first.titulo, 'Galpón 1: toca pasar a engorde');
    expect(avisos.last.titulo, 'Galpón 1: el lote ya está para vender');
  });

  test('si ya se compró engorde solo avisa la venta', () {
    final avisos = recordatorios(DateTime(2026, 9, 18), engorde: true);
    expect([for (final a in avisos) a.cuando], [DateTime(2026, 11, 1, 7)]);
  });

  test('no avisa lo que ya pasó', () {
    expect(recordatorios(DateTime(2026, 10, 9, 8)).single.cuando, DateTime(2026, 11, 1, 7));
    expect(recordatorios(DateTime(2026, 11, 2)), isEmpty);
  });

  test('un lote cerrado no avisa nada', () {
    expect(recordatorios(DateTime(2026, 9, 18), de: lote.cerrar(DateTime(2026, 9, 20))), isEmpty);
  });
}
