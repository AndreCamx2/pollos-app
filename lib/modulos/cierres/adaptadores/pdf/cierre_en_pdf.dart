// ADAPTADOR: arma el cierre de un lote como una hoja en PDF, para mandarla
// por WhatsApp o imprimirla.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../compartido/formato.dart';
import '../../../registros/dominio/cuentas_lote.dart';
import '../../dominio/cierres.dart';

const _tinta = PdfColor.fromInt(0xFF2B211A);
const _tintaSuave = PdfColor.fromInt(0xFF6B5D52);
const _granero = PdfColor.fromInt(0xFFA3401F);
const _pasto = PdfColor.fromInt(0xFF2F6B3A);
const _maizClaro = PdfColor.fromInt(0xFFFCEBC2);
const _borde = PdfColor.fromInt(0xFFE5DDD0);

/// El nombre con que se guarda y se comparte el archivo.
String nombreDelPdf(String galpon, DateTime fecha) {
  final limpio = galpon.replaceAll(RegExp(r'[^\w áéíóúñÁÉÍÓÚÑ-]'), '').trim();
  return 'Cierre $limpio ${fecha.day} ${mesCorto(fecha)} ${fecha.year}.pdf';
}

/// [clientes] trae los nombres de los clientes por id.
Future<Uint8List> cierreEnPdf(
  CuentasLote cuentas, {
  required String granja,
  required String galpon,
  required Map<String, String> clientes,
  required DateTime hoy,
}) {
  final lote = cuentas.lote;
  final cierre = lote.cerradoEn?.toLocal();
  final dias = cuentas.dias(hoy);
  final ganancia = cuentas.ganancia;
  final margen = cuentas.margen;

  pw.TextStyle letra(double tamano, {bool negrita = false, PdfColor color = _tinta}) =>
      pw.TextStyle(
        fontSize: tamano,
        color: color,
        fontWeight: negrita ? pw.FontWeight.bold : pw.FontWeight.normal,
      );

  pw.Widget seccion(String titulo) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 18, bottom: 6),
        child: pw.Text(titulo.toUpperCase(), style: letra(9, negrita: true, color: _tintaSuave)),
      );

  pw.Widget fila(String nombre, String valor, {String? detalle, bool fuerte = false}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _borde, width: 0.5)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(nombre, style: letra(11, negrita: fuerte)),
                  if (detalle != null && detalle.isNotEmpty)
                    pw.Text(detalle, style: letra(9, color: _tintaSuave)),
                ],
              ),
            ),
            pw.Text(valor, style: letra(11, negrita: true)),
          ],
        ),
      );

  String bultos(int cuantos, double kilos) =>
      '${miles(cuantos)} ${cuantos == 1 ? 'bulto' : 'bultos'} · ${decimal(kilos)} kg';

  final documento = pw.Document(title: 'Cierre · $galpon', author: 'Mis pollos');
  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (contexto) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          'Hecho con Mis pollos · ${fechaCorta(hoy)} ${hoy.year}',
          style: letra(8, color: _tintaSuave),
        ),
      ),
      build: (contexto) => [
        pw.Text(granja, style: letra(10, negrita: true, color: _tintaSuave)),
        pw.Text(
          '${cierre == null ? 'Cómo va' : 'Cierre'} · $galpon',
          style: letra(22, negrita: true),
        ),
        pw.Text(
          cierre == null
              ? 'Lote que llegó el ${fechaCorta(lote.fechaLlegada)} ${lote.fechaLlegada.year}, '
                  'va en el día $dias'
              : 'Lote del ${fechaCorta(lote.fechaLlegada)} ${lote.fechaLlegada.year} '
                  'al ${fechaCorta(cierre)} ${cierre.year} · $dias días',
          style: letra(11, color: _tintaSuave),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: const pw.BoxDecoration(
            color: _maizClaro,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                switch ((cierre == null, ganancia >= 0)) {
                  (true, true) => 'Va ganando',
                  (true, false) => 'Falta recuperar',
                  (false, true) => 'Ganancia',
                  (false, false) => 'Pérdida',
                },
                style: letra(10, color: _tintaSuave),
              ),
              pw.Text(
                plata(ganancia.abs()),
                style: letra(26, negrita: true, color: ganancia >= 0 ? _pasto : _granero),
              ),
              pw.Text(
                [
                  if (margen != null) '${decimal(margen)} % de lo vendido',
                  'Vendido ${plata(cuentas.ventas)}',
                  'Invertido ${plata(cuentas.invertido)}',
                ].join(' · '),
                style: letra(10),
              ),
            ],
          ),
        ),
        seccion('Inversión'),
        fila('Pollitos · ${miles(lote.cantidadInicial)}', plata(lote.precioCompraTotal)),
        fila(
          'Alimento de inicio',
          plata(cuentas.alimentoInicio),
          detalle: bultos(cuentas.bultosInicio, cuentas.kilosInicio),
        ),
        fila(
          'Alimento de engorde',
          plata(cuentas.alimentoEngorde),
          detalle: bultos(cuentas.bultosEngorde, cuentas.kilosEngorde),
        ),
        fila(
          'Medicamentos',
          plata(cuentas.medicina),
          detalle: cuentas.medicinas == 1 ? '1 compra' : '${cuentas.medicinas} compras',
        ),
        fila('Total invertido', plata(cuentas.invertido), fuerte: true),
        seccion('Pollos'),
        fila('Llegaron', miles(lote.cantidadInicial)),
        fila('Vendidos', miles(cuentas.vendidos)),
        fila('Muertos', miles(cuentas.muertos), detalle: '${decimal(cuentas.mortalidad)} % de mortalidad'),
        if (cuentas.faltantes > 0) fila('Faltantes', miles(cuentas.faltantes)),
        if (cierre == null) fila('Vivos', miles(cuentas.vivos)),
        for (final MapEntry(key: causa, value: cuantos) in cuentas.causas.entries)
          fila('   ${nombreDeCausa(causa)}', miles(cuantos)),
        seccion('Indicadores'),
        if (cuentas.pesoPromedio case final peso?)
          fila(
            'Peso promedio',
            '${decimal(peso)} lb',
            detalle: '${decimal(cuentas.librasVendidas)} lb vendidas',
          ),
        if (cuentas.precioPromedioLibra case final precio?)
          fila('Precio promedio de la libra', plata(precio.round())),
        if (cuentas.conversion case final conversion?)
          fila(
            'Conversión',
            dosDecimales(conversion),
            detalle: 'kg de alimento por kg de pollo',
          ),
        if (cuentas.costoPorPollo case final costo?) fila('Costo de cada pollo', plata(costo)),
        if (cuentas.gananciaPorPollo case final porPollo?)
          fila(porPollo >= 0 ? 'Ganancia por pollo' : 'Pérdida por pollo', plata(porPollo.abs())),
        if (cuentas.ventasPorCliente.isNotEmpty) ...[
          seccion('A quién se le vendió'),
          for (final venta in cuentas.ventasPorCliente)
            fila(
              clientes[venta.clienteId] ?? 'Cliente',
              plata(venta.total),
              detalle: '${miles(venta.pollos)} pollos · ${decimal(venta.libras)} lb',
            ),
        ],
      ],
    ),
  );
  return documento.save();
}
