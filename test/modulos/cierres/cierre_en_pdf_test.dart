import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/cierres/adaptadores/pdf/cierre_en_pdf.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';
import 'package:pollos_app/modulos/registros/dominio/cuentas_lote.dart';
import 'package:pollos_app/modulos/registros/dominio/registro.dart';

void main() {
  final cierre = DateTime(2026, 11, 1);
  final lote = Lote.reconstruir(
    id: 'lote-1',
    granjaId: 'granja-1',
    galponId: 'galpon-1',
    fechaLlegada: DateTime(2026, 9, 17),
    cantidadInicial: 500,
    precioCompraTotal: 1750000,
    cerradoEn: cierre,
  );

  test('el cierre sale como un PDF, con ventas y sin ellas', () async {
    final conVentas = CuentasLote(lote, [
      Venta.reconstruir(
        id: 'v1',
        granjaId: 'granja-1',
        loteId: 'lote-1',
        fecha: cierre,
        clienteId: 'jaime',
        pollos: 480,
        libras: 2496.5,
        precioLibra: 5600,
        fiado: false,
      ),
      Mortalidad.reconstruir(
        id: 'm1',
        granjaId: 'granja-1',
        loteId: 'lote-1',
        fecha: cierre,
        cantidad: 20,
        causa: CausaMuerte.calor,
      ),
    ]);
    for (final cuentas in [conVentas, CuentasLote(lote, const [])]) {
      final pdf = await cierreEnPdf(
        cuentas,
        granja: 'Granja La Esperanza',
        galpon: 'Galpón 1',
        clientes: const {'jaime': 'Don Jaime Hernández Ospina'},
        hoy: DateTime(2026, 11, 14),
      );
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
    }
  });

  test('el archivo lleva el galpón y la fecha, sin signos raros', () {
    expect(nombreDelPdf('Galpón 1 / atrás', DateTime(2026, 11, 1)), 'Cierre Galpón 1  atrás 1 nov 2026.pdf');
  });
}
