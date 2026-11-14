import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/compartido/version.dart';

void main() {
  test('la versión de la app es la misma de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final escrita = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec);
    expect(escrita?.group(1), versionDeLaApp);
  });

  test('reconoce cuándo lo publicado es más nuevo que lo instalado', () {
    expect(esMasNueva('v1.5.1', '1.5.0'), isTrue);
    expect(esMasNueva('1.10.0', '1.9.3'), isTrue);
    expect(esMasNueva('2.0.0', '1.9.9'), isTrue);
    expect(esMasNueva('v1.5.0', '1.5.0'), isFalse);
    expect(esMasNueva('v1.4.0', '1.5.0'), isFalse);
    expect(esMasNueva('borrador', '1.5.0'), isFalse);
  });
}
