import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';

void main() {
  final hoy = DateTime(2026, 10, 10);

  Lote loteDePrueba({
    String galpon = 'Galpón 1',
    DateTime? fechaLlegada,
    int cantidadInicial = 500,
    int precioCompraTotal = 1750000,
  }) =>
      Lote.nuevo(
        id: 'lote-1',
        galpon: galpon,
        fechaLlegada: fechaLlegada ?? DateTime(2026, 9, 17),
        cantidadInicial: cantidadInicial,
        precioCompraTotal: precioCompraTotal,
        hoy: hoy,
      );

  group('Crear un lote', () {
    test('guarda los datos y quita espacios del nombre', () {
      final lote = loteDePrueba(galpon: '  Galpón 1  ');
      expect(lote.galpon, 'Galpón 1');
      expect(lote.cantidadInicial, 500);
      expect(lote.precioCompraTotal, 1750000);
    });

    test('rechaza un galpón sin nombre', () {
      expect(() => loteDePrueba(galpon: '   '), throwsA(isA<LoteInvalido>()));
    });

    test('rechaza cero pollos', () {
      expect(() => loteDePrueba(cantidadInicial: 0),
          throwsA(isA<LoteInvalido>()));
    });

    test('rechaza un precio negativo', () {
      expect(() => loteDePrueba(precioCompraTotal: -1),
          throwsA(isA<LoteInvalido>()));
    });

    test('rechaza una llegada en el futuro', () {
      expect(() => loteDePrueba(fechaLlegada: DateTime(2026, 10, 11)),
          throwsA(isA<LoteInvalido>()));
    });

    test('acepta una llegada hoy mismo', () {
      expect(loteDePrueba(fechaLlegada: hoy).diasDeEdad(hoy), 0);
    });
  });

  group('Días y alimento', () {
    test('llegó el 17 de septiembre: el 10 de octubre va en el día 23', () {
      expect(loteDePrueba().diasDeEdad(hoy), 23);
    });

    test('la hora del día no cambia la cuenta', () {
      final lote = loteDePrueba();
      expect(lote.diasDeEdad(DateTime(2026, 10, 10, 23, 59)), 23);
    });

    test('inicio hasta el día 21, cambio del 22 al 25, engorde desde el 26',
        () {
      final lote = loteDePrueba();
      final llegada = DateTime(2026, 9, 17);
      EtapaAlimento etapaEnDia(int dia) =>
          lote.etapaAlimento(llegada.add(Duration(days: dia)));

      expect(etapaEnDia(0), EtapaAlimento.inicio);
      expect(etapaEnDia(21), EtapaAlimento.inicio);
      expect(etapaEnDia(22), EtapaAlimento.cambio);
      expect(etapaEnDia(25), EtapaAlimento.cambio);
      expect(etapaEnDia(26), EtapaAlimento.engorde);
    });
  });

  group('Pollos vivos y cierre', () {
    test('500 que llegaron, 12 muertos y 0 vendidos: quedan 488', () {
      expect(loteDePrueba().vivos(muertos: 12, vendidos: 0), 488);
    });

    test('no deja que muertos y vendidos pasen de los que llegaron', () {
      expect(() => loteDePrueba().vivos(muertos: 10, vendidos: 491),
          throwsA(isA<LoteInvalido>()));
    });

    test('no acepta números negativos', () {
      expect(() => loteDePrueba().vivos(muertos: -1, vendidos: 0),
          throwsA(isA<LoteInvalido>()));
    });

    test('se cierra cuando no quedan pollos vivos', () {
      final lote = loteDePrueba();
      expect(lote.estaCerrado(muertos: 15, vendidos: 485), isTrue);
      expect(lote.estaCerrado(muertos: 15, vendidos: 484), isFalse);
    });
  });
}
