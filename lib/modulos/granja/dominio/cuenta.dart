/// Lo que se revisa en el celular antes de pedirle algo a Supabase, para
/// decirle a la persona qué corregir en palabras claras.
library;

String? errorDeCorreo(String correo) {
  final limpio = correo.trim();
  if (limpio.isEmpty) return 'Escribe tu correo.';
  if (limpio.contains(' ')) return 'El correo no lleva espacios.';
  final partes = limpio.split('@');
  if (partes.length == 1) return 'Al correo le falta la @.';
  if (partes.length > 2 || partes.first.isEmpty || partes.last.isEmpty) {
    return 'Revisa el correo, algo quedó mal escrito.';
  }
  final dominio = partes.last;
  final punto = dominio.lastIndexOf('.');
  if (punto <= 0 || dominio.length - punto < 3) {
    return 'A este correo le falta el final, como .com o .co';
  }
  return null;
}

String? errorDeNombre(String nombre) {
  final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (limpio.isEmpty) return 'Escribe tu nombre.';
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(limpio)) {
    return 'El nombre lleva letras, no solo números.';
  }
  if (limpio.length < 2) return 'Escribe al menos 2 letras.';
  if (limpio.length > 40) return 'Usa máximo 40 letras.';
  return null;
}

/// Lo que se va marcando en verde mientras la persona escribe.
({bool largo, bool letrasYNumeros}) requisitosDeClave(String clave) => (
      largo: clave.length >= 8,
      letrasYNumeros: RegExp(r'\p{L}', unicode: true).hasMatch(clave) &&
          RegExp(r'\d').hasMatch(clave),
    );

String? errorDeClaveNueva(String clave) {
  if (clave.isEmpty) return 'Escribe la contraseña nueva.';
  final requisitos = requisitosDeClave(clave);
  if (!requisitos.largo) return 'Usa al menos 8 caracteres.';
  if (!requisitos.letrasYNumeros) return 'Mézclale letras y números.';
  // Supabase guarda la contraseña con bcrypt, que solo mira los primeros 72.
  if (clave.length > 72) return 'Usa máximo 72 caracteres.';
  return null;
}

String? errorDeClaveRepetida(String clave, String repetida) {
  if (repetida.isEmpty) return 'Escríbela otra vez para confirmar.';
  if (clave != repetida) return 'No es igual a la de arriba.';
  return null;
}
