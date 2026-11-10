import 'package:flutter/animation.dart';

abstract final class Curvas {
  /// Entrar, salir y responder al toque: arranca rápido y se siente inmediato.
  static const salida = Cubic(0.23, 1, 0.32, 1);

  /// Hojas que suben desde abajo, al estilo iOS.
  static const hoja = Cubic(0.32, 0.72, 0, 1);
}
