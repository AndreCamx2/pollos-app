// DOMINIO: cómo le fue a la granja en sus lotes cerrados, en Dart puro.

import '../../../compartido/formato.dart';
import '../../registros/dominio/cuentas_lote.dart';
import '../../registros/dominio/registro.dart';

enum Periodo { anio, seisMeses, todo }

/// Si el lote se cerró dentro del periodo, contado hacia atrás desde [hoy].
bool cerradoEn(CuentasLote cuentas, Periodo periodo, DateTime hoy) {
  final cierre = cuentas.lote.cerradoEn?.toLocal();
  if (cierre == null) return false;
  return switch (periodo) {
    Periodo.anio => cierre.year == hoy.year,
    Periodo.seisMeses => cierre.isAfter(DateTime(hoy.year, hoy.month - 6, hoy.day)),
    Periodo.todo => true,
  };
}

class ResumenPeriodo {
  ResumenPeriodo(this.lotes);

  final List<CuentasLote> lotes;

  int get ganancia => lotes.fold(0, (suma, c) => suma + c.ganancia);
  int get ventas => lotes.fold(0, (suma, c) => suma + c.ventas);
  int get llegaron => lotes.fold(0, (suma, c) => suma + c.lote.cantidadInicial);
  int get vendidos => lotes.fold(0, (suma, c) => suma + c.vendidos);
  int get muertos => lotes.fold(0, (suma, c) => suma + c.muertos);

  /// Ganancia sobre lo vendido, de 0 a 100; null si no se vendió nada.
  double? get margen => ventas == 0 ? null : ganancia * 100 / ventas;

  double? get mortalidad => llegaron == 0 ? null : muertos * 100 / llegaron;

  /// El que más ganó; null si no hay lotes.
  CuentasLote? get mejor => lotes.isEmpty
      ? null
      : lotes.reduce((a, b) => b.ganancia > a.ganancia ? b : a);

  int get conPerdida => lotes.where((c) => c.ganancia < 0).length;

  /// Si [cuentas] es el lote con más margen entre los del periodo, con al
  /// menos otro para comparar.
  bool esElMejor(CuentasLote cuentas) {
    if (lotes.length < 2 || cuentas.margen == null) return false;
    return lotes.every((c) => c.lote.id == cuentas.lote.id || (c.margen ?? -999) <= cuentas.margen!);
  }
}

/// El resumen del lote en texto, para mandarlo por WhatsApp o donde sea.
/// [clientes] trae los nombres de los clientes por id.
String textoParaCompartir(
  CuentasLote cuentas, {
  required String galpon,
  required Map<String, String> clientes,
  required DateTime hoy,
}) {
  final lote = cuentas.lote;
  final cierre = lote.cerradoEn?.toLocal();
  final dias = cuentas.dias(hoy);
  final ganancia = cuentas.ganancia;
  final margen = cuentas.margen;
  final lineas = [
    'Mis pollos · $galpon',
    cierre == null
        ? 'Lote que llegó el ${fechaCorta(lote.fechaLlegada)}, va en el día $dias'
        : 'Lote del ${fechaCorta(lote.fechaLlegada)} al ${fechaCorta(cierre)} ($dias días)',
    '',
    if (cierre == null)
      ganancia >= 0 ? 'Va ganando: ${plata(ganancia)}' : 'Falta recuperar: ${plata(-ganancia)}'
    else
      ganancia >= 0 ? 'Ganancia: ${plata(ganancia)}' : 'Pérdida: ${plata(-ganancia)}',
    if (margen != null) '${decimal(margen)} % de lo vendido',
    'Vendido: ${plata(cuentas.ventas)} · Invertido: ${plata(cuentas.invertido)}',
    '',
    'Pollos: ${miles(lote.cantidadInicial)} llegaron, ${miles(cuentas.vendidos)} vendidos, '
        '${miles(cuentas.muertos)} muertos (${decimal(cuentas.mortalidad)} %)'
        '${cuentas.faltantes > 0 ? ', ${miles(cuentas.faltantes)} faltantes' : ''}',
    if (cuentas.pesoPromedio case final peso?) 'Peso promedio: ${decimal(peso)} lb por pollo',
    if (cuentas.precioPromedioLibra case final precio?)
      'Precio promedio: ${plata(precio.round())} la libra',
    if (cuentas.conversion case final conversion?)
      'Conversión: ${dosDecimales(conversion)} kg de alimento por kg de pollo',
    if (cuentas.ventasPorCliente.isNotEmpty) ...[
      '',
      'A quién se le vendió:',
      for (final venta in cuentas.ventasPorCliente)
        '- ${clientes[venta.clienteId] ?? 'Cliente'}: ${miles(venta.pollos)} pollos, ${plata(venta.total)}',
    ],
    '',
    'Hecho con Mis pollos',
  ];
  return lineas.join('\n');
}

/// "Calor 8", "Sin causa 3"...
String nombreDeCausa(CausaMuerte? causa) => causa?.etiqueta ?? 'Sin causa';
