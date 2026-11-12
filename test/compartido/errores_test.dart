import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/compartido/errores.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('muestra tal cual las reglas del negocio que manda la base de datos', () {
    final error = PostgrestException(
      message: 'Solo quedan 271 pollos vivos en este lote',
      code: 'P0001',
    );
    expect(mensajeDeError(error), 'Solo quedan 271 pollos vivos en este lote');
  });

  test('no le muestra a la persona mensajes técnicos de la base de datos', () {
    final error = PostgrestException(
      message: 'invalid input syntax for type uuid: "abc"',
      code: '22P02',
    );
    expect(mensajeDeError(error), 'Algo salió mal. Intenta de nuevo.');
  });

  test('avisa cuando el nombre ya existe', () {
    final error = PostgrestException(message: 'duplicate key', code: '23505');
    expect(mensajeDeError(error), 'Ya existe uno con ese nombre.');
  });

  test('explica cuando el galpón ya tiene un lote abierto', () {
    final error = PostgrestException(
      message: 'duplicate key value violates unique constraint "un_lote_abierto_por_galpon"',
      code: '23505',
    );
    expect(mensajeDeError(error), 'Ese galpón ya tiene un lote abierto.');
  });

  test('avisa cuando no hay internet', () {
    expect(
      mensajeDeError(const SocketException('Failed host lookup')),
      'Sin conexión. Revisa el internet e intenta de nuevo.',
    );
  });

  test('explica cuando el correo o la contraseña no coinciden', () {
    final error = AuthException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    expect(mensajeDeError(error), 'El correo o la contraseña no coinciden.');
  });
}
