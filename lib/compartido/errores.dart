import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Sin señal o con la conexión cortada: no es culpa del dato y vale la pena
/// intentar más tarde.
bool esFallaDeRed(Object error) =>
    error is IOException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException ||
    '$error'.contains('SocketException') ||
    '$error'.contains('ClientException');

/// El servidor está caído, ocupado o no reconoció la sesión: el dato no
/// tiene la culpa. Llega como código de Postgres (conexión, bloqueo, recursos,
/// consulta cancelada), de PostgREST o como el número de la respuesta.
bool esFallaPasajera(PostgrestException error) {
  final codigo = error.code ?? '';
  return codigo.isEmpty ||
      RegExp(r'^(PGRST[03]\d*|(08|40|53|57)\w{3}|5\d\d|429|401)$').hasMatch(codigo);
}

/// Convierte cualquier error en una frase que se le puede mostrar a la persona.
String mensajeDeError(Object error) {
  if (esFallaDeRed(error)) {
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
    if (error.statusCode == '429' || error.code == 'over_request_rate_limit') {
      return 'Hiciste muchos intentos. Espera unos minutos y vuelve a probar.';
    }
    return 'No se pudo entrar. Intenta de nuevo.';
  }
  if (error is PostgrestException) {
    // P0001 son los "raise exception" del esquema, ya escritos para la persona.
    if (error.code == 'P0001') return error.message;
    if (error.code == '23505') {
      return error.message.contains('un_lote_abierto_por_galpon')
          ? 'Ese galpón ya tiene un lote abierto.'
          : 'Ya existe uno con ese nombre.';
    }
    if (error.code == '23503') {
      return 'Depende de otro registro que ya no existe o que todavía se usa.';
    }
    if (error.code == '42501') return 'Tu rol no tiene permiso para hacer esto.';
  }
  return 'Algo salió mal. Intenta de nuevo.';
}
