import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte cualquier error en una frase que se le puede mostrar a la persona.
String mensajeDeError(Object error) {
  if (error is SocketException ||
      error is AuthRetryableFetchException ||
      '$error'.contains('SocketException')) {
    return 'Sin conexión. Revisa el internet e intenta de nuevo.';
  }
  if (error is AuthException) {
    if (error.code == 'invalid_credentials' ||
        error.message == 'Invalid login credentials') {
      return 'El correo o la contraseña no coinciden.';
    }
    if (error.code == 'weak_password') {
      return 'Esa contraseña es muy fácil de adivinar. Usa una más larga.';
    }
    if (error.code == 'same_password') {
      return 'La contraseña nueva debe ser distinta a la que te dieron.';
    }
    return 'No se pudo entrar. Intenta de nuevo.';
  }
  if (error is PostgrestException) {
    // P0001 son los "raise exception" del esquema, ya escritos para la persona.
    if (error.code == 'P0001') return error.message;
    if (error.code == '23505') return 'Ya existe uno con ese nombre.';
    if (error.code == '42501') return 'Tu rol no tiene permiso para hacer esto.';
  }
  return 'Algo salió mal. Intenta de nuevo.';
}
