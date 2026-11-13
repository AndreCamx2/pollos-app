// ADAPTADOR: guarda los clientes y sus abonos en la base del celular. De ahí
// el sincronizador los sube cuando hay señal.

import '../../../../compartido/fechas.dart';
import '../../../../compartido/formato.dart';
import '../../../../compartido/local/base_local.dart';
import '../../dominio/cliente.dart';

class RepositorioClientesLocal {
  RepositorioClientesLocal(this._local, {required this.autor});

  final BaseLocal _local;

  /// Quien está usando la app; queda como autor de lo que anote.
  final String? autor;

  Future<void> guardarCliente(Cliente cliente) => _local.guardarFila(
        'clientes',
        {
          'id': cliente.id,
          'granja_id': cliente.granjaId,
          'nombre': cliente.nombre,
          'detalle': cliente.detalle,
          'telefono': cliente.telefono,
          'precio_libra_sugerido': cliente.precioLibraSugerido,
          'recurrente': cliente.recurrente ? 1 : 0,
          'cupo_fiado': cliente.cupoFiado,
        },
        titulo: cliente.nombre,
        autor: autor,
      );

  Future<void> borrarCliente(Cliente cliente) => _local.borrarFila(
        'clientes',
        cliente.id,
        granjaId: cliente.granjaId,
        titulo: cliente.nombre,
      );

  Future<List<Cliente>> clientes(String granjaId) async => [
        for (final f in await _local.filas('clientes', granjaId: granjaId))
          Cliente.reconstruir(
            id: f['id']! as String,
            granjaId: granjaId,
            nombre: f['nombre']! as String,
            detalle: f['detalle'] as String?,
            telefono: f['telefono'] as String?,
            precioLibraSugerido: f['precio_libra_sugerido'] as int?,
            // Null si se bajó antes de que el servidor tuviera la columna.
            recurrente: f['recurrente'] != 0,
            cupoFiado: f['cupo_fiado'] as int?,
            creadoPor: f['creado_por'] as String?,
          ),
      ];

  /// [nombreCliente] es como se le nombra a la persona si el servidor lo rechaza.
  Future<void> guardarAbono(Abono abono, {required String nombreCliente}) =>
      _local.guardarFila(
        'abonos',
        {
          'id': abono.id,
          'granja_id': abono.granjaId,
          'cliente_id': abono.clienteId,
          'fecha': fechaParaBase(abono.fecha),
          'valor': abono.valor,
          'recibido_por': abono.recibidoPor,
        },
        titulo: _titulo(abono, nombreCliente),
        autor: autor,
      );

  Future<void> borrarAbono(Abono abono, {required String nombreCliente}) =>
      _local.borrarFila(
        'abonos',
        abono.id,
        granjaId: abono.granjaId,
        titulo: _titulo(abono, nombreCliente),
      );

  /// Los abonos de la granja, el más reciente primero.
  Future<List<Abono>> abonos(String granjaId) async {
    final abonos = [
      for (final f in await _local.filas('abonos', granjaId: granjaId))
        Abono.reconstruir(
          id: f['id']! as String,
          granjaId: granjaId,
          clienteId: f['cliente_id']! as String,
          fecha: DateTime.parse(f['fecha']! as String),
          valor: f['valor']! as int,
          recibidoPor: f['recibido_por'] as String?,
          creadoPor: f['creado_por'] as String?,
          creadoEn: switch (f['creado_en']) {
            final String texto => DateTime.tryParse(texto),
            _ => null,
          },
        ),
    ];
    final nunca = DateTime.utc(2000);
    return abonos
      ..sort((a, b) {
        final porFecha = b.fecha.compareTo(a.fecha);
        return porFecha != 0
            ? porFecha
            : (b.creadoEn ?? nunca).compareTo(a.creadoEn ?? nunca);
      });
  }

  String _titulo(Abono abono, String nombreCliente) =>
      'Abono de ${plata(abono.valor)} de $nombreCliente del ${fechaCorta(abono.fecha)}';
}
