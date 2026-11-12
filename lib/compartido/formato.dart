const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// 1248000 -> "1.248.000"
String miles(int numero) {
  final digitos = numero.abs().toString();
  final grupos = <String>[];
  for (var fin = digitos.length; fin > 0; fin -= 3) {
    grupos.insert(0, digitos.substring(fin < 3 ? 0 : fin - 3, fin));
  }
  return '${numero < 0 ? '-' : ''}${grupos.join('.')}';
}

/// 1248000 -> "$1.248.000"
String plata(int pesos) =>
    pesos < 0 ? '-\$${miles(-pesos)}' : '\$${miles(pesos)}';

/// Un decimal como mucho y con coma: 245.5 -> "245,5"; 72.0 -> "72".
String decimal(num numero) {
  final redondeado = (numero * 10).round() / 10;
  final texto = redondeado == redondeado.roundToDouble()
      ? redondeado.round().toString()
      : redondeado.toStringAsFixed(1);
  return texto.replaceAll('.', ',');
}

/// "10 oct"
String fechaCorta(DateTime fecha) => '${fecha.day} ${_meses[fecha.month - 1]}';

/// Lee lo que la persona escribió en un campo de números enteros, con o sin
/// puntos de miles. Null si no escribió ningún número.
int? leerEntero(String texto) =>
    int.tryParse(texto.replaceAll(RegExp(r'\D'), ''));

/// Lee metros o libras escritos con coma o con punto.
double? leerDecimal(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

/// "María José Peñaloza" -> "MP"; "Jo" -> "J".
String iniciales(String nombre) {
  final palabras = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (palabras.isEmpty) return '';
  String primeraLetra(String palabra) => String.fromCharCode(palabra.runes.first);
  final primera = primeraLetra(palabras.first);
  final ultima = palabras.length > 1 ? primeraLetra(palabras.last) : '';
  return (primera + ultima).toUpperCase();
}
