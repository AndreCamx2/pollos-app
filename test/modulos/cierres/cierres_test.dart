import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/cierres/dominio/cierres.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';
import 'package:pollos_app/modulos/registros/dominio/cuentas_lote.dart';
import 'package:pollos_app/modulos/registros/dominio/registro.dart';

void main() {
  final hoy = DateTime(2026, 11, 12);

  CuentasLote loteCerrado(String id, DateTime cierre, {required int vendidoEn, int muertos = 0}) {
    final lote = Lote.reconstruir(
      id: id,
      granjaId: 'granja-1',
      galponId: 'galpon-1',
      fechaLlegada: cierre.subtract(const Duration(days: 45)),
      cantidadInicial: 500,
      precioCompraTotal: 1000000,
      cerradoEn: cierre,
    );
    return CuentasLote(lote, [
      Venta.reconstruir(
        id: '$id-v',
        granjaId: 'granja-1',
        loteId: id,
        fecha: cierre,
        clienteId: 'jaime',
        pollos: 500 - muertos,
        libras: 100,
        precioLibra: vendidoEn ~/ 100,
        fiado: false,
      ),
      if (muertos > 0)
        Mortalidad.reconstruir(
          id: '$id-m',
          granjaId: 'granja-1',
          loteId: id,
          fecha: cierre,
          cantidad: muertos,
        ),
    ]);
  }

  final octubre = loteCerrado('oct', DateTime(2026, 10, 7), vendidoEn: 3000000, muertos: 15);
  final marzo = loteCerrado('mar', DateTime(2026, 3, 1), vendidoEn: 800000, muertos: 46);
  final pasado = loteCerrado('2025', DateTime(2025, 11, 26), vendidoEn: 2000000);

  test('el año cuenta solo los lotes cerrados este año', () {
    expect([for (final c in [octubre, marzo, pasado]) cerradoEn(c, Periodo.anio, hoy)], [true, true, false]);
  });

  test('los últimos 6 meses dejan por fuera el lote de marzo', () {
    expect(cerradoEn(marzo, Periodo.seisMeses, hoy), isFalse);
    expect(cerradoEn(octubre, Periodo.seisMeses, hoy), isTrue);
  });

  test('un lote abierto no entra en ningún periodo', () {
    final abierto = CuentasLote(
      Lote.reconstruir(
        id: 'abierto',
        granjaId: 'granja-1',
        galponId: 'galpon-1',
        fechaLlegada: DateTime(2026, 11, 1),
        cantidadInicial: 500,
        precioCompraTotal: 1000000,
      ),
      const [],
    );
    expect(cerradoEn(abierto, Periodo.todo, hoy), isFalse);
  });

  test('el resumen suma ganancia, ventas y mortalidad de los lotes', () {
    final resumen = ResumenPeriodo([octubre, marzo]);
    expect(resumen.ganancia, 2000000 - 200000);
    expect(resumen.ventas, 3800000);
    expect(resumen.mortalidad, closeTo(6.1, 0.01));
    expect(resumen.conPerdida, 1);
    expect(resumen.mejor?.lote.id, 'oct');
    expect(resumen.esElMejor(octubre), isTrue);
    expect(resumen.esElMejor(marzo), isFalse);
  });

  test('con un solo lote no hay "mejor lote" que mostrar', () {
    expect(ResumenPeriodo([octubre]).esElMejor(octubre), isFalse);
  });

  test('el texto para compartir dice cuánto se ganó y a quién se le vendió', () {
    final texto = textoParaCompartir(
      octubre,
      galpon: 'Galpón 4',
      clientes: {'jaime': 'Don Jaime'},
      hoy: hoy,
    );
    expect(texto, contains('Mis pollos · Galpón 4'));
    expect(texto, contains(r'Ganancia: $2.000.000'));
    expect(texto, contains('15 muertos (3 %)'));
    expect(texto, contains(r'- Don Jaime: 485 pollos, $3.000.000'));
    expect(texto.split('\n').last, 'Hecho con Mis pollos');
  });
}
