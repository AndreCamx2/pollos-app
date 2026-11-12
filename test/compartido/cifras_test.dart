import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/compartido/cifras.dart';

void main() {
  test(r'$56.000 la libra cuando la última fue a $5.600: avisa que sobra un cero', () {
    expect(
      avisoCifraRara(56000, 5600, comparadoCon: 'tu última venta'),
      r'Es mucho más que tu última venta ($5.600). Revisa que no sobre un cero.',
    );
  });

  test(r'$560 la libra cuando la última fue a $5.600: avisa que falta un cero', () {
    expect(avisoCifraRara(560, 5600, comparadoCon: 'tu última venta'), contains('falte un cero'));
  });

  test('un precio parecido al de siempre no avisa', () {
    expect(avisoCifraRara(5800, 5600, comparadoCon: 'tu última venta'), isNull);
  });

  test('sin nada con qué comparar no avisa', () {
    expect(avisoCifraRara(5800, null, comparadoCon: 'tu última venta'), isNull);
  });
}
