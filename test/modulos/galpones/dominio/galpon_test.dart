import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/galpones/dominio/galpon.dart';

void main() {
  const galpon1 = Galpon.reconstruir(
    id: 'galpon-1',
    granjaId: 'granja-1',
    nombre: 'Galpón 1',
  );

  Galpon galponNuevo({
    String id = 'galpon-5',
    String nombre = 'Galpón 5',
    int? capacidad,
    double? largoM,
    double? anchoM,
    String? ubicacion,
  }) =>
      Galpon.nuevo(
        id: id,
        granjaId: 'granja-1',
        nombre: nombre,
        capacidad: capacidad,
        largoM: largoM,
        anchoM: anchoM,
        ubicacion: ubicacion,
        otros: const [galpon1],
      );

  test('solo el nombre es obligatorio', () {
    final galpon = galponNuevo(nombre: '  Galpón 5 ', ubicacion: '  ');
    expect(galpon.nombre, 'Galpón 5');
    expect(galpon.capacidad, isNull);
    expect(galpon.ubicacion, isNull);
    expect(galpon.areaM2, isNull);
  });

  test('rechaza un galpón sin nombre', () {
    expect(() => galponNuevo(nombre: '   '), throwsA(isA<GalponInvalido>()));
  });

  test('no deja dos galpones con el mismo nombre, aunque cambien las mayúsculas', () {
    expect(() => galponNuevo(nombre: 'GALPÓN 1'), throwsA(isA<GalponInvalido>()));
  });

  test('al corregir un galpón puede conservar su propio nombre', () {
    final corregido = galponNuevo(id: 'galpon-1', nombre: 'Galpón 1', capacidad: 600);
    expect(corregido.capacidad, 600);
  });

  test('rechaza capacidad o medidas en cero', () {
    expect(() => galponNuevo(capacidad: 0), throwsA(isA<GalponInvalido>()));
    expect(() => galponNuevo(largoM: 0, anchoM: 6), throwsA(isA<GalponInvalido>()));
  });

  test('12 por 6 metros con 600 pollos: 72 m² y 8,3 pollos por metro', () {
    final galpon = galponNuevo(capacidad: 600, largoM: 12, anchoM: 6);
    expect(galpon.areaM2, 72);
    expect(galpon.densidad, closeTo(8.33, 0.01));
  });
}
