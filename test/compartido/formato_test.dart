import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/compartido/formato.dart';

void main() {
  test('la plata va con signo de pesos y punto de miles', () {
    expect(plata(1248000), r'$1.248.000');
    expect(plata(3500), r'$3.500');
    expect(plata(980), r'$980');
    expect(plata(0), r'$0');
    expect(plata(-54000), r'-$54.000');
  });

  test('las cantidades grandes llevan punto de miles', () {
    expect(miles(1452), '1.452');
    expect(miles(500), '500');
  });

  test('los decimales van con coma y sin ceros de sobra', () {
    expect(decimal(245.5), '245,5');
    expect(decimal(72.0), '72');
    expect(decimal(8.333), '8,3');
  });

  test('las fechas cortas son día y mes', () {
    expect(fechaCorta(DateTime(2026, 10, 10)), '10 oct');
    expect(fechaCorta(DateTime(2026, 9, 17)), '17 sep');
  });

  test('lee lo que la persona escribe, con puntos, comas o espacios', () {
    expect(leerEntero('1.750.000'), 1750000);
    expect(leerEntero(''), isNull);
    expect(leerDecimal('12,5'), 12.5);
    expect(leerDecimal(' 6 '), 6);
    expect(leerDecimal(''), isNull);
  });

  test('en libras el punto de miles no se confunde con decimales', () {
    expect(leerDecimal('1.250'), 1250);
    expect(leerDecimal('1.250,5'), 1250.5);
    expect(leerDecimal('12.345.678'), 12345678);
    expect(leerDecimal('50.5'), 50.5);
    expect(leerDecimal('245.75'), 245.75);
    expect(leerDecimal('0.125'), 0.125);
  });
}
