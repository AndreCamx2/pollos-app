import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/clientes/dominio/cliente.dart';

void main() {
  final hoy = DateTime(2026, 10, 10);
  const marta = Cliente.reconstruir(
    id: 'marta',
    granjaId: 'granja-1',
    nombre: 'Doña Marta',
    detalle: 'Tienda La Esquina',
  );

  Abono abono(int valor, {int debe = 539800}) => Abono.nuevo(
        id: 'a1',
        cliente: marta,
        fecha: hoy,
        valor: valor,
        recibidoPor: 'ana',
        debeSinEste: debe,
        hoy: hoy,
      );

  CuentaCliente cuenta(
    Cliente cliente, {
    int fiado = 0,
    List<Abono> abonos = const [],
    int ventas = 0,
    int? ultimoPrecio,
  }) =>
      CuentaCliente(
        cliente: cliente,
        totalFiado: fiado,
        abonos: abonos,
        ventas: ventas,
        ultimoPrecio: ultimoPrecio,
      );

  group('Cliente', () {
    test('solo el nombre es obligatorio y nace recurrente', () {
      final cliente = Cliente.nuevo(
        id: 'c1',
        granjaId: 'granja-1',
        nombre: '  Luz Marina Ospina ',
        detalle: '  ',
      );
      expect(cliente.nombre, 'Luz Marina Ospina');
      expect(cliente.detalle, isNull);
      expect(cliente.recurrente, isTrue);
    });

    test('el celular, si se escribe, tiene 10 números y empieza por 3', () {
      Cliente conCelular(String telefono) =>
          Cliente.nuevo(id: 'c1', granjaId: 'granja-1', nombre: 'Pedro', telefono: telefono);
      expect(conCelular('3001234567').telefono, '300 123 4567');
      expect(conCelular('').telefono, isNull);
      expect(
        () => conCelular('300 123'),
        throwsA(isA<ClienteInvalido>().having((e) => e.campo, 'campo', 'telefono')),
      );
      expect(() => conCelular('6012345678'), throwsA(isA<ClienteInvalido>()));
    });

    test('rechaza un cliente sin nombre o con precio en cero', () {
      expect(
        () => Cliente.nuevo(id: 'c1', granjaId: 'granja-1', nombre: ' '),
        throwsA(isA<ClienteInvalido>()),
      );
      expect(
        () => Cliente.nuevo(
          id: 'c1',
          granjaId: 'granja-1',
          nombre: 'Pedro',
          precioLibraSugerido: 0,
        ),
        throwsA(isA<ClienteInvalido>()),
      );
    });
  });

  group('Abonos', () {
    test('Doña Marta debe \$539.800 y abona \$200.000', () {
      expect(abono(200000).valor, 200000);
    });

    test('no deja abonar más de lo que debe', () {
      expect(
        () => abono(539801),
        throwsA(
          isA<ClienteInvalido>().having(
            (e) => e.mensaje,
            'mensaje',
            r'Doña Marta solo debe $539.800. Revisa el valor.',
          ),
        ),
      );
    });

    test('no deja abonar a quien no debe nada', () {
      expect(() => abono(1000, debe: 0), throwsA(isA<ClienteInvalido>()));
    });

    test('no deja un abono de antes de la primera venta fiada', () {
      expect(
        () => Abono.nuevo(
          id: 'a1',
          cliente: marta,
          fecha: DateTime(2026, 10, 1),
          valor: 1000,
          debeSinEste: 539800,
          primeraVentaFiada: DateTime(2026, 10, 3),
          hoy: hoy,
        ),
        throwsA(isA<ClienteInvalido>().having((e) => e.campo, 'campo', 'fecha')),
      );
    });

    test('rechaza un abono en cero', () {
      expect(() => abono(0), throwsA(isA<ClienteInvalido>()));
    });
  });

  group('Cuenta del cliente', () {
    test('debe lo fiado menos lo abonado', () {
      final cuentaMarta = cuenta(
        marta,
        fiado: 739800,
        abonos: [abono(200000)],
        ventas: 2,
      );
      expect(cuentaMarta.debe, 539800);
      expect(cuentaMarta.alDia, isFalse);
    });

    test('al corregir un abono no se cuenta dos veces', () {
      final pago = abono(200000);
      expect(cuenta(marta, fiado: 739800, abonos: [pago]).debeSin(pago), 739800);
    });

    test('sugiere el precio de la última venta y, si no hay, el del cliente', () {
      const pedro = Cliente.reconstruir(
        id: 'pedro',
        granjaId: 'granja-1',
        nombre: 'Pedro Gómez',
        precioLibraSugerido: 5800,
      );
      expect(cuenta(pedro).precioSugerido, 5800);
      expect(cuenta(pedro, ultimoPrecio: 5600).precioSugerido, 5600);
    });

    test('un cliente con ventas o abonos no se puede borrar', () {
      expect(cuenta(marta).sePuedeBorrar, isTrue);
      expect(cuenta(marta, ventas: 1).sePuedeBorrar, isFalse);
    });

    test('los no recurrentes van al final, y arriba los que más deben', () {
      const vecino = Cliente.reconstruir(
        id: 'vecino',
        granjaId: 'granja-1',
        nombre: 'Vecino de la vereda',
        recurrente: false,
      );
      const jaime = Cliente.reconstruir(id: 'jaime', granjaId: 'granja-1', nombre: 'Don Jaime');
      final orden = [
        cuenta(vecino, fiado: 900000),
        cuenta(jaime),
        cuenta(marta, fiado: 539800),
      ]..sort(ordenDeClientes);
      expect([for (final c in orden) c.cliente.id], ['marta', 'jaime', 'vecino']);
    });

    test('avisa si un cambio deja abonos de más', () {
      expect(() => revisarQueNoQuedeAFavor(marta, -54000), throwsA(isA<ClienteInvalido>()));
      revisarQueNoQuedeAFavor(marta, 0);
    });
  });
}
