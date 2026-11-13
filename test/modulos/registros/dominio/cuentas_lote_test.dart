import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';
import 'package:pollos_app/modulos/registros/dominio/cuentas_lote.dart';
import 'package:pollos_app/modulos/registros/dominio/registro.dart';

void main() {
  final lote = Lote.reconstruir(
    id: 'lote-4',
    granjaId: 'granja-1',
    galponId: 'galpon-4',
    fechaLlegada: DateTime(2026, 8, 23),
    cantidadInicial: 500,
    precioCompraTotal: 1750000,
    cerradoEn: DateTime.utc(2026, 10, 7, 18),
  );

  var siguiente = 0;
  String id() => 'r${siguiente++}';

  Mortalidad muertos(int cantidad, CausaMuerte? causa) => Mortalidad.reconstruir(
        id: id(),
        granjaId: 'granja-1',
        loteId: lote.id,
        fecha: DateTime(2026, 9, 10),
        cantidad: cantidad,
        causa: causa,
      );

  CompraAlimento compra(TipoAlimento tipo, int bultos, int precio, DateTime fecha) =>
      CompraAlimento.reconstruir(
        id: id(),
        granjaId: 'granja-1',
        loteId: lote.id,
        fecha: fecha,
        tipo: tipo,
        marca: 'Solla',
        kilosPorBulto: 40,
        bultos: bultos,
        precioPorBulto: precio,
      );

  Venta venta(String cliente, int pollos, double libras, int precio, DateTime fecha) =>
      Venta.reconstruir(
        id: id(),
        granjaId: 'granja-1',
        loteId: lote.id,
        fecha: fecha,
        clienteId: cliente,
        pollos: pollos,
        libras: libras,
        precioLibra: precio,
        fiado: false,
      );

  // El lote del Galpón 4 del diseño: 500 pollitos, 20 bultos de inicio,
  // 40 de engorde, $120.000 de medicina y 485 pollos vendidos.
  final cuentas = CuentasLote(lote, [
    muertos(8, CausaMuerte.calor),
    muertos(4, CausaMuerte.enfermedad),
    muertos(3, CausaMuerte.aplastamiento),
    compra(TipoAlimento.inicio, 20, 98000, DateTime(2026, 8, 23)),
    compra(TipoAlimento.engorde, 40, 104000, DateTime(2026, 9, 14)),
    Medicamento.reconstruir(
      id: id(),
      granjaId: 'granja-1',
      loteId: lote.id,
      fecha: DateTime(2026, 9, 1),
      nombre: 'Vitaminas',
      costo: 120000,
    ),
    venta('pedro', 132, 662.5, 5800, DateTime(2026, 9, 30)),
    venta('jaime', 220, 1100, 5600, DateTime(2026, 9, 26)),
    venta('marta', 133, 662.5, 5400, DateTime(2026, 10, 7)),
  ]);

  test('invertido, vendido y ganancia del lote', () {
    expect(cuentas.invertido, 1750000 + 1960000 + 4160000 + 120000);
    expect(cuentas.ventas, 3842500 + 6160000 + 3577500);
    expect(cuentas.ganancia, cuentas.ventas - cuentas.invertido);
    expect(cuentas.margen, closeTo(41.2, 0.1));
  });

  test('mortalidad, peso promedio y conversión', () {
    expect(cuentas.muertos, 15);
    expect(cuentas.mortalidad, closeTo(3.0, 0.01));
    expect(cuentas.vendidos, 485);
    expect(cuentas.vivos, 0);
    expect(cuentas.pesoPromedio, closeTo(5.0, 0.01));
    expect(cuentas.kilosAlimento, 2400);
    expect(cuentas.conversion, closeTo(2.18, 0.01));
  });

  test('costo y ganancia por pollo', () {
    expect(cuentas.costoPorPollo, 16474);
    expect(cuentas.gananciaPorPollo, 11526);
    expect(cuentas.precioPromedioLibra, closeTo(5600, 1));
  });

  test('las causas de muerte, la primera venta y el paso a engorde', () {
    expect(cuentas.causas[CausaMuerte.calor], 8);
    expect(cuentas.causas[CausaMuerte.aplastamiento], 3);
    expect(cuentas.primeraVenta?.clienteId, 'jaime');
    expect(cuentas.primerEngorde, DateTime.utc(2026, 9, 14));
    expect(cuentas.dias(DateTime(2026, 12, 1)), 45);
  });

  test('a quién se le vendió, el que más compró primero', () {
    expect([for (final c in cuentas.ventasPorCliente) c.clienteId], ['jaime', 'pedro', 'marta']);
    expect(cuentas.ventasPorCliente.first.pollos, 220);
  });

  test('los faltantes sacan pollos del galpón pero no cuentan como mortalidad', () {
    final conFaltantes = CuentasLote(lote, [muertos(10, CausaMuerte.calor), muertos(12, CausaMuerte.faltante)]);
    expect(conFaltantes.muertos, 10);
    expect(conFaltantes.faltantes, 12);
    expect(conFaltantes.vivos, 478);
    expect(conFaltantes.mortalidad, closeTo(2.0, 0.01));
    expect(conFaltantes.causas.containsKey(CausaMuerte.faltante), isFalse);
  });

  test('sin ventas no hay margen ni indicadores por pollo', () {
    final vacio = CuentasLote(lote, const []);
    expect(vacio.margen, isNull);
    expect(vacio.costoPorPollo, isNull);
    expect(vacio.conversion, isNull);
  });
}
