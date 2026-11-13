// DOMINIO: los clientes, lo que abonan y cuánto deben, en Dart puro.

import '../../../compartido/cifras.dart';
import '../../../compartido/fechas.dart';
import '../../../compartido/formato.dart';

/// Error cuando un dato del cliente o del abono rompe una regla del negocio.
class ClienteInvalido implements Exception {
  const ClienteInvalido(this.mensaje, {this.campo});

  final String mensaje;

  /// El campo del formulario donde está el error, para señalarlo ahí.
  final String? campo;

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
    this.cupoFiado,
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
    int? cupoFiado,
  }) {
    final limpio = _sinVacio(nombre);
    if (limpio == null) {
      throw const ClienteInvalido('Escribe el nombre del cliente.', campo: 'nombre');
    }
    if (precioLibraSugerido != null && precioLibraSugerido <= 0) {
      throw const ClienteInvalido('El precio por libra debe ser mayor que cero.', campo: 'precio');
    }
    if (precioLibraSugerido != null && precioLibraSugerido > Topes.precioLibra) {
      throw const ClienteInvalido(
        'Más de \$100.000 la libra no parece correcto. Revisa la cifra.',
        campo: 'precio',
      );
    }
    if (cupoFiado != null && cupoFiado <= 0) {
      throw const ClienteInvalido(
        'El cupo debe ser mayor que cero. Déjalo vacío si no le pones tope.',
        campo: 'cupo',
      );
    }
    if (cupoFiado != null && cupoFiado > Topes.plata) {
      throw const ClienteInvalido('Ese cupo es demasiado alto. Revisa la cifra.', campo: 'cupo');
    }
    final digitos = telefono?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digitos.isNotEmpty && (digitos.length != 10 || !digitos.startsWith('3'))) {
      throw const ClienteInvalido(
        'El celular debe tener 10 números y empezar por 3.',
        campo: 'telefono',
      );
    }
    return Cliente.reconstruir(
      id: id,
      granjaId: granjaId,
      nombre: limpio,
      detalle: _sinVacio(detalle),
      telefono: digitos.isEmpty
          ? null
          : '${digitos.substring(0, 3)} ${digitos.substring(3, 6)} ${digitos.substring(6)}',
      precioLibraSugerido: precioLibraSugerido,
      recurrente: recurrente,
      cupoFiado: cupoFiado,
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

  /// Hasta cuánto se le fía; null es sin tope. Pasarlo solo da un aviso.
  final int? cupoFiado;
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
    DateTime? primeraVentaFiada,
    required DateTime hoy,
  }) {
    if (valor <= 0) {
      throw const ClienteInvalido('Escribe cuánto pagó.', campo: 'valor');
    }
    if (soloFecha(fecha).isAfter(soloFecha(hoy))) {
      throw const ClienteInvalido('La fecha no puede ser en el futuro.', campo: 'fecha');
    }
    if (primeraVentaFiada != null && soloFecha(fecha).isBefore(soloFecha(primeraVentaFiada))) {
      throw ClienteInvalido(
        'La primera venta fiada a ${cliente.nombre} fue el ${fechaCorta(primeraVentaFiada)}: '
        'el abono no puede ser de antes.',
        campo: 'fecha',
      );
    }
    if (valor > debeSinEste) {
      throw ClienteInvalido(
        debeSinEste <= 0
            ? '${cliente.nombre} no debe nada.'
            : '${cliente.nombre} solo debe ${plata(debeSinEste)}. Revisa el valor.',
        campo: 'valor',
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
    this.primeraFiada,
  });

  final Cliente cliente;
  final int totalFiado;
  final List<Abono> abonos;

  /// Cuántas ventas tiene, fiadas o de contado.
  final int ventas;
  final int? ultimoPrecio;

  /// La fecha de su primera venta fiada: ningún abono puede ser de antes.
  final DateTime? primeraFiada;

  int get abonado => abonos.fold(0, (suma, abono) => suma + abono.valor);

  int get debe => totalFiado - abonado;

  bool get alDia => debe <= 0;

  /// El precio que se le sugiere en la próxima venta.
  int? get precioSugerido => ultimoPrecio ?? cliente.precioLibraSugerido;

  /// Un cliente con ventas o abonos no se borra: se perderían sus cuentas.
  bool get sePuedeBorrar => ventas == 0 && abonos.isEmpty;

  /// En cuánto se pasaría del cupo si quedara debiendo [debeDespues]; null
  /// si no tiene cupo o no lo pasa.
  int? pasaDelCupo(int debeDespues) {
    final cupo = cliente.cupoFiado;
    return cupo == null || debeDespues <= cupo ? null : debeDespues - cupo;
  }

  /// Para escribirle por WhatsApp; null si no tiene celular. Si debe, el
  /// mensaje ya lleva el saldo y solo falta enviarlo.
  Uri? enlaceWhatsApp({required String granja}) {
    final celular = cliente.telefono?.replaceAll(' ', '');
    if (celular == null) return null;
    return Uri.https(
      'wa.me',
      '/57$celular',
      alDia
          ? null
          : {
              'text': 'Hola ${cliente.nombre}, le escribo de $granja. '
                  'Tiene un saldo pendiente de ${plata(debe)}.',
            },
    );
  }

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
