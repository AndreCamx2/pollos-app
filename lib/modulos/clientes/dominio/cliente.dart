// DOMINIO: los clientes, lo que abonan y cuánto deben, en Dart puro.

import '../../../compartido/fechas.dart';
import '../../../compartido/formato.dart';

/// Error cuando un dato del cliente o del abono rompe una regla del negocio.
class ClienteInvalido implements Exception {
  const ClienteInvalido(this.mensaje);

  final String mensaje;

  @override
  String toString() => 'ClienteInvalido: $mensaje';
}

String? _sinVacio(String? texto) {
  final limpio = texto?.trim() ?? '';
  return limpio.isEmpty ? null : limpio;
}

class Cliente {
  const Cliente.reconstruir({
    required this.id,
    required this.granjaId,
    required this.nombre,
    this.detalle,
    this.telefono,
    this.precioLibraSugerido,
    this.recurrente = true,
    this.creadoPor,
  });

  /// Crea un cliente, o lo corrige si [id] ya existe, revisando las reglas.
  factory Cliente.nuevo({
    required String id,
    required String granjaId,
    required String nombre,
    String? detalle,
    String? telefono,
    int? precioLibraSugerido,
    bool recurrente = true,
  }) {
    final limpio = _sinVacio(nombre);
    if (limpio == null) {
      throw const ClienteInvalido('Escribe el nombre del cliente.');
    }
    if (precioLibraSugerido != null && precioLibraSugerido <= 0) {
      throw const ClienteInvalido('El precio por libra debe ser mayor que cero.');
    }
    return Cliente.reconstruir(
      id: id,
      granjaId: granjaId,
      nombre: limpio,
      detalle: _sinVacio(detalle),
      telefono: _sinVacio(telefono),
      precioLibraSugerido: precioLibraSugerido,
      recurrente: recurrente,
    );
  }

  final String id;
  final String granjaId;
  final String nombre;

  /// El negocio o cómo se le reconoce, por ejemplo "Tienda La Esquina".
  final String? detalle;
  final String? telefono;

  /// El precio de la primera venta; después se sugiere el de la última.
  final int? precioLibraSugerido;

  /// Los que compraron una vez y no se espera que vuelvan van al final de
  /// las listas.
  final bool recurrente;
  final String? creadoPor;

  bool puedeCambiarlo({required bool administra, required String? usuarioId}) =>
      administra || (usuarioId != null && creadoPor == usuarioId);

  @override
  bool operator ==(Object other) => other is Cliente && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Plata que un cliente pagó de lo que debía.
class Abono {
  Abono.reconstruir({
    required this.id,
    required this.granjaId,
    required this.clienteId,
    required DateTime fecha,
    required this.valor,
    this.recibidoPor,
    this.creadoPor,
    this.creadoEn,
  }) : fecha = soloFecha(fecha);

  /// [debeSinEste] es lo que debe el cliente sin contar este abono, para que
  /// al corregirlo no se cuente dos veces.
  factory Abono.nuevo({
    required String id,
    required Cliente cliente,
    required DateTime fecha,
    required int valor,
    String? recibidoPor,
    required int debeSinEste,
    required DateTime hoy,
  }) {
    if (valor <= 0) {
      throw const ClienteInvalido('Escribe cuánto pagó.');
    }
    if (soloFecha(fecha).isAfter(soloFecha(hoy))) {
      throw const ClienteInvalido('La fecha no puede ser en el futuro.');
    }
    if (valor > debeSinEste) {
      throw ClienteInvalido(
        debeSinEste <= 0
            ? '${cliente.nombre} no debe nada.'
            : '${cliente.nombre} solo debe ${plata(debeSinEste)}. Revisa el valor.',
      );
    }
    return Abono.reconstruir(
      id: id,
      granjaId: cliente.granjaId,
      clienteId: cliente.id,
      fecha: fecha,
      valor: valor,
      recibidoPor: recibidoPor,
    );
  }

  final String id;
  final String granjaId;
  final String clienteId;
  final DateTime fecha;
  final int valor;

  /// Quién de la granja recibió la plata.
  final String? recibidoPor;
  final String? creadoPor;
  final DateTime? creadoEn;

  bool puedeCambiarlo({required bool administra, required String? usuarioId}) =>
      administra || (usuarioId != null && creadoPor == usuarioId);
}

/// Lo que se le ha vendido y abonado a un cliente. [ultimoPrecio] es el
/// precio de la libra en la venta más reciente.
class CuentaCliente {
  CuentaCliente({
    required this.cliente,
    required this.totalFiado,
    required this.abonos,
    required this.ventas,
    this.ultimoPrecio,
  });

  final Cliente cliente;
  final int totalFiado;
  final List<Abono> abonos;

  /// Cuántas ventas tiene, fiadas o de contado.
  final int ventas;
  final int? ultimoPrecio;

  int get abonado => abonos.fold(0, (suma, abono) => suma + abono.valor);

  int get debe => totalFiado - abonado;

  bool get alDia => debe <= 0;

  /// El precio que se le sugiere en la próxima venta.
  int? get precioSugerido => ultimoPrecio ?? cliente.precioLibraSugerido;

  /// Un cliente con ventas o abonos no se borra: se perderían sus cuentas.
  bool get sePuedeBorrar => ventas == 0 && abonos.isEmpty;

  /// Lo que debe sin contar [abono], para corregirlo sin contarlo dos veces.
  int debeSin(Abono? abono) => debe + (abono?.valor ?? 0);
}

/// Primero los recurrentes, los que más deben arriba y luego por nombre.
int ordenDeClientes(CuentaCliente a, CuentaCliente b) {
  if (a.cliente.recurrente != b.cliente.recurrente) {
    return a.cliente.recurrente ? -1 : 1;
  }
  final porDeuda = b.debe.compareTo(a.debe);
  return porDeuda != 0
      ? porDeuda
      : a.cliente.nombre.toLowerCase().compareTo(b.cliente.nombre.toLowerCase());
}

/// Revisa que con un cambio el cliente no quede con abonos de más.
void revisarQueNoQuedeAFavor(Cliente cliente, int debeDespues) {
  if (debeDespues < 0) {
    throw ClienteInvalido(
      'Con este cambio los abonos de ${cliente.nombre} superan lo que compró '
      'fiado por ${plata(-debeDespues)}.',
    );
  }
}
