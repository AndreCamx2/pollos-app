// DOMINIO: lo que se anota en un lote día a día, en Dart puro.

import '../../../compartido/cifras.dart';
import '../../../compartido/fechas.dart';
import '../../../compartido/formato.dart';
import '../../clientes/dominio/cliente.dart';
import '../../lotes/dominio/lote.dart';
import 'marca.dart';

enum TipoAlimento {
  inicio('Inicio'),
  engorde('Engorde');

  const TipoAlimento(this.etiqueta);

  final String etiqueta;
}

/// Los nombres coinciden con los valores de la columna mortalidad.causa.
enum CausaMuerte {
  calor('Calor'),
  enfermedad('Enfermedad'),
  aplastamiento('Aplastamiento'),
  otra('Otra');

  const CausaMuerte(this.etiqueta);

  final String etiqueta;
}

/// Error cuando un dato del registro rompe una regla del negocio.
class RegistroInvalido implements Exception {
  const RegistroInvalido(this.mensaje, {this.campo});

  final String mensaje;

  /// El campo del formulario donde está el error, para señalarlo ahí.
  final String? campo;

  @override
  String toString() => 'RegistroInvalido: $mensaje';
}

/// Algo que se anotó en un lote: una compra de alimento, unos muertos, una
/// medicina o una venta. Cada clase tiene un constructor `nueva` que revisa las reglas
/// (también sirve para corregir uno que ya existe, con su mismo id) y uno
/// `reconstruir` para lo que ya estaba guardado.
sealed class Registro {
  Registro({
    required this.id,
    required this.granjaId,
    required this.loteId,
    required DateTime fecha,
    this.creadoPor,
    this.creadoEn,
  }) : fecha = soloFecha(fecha);

  final String id;
  final String granjaId;
  final String loteId;
  final DateTime fecha;

  /// Quién lo anotó; null mientras no se ha guardado.
  final String? creadoPor;
  final DateTime? creadoEn;

  /// El dueño y el administrador cambian cualquier registro; el trabajador,
  /// solo los que anotó él.
  bool puedeCambiarlo({required bool administra, required String? usuarioId}) =>
      administra || (usuarioId != null && creadoPor == usuarioId);
}

void _revisarLoteYFecha(Lote lote, DateTime fecha, DateTime hoy) {
  if (!lote.abierto) {
    throw const RegistroInvalido(
      'Este lote ya está cerrado. Reábrelo para registrar cambios.',
    );
  }
  if (soloFecha(fecha).isBefore(lote.fechaLlegada)) {
    throw RegistroInvalido(
      'La fecha no puede ser anterior a la llegada del lote (${fechaCorta(lote.fechaLlegada)}).',
      campo: 'fecha',
    );
  }
  if (soloFecha(fecha).isAfter(soloFecha(hoy))) {
    throw const RegistroInvalido('La fecha no puede ser en el futuro.', campo: 'fecha');
  }
}

String? _sinVacio(String? texto) {
  final limpio = texto?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

final class CompraAlimento extends Registro {
  CompraAlimento.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.tipo,
    required this.marca,
    this.marcaId,
    required this.kilosPorBulto,
    required this.bultos,
    required this.precioPorBulto,
    super.creadoPor,
    super.creadoEn,
  });

  factory CompraAlimento.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required TipoAlimento tipo,
    required Marca? marca,
    required double kilosPorBulto,
    required int bultos,
    required int precioPorBulto,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    if (marca == null) {
      throw const RegistroInvalido('Elige la marca del alimento.', campo: 'marca');
    }
    if (bultos <= 0) {
      throw const RegistroInvalido('Los bultos deben ser más de cero.', campo: 'bultos');
    }
    if (bultos > Topes.bultos) {
      throw const RegistroInvalido(
        'Más de 1.000 bultos en una compra no parece correcto. Revisa la cifra.',
        campo: 'bultos',
      );
    }
    if (kilosPorBulto <= 0 || kilosPorBulto > Topes.kilosPorBulto) {
      throw const RegistroInvalido(
        'Los kilos por bulto deben estar entre 1 y 100.',
        campo: 'kilos',
      );
    }
    if (precioPorBulto < 0) {
      throw const RegistroInvalido('El precio no puede ser negativo.', campo: 'precio');
    }
    if (precioPorBulto > Topes.precioBulto) {
      throw const RegistroInvalido(
        'Más de \$2.000.000 por bulto no parece correcto. Revisa la cifra.',
        campo: 'precio',
      );
    }
    return CompraAlimento.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      tipo: tipo,
      marca: marca.nombre,
      marcaId: marca.id,
      kilosPorBulto: kilosPorBulto,
      bultos: bultos,
      precioPorBulto: precioPorBulto,
    );
  }

  final TipoAlimento tipo;

  /// El nombre que tenía la marca al comprarse. Para mostrarla se busca por
  /// [marcaId], que trae el nombre corregido si se cambió después.
  final String marca;

  /// Null en compras anotadas antes de que existiera la lista de marcas.
  final String? marcaId;
  final double kilosPorBulto;
  final int bultos;

  /// En pesos enteros, como toda la plata de la app.
  final int precioPorBulto;

  int get total => bultos * precioPorBulto;

  double get kilos => bultos * kilosPorBulto;
}

