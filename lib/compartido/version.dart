/// La versión de esta app. Tiene que ser la misma de pubspec.yaml: una
/// prueba lo revisa para que no se quede atrás.
const versionDeLaApp = '1.5.0';

/// Si [otra] es más nueva que [actual]. Las dos van como "1.4.0"; se acepta
/// la "v" de las etiquetas ("v1.4.0") y se ignora lo que venga después de
/// los tres números.
bool esMasNueva(String otra, String actual) {
  final a = _numeros(otra);
  final b = _numeros(actual);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

List<int>? _numeros(String version) {
  final partes = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(version.trim());
  if (partes == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(partes.group(i)!)];
}
