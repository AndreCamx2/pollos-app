import 'package:flutter/painting.dart';

/// Cada color significa algo y siempre lo mismo: granero es lo que sale
/// (plata, pollos) y la acción principal; pasto es lo que entra.
abstract final class ColoresGranja {
  static const maiz = Color(0xFFF2B632);
  static const maizClaro = Color(0xFFFCEBC2);
  static const maizTecho = Color(0xFFE7A527);
  static const maizOscuro = Color(0xFF8A5A00);
  static const textoSobreMaiz = Color(0xFF4A3A1E);

  static const granero = Color(0xFFA3401F);
  static const graneroClaro = Color(0xFFF6DDD3);

  static const pasto = Color(0xFF2F6B3A);
  static const pastoClaro = Color(0xFFE2EFDF);

  /// Solo para medicina.
  static const lila = Color(0xFFB9A8F2);
  static const lilaClaro = Color(0xFFECE8FB);
  static const lilaOscuro = Color(0xFF5B4BB0);

  static const tinta = Color(0xFF2B211A);
  static const tintaSuave = Color(0xFF6B5D52);
  static const textoSobreTinta = Color(0xFFCDBFAF);

  /// El gallo de la app: cresta y barbillas, y el pico.
  static const cresta = Color(0xFFD63A22);
  static const pico = Color(0xFFF08A24);

  static const crema = Color(0xFFFBF5EC);
  static const papel = Color(0xFFFFFFFF);
  static const borde = Color(0x1F2B211A);

  /// Fondo de las barras de avance y de lo que está apagado.
  static const surco = Color(0xFFF1E9DC);
}
