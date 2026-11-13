import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/granja/dominio/cuenta.dart';

void main() {
  group('Correo', () {
    test('acepta un correo bien escrito aunque traiga espacios a los lados', () {
      expect(errorDeCorreo('  marta@granjaelsol.co '), isNull);
    });

    test('dice qué le falta al correo', () {
      expect(errorDeCorreo(''), 'Escribe tu correo.');
      expect(errorDeCorreo('marta granjaelsol.co'), 'El correo no lleva espacios.');
      expect(errorDeCorreo('marta.granjaelsol.co'), 'Al correo le falta la @.');
      expect(errorDeCorreo('marta@granjaelsol'), contains('.com o .co'));
      expect(errorDeCorreo('marta@granjaelsol.c'), contains('.com o .co'));
      expect(errorDeCorreo('@granjaelsol.co'), contains('mal escrito'));
      expect(errorDeCorreo('marta@@granjaelsol.co'), contains('mal escrito'));
    });
  });

  group('Nombre', () {
    test('Marta Rodríguez es un nombre válido', () {
      expect(errorDeNombre('Marta   Rodríguez'), isNull);
    });

    test('rechaza nombres vacíos, de una letra, muy largos o solo con números', () {
      expect(errorDeNombre('   '), 'Escribe tu nombre.');
      expect(errorDeNombre('M'), 'Escribe al menos 2 letras.');
      expect(errorDeNombre('A' * 41), 'Usa máximo 40 letras.');
      expect(errorDeNombre('12345'), contains('letras'));
    });
  });

  group('Contraseña nueva', () {
    test('gallinas88 cumple todo', () {
      expect(errorDeClaveNueva('gallinas88'), isNull);
      expect(requisitosDeClave('gallinas88'), (largo: true, letrasYNumeros: true));
    });

    test('pide 8 caracteres y mezclar letras con números', () {
      expect(errorDeClaveNueva(''), 'Escribe la contraseña nueva.');
      expect(errorDeClaveNueva('pollo1'), 'Usa al menos 8 caracteres.');
      expect(errorDeClaveNueva('gallinero'), 'Mézclale letras y números.');
      expect(errorDeClaveNueva('12345678'), 'Mézclale letras y números.');
      expect(errorDeClaveNueva('a1${'x' * 71}'), 'Usa máximo 72 caracteres.');
    });

    test('la repetida tiene que ser igual', () {
      expect(errorDeClaveRepetida('gallinas88', 'gallinas88'), isNull);
      expect(errorDeClaveRepetida('gallinas88', ''), 'Escríbela otra vez para confirmar.');
      expect(errorDeClaveRepetida('gallinas88', 'gallina88'), 'No es igual a la de arriba.');
    });
  });
}
