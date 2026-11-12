import 'formato.dart';

/// Topes para atajar errores de dedo, como un cero de más, antes de guardar.
/// También evitan que Supabase rechace la fila por una cifra que no le cabe.
abstract final class Topes {
  static const pollos = 100000;
  static const bultos = 1000;
  static const kilosPorBulto = 100.0;
  static const libras = 99999.0;
  static const metros = 1000.0;
  static const precioLibra = 100000;
  static const precioBulto = 2000000;
  static const plata = 2000000000;
}

/// Un aviso cuando [valor] se aleja mucho de [referencia], lo normal en la
/// granja. No bloquea: solo pide revisar. [comparadoCon] completa la frase,
/// por ejemplo "tu última venta a Don Jaime".
String? avisoCifraRara(int valor, int? referencia, {required String comparadoCon}) {
  if (referencia == null || referencia <= 0 || valor <= 0) return null;
  if (valor >= referencia * 2.5) {
    return 'Es mucho más que $comparadoCon (${plata(referencia)}). '
        'Revisa que no sobre un cero.';
  }
  if (valor * 2.5 <= referencia) {
    return 'Es mucho menos que $comparadoCon (${plata(referencia)}). '
        'Revisa que no falte un cero.';
  }
  return null;
}
