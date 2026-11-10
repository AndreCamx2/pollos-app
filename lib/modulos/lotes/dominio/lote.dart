// DOMINIO: las reglas del negocio, en Dart puro.
// Aquí no se importa Flutter, Supabase ni nada externo. Si mañana cambiamos
// de base de datos o de pantallas, este archivo no se toca.

/// En qué alimento debería estar el lote según los días que lleva.
enum EtapaAlimento {
  /// Del día 0 al 21: bulto de inicio.
  inicio,

  /// Del día 22 al 25: es momento de pasar a engorde.
  cambio,

  /// Del día 26 en adelante: bulto de engorde hasta la venta.
  engorde,
}

/// Error cuando un dato del lote rompe una regla del negocio.
class LoteInvalido implements Exception {
  const LoteInvalido(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'LoteInvalido: $mensaje';
}

/// Un lote es un grupo de pollos que llegó el mismo día a un galpón.
class Lote {
  /// Arma un lote con datos que ya estaban guardados (por ejemplo, al leerlo
  /// de la base de datos). No valida, porque esos datos ya se validaron
  /// cuando el lote se creó con [Lote.nuevo].
  Lote.reconstruir({
    required this.id,
    required this.galpon,
    required DateTime fechaLlegada,
    required this.cantidadInicial,
    required this.precioCompraTotal,
  }) : fechaLlegada = _soloFecha(fechaLlegada);

  /// Crea un lote nuevo revisando las reglas del negocio.
  ///
  /// [hoy] se recibe como dato en vez de leer el reloj aquí adentro. Así las
  /// pruebas pueden decir "hoy es 10 de octubre" y el resultado siempre es
  /// el mismo.
  factory Lote.nuevo({
    required String id,
    required String galpon,
    required DateTime fechaLlegada,
    required int cantidadInicial,
    required int precioCompraTotal,
    required DateTime hoy,
  }) {
    final nombre = galpon.trim();
    if (nombre.isEmpty) {
      throw const LoteInvalido('El galpón necesita un nombre.');
    }
    if (cantidadInicial <= 0) {
      throw const LoteInvalido('La cantidad de pollos debe ser mayor que cero.');
    }
    if (precioCompraTotal < 0) {
      throw const LoteInvalido('El precio de compra no puede ser negativo.');
    }
    if (_soloFecha(fechaLlegada).isAfter(_soloFecha(hoy))) {
      throw const LoteInvalido('La fecha de llegada no puede ser en el futuro.');
    }
    return Lote.reconstruir(
      id: id,
      galpon: nombre,
      fechaLlegada: fechaLlegada,
      cantidadInicial: cantidadInicial,
      precioCompraTotal: precioCompraTotal,
    );
  }

  final String id;

  /// Nombre del galpón donde vive el lote, por ejemplo "Galpón 1".
  final String galpon;

  /// Día en que llegaron los pollos (sin hora).
  final DateTime fechaLlegada;

  /// Cuántos pollos llegaron.
  final int cantidadInicial;

  /// Lo que costaron todos los pollos del lote, en pesos.
  /// La plata se guarda en enteros (pesos completos), nunca con decimales,
  /// para evitar errores de redondeo.
  final int precioCompraTotal;

  /// Días que lleva el lote desde que llegó. El día de llegada es el día 0.
  int diasDeEdad(DateTime hoy) =>
      _soloFecha(hoy).difference(fechaLlegada).inDays;

  /// En qué alimento debería estar el lote [hoy].
  EtapaAlimento etapaAlimento(DateTime hoy) {
    final dias = diasDeEdad(hoy);
    if (dias < 22) return EtapaAlimento.inicio;
    if (dias <= 25) return EtapaAlimento.cambio;
    return EtapaAlimento.engorde;
  }

  /// Pollos que siguen vivos en el galpón.
  int vivos({required int muertos, required int vendidos}) {
    if (muertos < 0 || vendidos < 0) {
      throw const LoteInvalido('Los muertos y vendidos no pueden ser negativos.');
    }
    final quedan = cantidadInicial - muertos - vendidos;
    if (quedan < 0) {
      throw const LoteInvalido(
        'Hay más pollos muertos y vendidos que los que llegaron.',
      );
    }
    return quedan;
  }

  /// El lote se cierra cuando ya no quedan pollos vivos.
  bool estaCerrado({required int muertos, required int vendidos}) =>
      vivos(muertos: muertos, vendidos: vendidos) == 0;

  // Dos lotes son el mismo si tienen el mismo id.
  @override
  bool operator ==(Object other) => other is Lote && other.id == id;

  @override
  int get hashCode => id.hashCode;

  // Quita la hora y usa UTC, para que contar días no falle por horas o
  // cambios de horario.
  static DateTime _soloFecha(DateTime fecha) =>
      DateTime.utc(fecha.year, fecha.month, fecha.day);
}