final class Mortalidad extends Registro {
  Mortalidad.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.cantidad,
    this.causa,
    this.nota,
    super.creadoPor,
    super.creadoEn,
  });

  /// [vivosSinEste] son los vivos del lote contando todo menos este registro,
  /// para que al corregirlo no se cuente dos veces.
  factory Mortalidad.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required int cantidad,
    CausaMuerte? causa,
    String? nota,
    required int vivosSinEste,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    if (cantidad <= 0) {
      throw const RegistroInvalido('Escribe cuántos se murieron.', campo: 'cantidad');
    }
    if (cantidad > vivosSinEste) {
      throw RegistroInvalido(
        'Solo quedan $vivosSinEste pollos vivos en este lote.',
        campo: 'cantidad',
      );
    }
    return Mortalidad.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      cantidad: cantidad,
      causa: causa,
      nota: _sinVacio(nota),
    );
  }

  final int cantidad;
  final CausaMuerte? causa;
  final String? nota;
}

final class Medicamento extends Registro {
  Medicamento.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.nombre,
    required this.costo,
    this.nota,
    super.creadoPor,
    super.creadoEn,
  });

  factory Medicamento.nueva({
    required String id,
    required Lote lote,
    required DateTime fecha,
    required String nombre,
    required int costo,
    String? nota,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    final limpio = _sinVacio(nombre);
    if (limpio == null) {
      throw const RegistroInvalido('Escribe qué medicina se compró.', campo: 'nombre');
    }
    if (costo < 0) {
      throw const RegistroInvalido('El costo no puede ser negativo.', campo: 'costo');
    }
    if (costo > Topes.plata) {
      throw const RegistroInvalido('Ese costo es demasiado alto. Revisa la cifra.', campo: 'costo');
    }
    return Medicamento.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      nombre: limpio,
      costo: costo,
      nota: _sinVacio(nota),
    );
  }

  final String nombre;
  final int costo;

  /// Para qué es o cómo se da.
  final String? nota;
}

/// Libras por precio, redondeado al peso como lo calcula la base de datos.
/// Las libras se cuentan en centésimas para no arrastrar errores de decimales.
int totalVenta(double libras, int precioLibra) =>
    ((libras * 100).round() * precioLibra + 50) ~/ 100;

final class Venta extends Registro {
  Venta.reconstruir({
    required super.id,
    required super.granjaId,
    required super.loteId,
    required super.fecha,
    required this.clienteId,
    required this.pollos,
    required this.libras,
    required this.precioLibra,
    required this.fiado,
    super.creadoPor,
    super.creadoEn,
  });

  /// [vivosSinEsta] son los vivos del lote sin contar esta venta y
  /// [debeSinEsta] lo que debe el cliente sin contarla, para que al
  /// corregirla no se cuente dos veces.
  factory Venta.nueva({
    required String id,
    required Lote lote,
    required Cliente cliente,
    required DateTime fecha,
    required int pollos,
    required double libras,
    required int precioLibra,
    required bool fiado,
    required int vivosSinEsta,
    required int debeSinEsta,
    required DateTime hoy,
  }) {
    _revisarLoteYFecha(lote, fecha, hoy);
    if (pollos <= 0) {
      throw const RegistroInvalido('Escribe cuántos pollos se vendieron.', campo: 'pollos');
    }
    if (pollos > vivosSinEsta) {
      throw RegistroInvalido(
        'Solo quedan $vivosSinEsta pollos vivos en este lote.',
        campo: 'pollos',
      );
    }
    if (libras <= 0) {
      throw const RegistroInvalido('Escribe cuántas libras pesaron.', campo: 'libras');
    }
    if (libras > Topes.libras) {
      throw const RegistroInvalido(
        'Más de 99.999 libras en una venta no parece correcto. Revisa la cifra.',
        campo: 'libras',
      );
    }
    if (precioLibra <= 0) {
      throw const RegistroInvalido('Escribe el precio de la libra.', campo: 'precio');
    }
    if (precioLibra > Topes.precioLibra) {
      throw const RegistroInvalido(
        'Más de \$100.000 la libra no parece correcto. Revisa la cifra.',
        campo: 'precio',
      );
    }
    final venta = Venta.reconstruir(
      id: id,
      granjaId: lote.granjaId,
      loteId: lote.id,
      fecha: fecha,
      clienteId: cliente.id,
      pollos: pollos,
      libras: (libras * 100).round() / 100,
      precioLibra: precioLibra,
      fiado: fiado,
    );
    try {
      revisarQueNoQuedeAFavor(cliente, debeSinEsta + venta.fiadoPorCobrar);
    } on ClienteInvalido catch (e) {
      throw RegistroInvalido(e.mensaje);
    }
    return venta;
  }

  final String clienteId;
  final int pollos;

  /// Con dos decimales como mucho, como las guarda la base de datos.
  final double libras;
  final int precioLibra;
  final bool fiado;

  int get total => totalVenta(libras, precioLibra);

  /// Lo que esta venta le suma a la deuda del cliente.
  int get fiadoPorCobrar => fiado ? total : 0;

  double get librasPorPollo => libras / pollos;

  /// Menos de 2 o más de 8 libras por pollo casi siempre es un error al anotar.
  bool get pesoRaro => librasPorPollo < 2 || librasPorPollo > 8;
}
