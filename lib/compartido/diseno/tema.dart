import 'package:flutter/material.dart';

import 'colores.dart';

// Las dos fuentes son variables y Flutter no mueve el eje wght solo con
// fontWeight, así que cada estilo lleva también su FontVariation.
TextStyle conPeso(TextStyle estilo, int peso) => estilo.copyWith(
      fontWeight: FontWeight.values[peso ~/ 100 - 1],
      fontVariations: [FontVariation.weight(peso.toDouble())],
    );

TextStyle _titulo(double tamano, int peso) => conPeso(
      TextStyle(
        fontFamily: 'BricolageGrotesque',
        fontSize: tamano,
        height: 1.1,
        letterSpacing: -tamano * 0.02,
        color: ColoresGranja.tinta,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      peso,
    );

ThemeData temaGranja() {
  final cuerpo = conPeso(
    const TextStyle(
      fontFamily: 'Figtree',
      fontSize: 16,
      height: 1.4,
      color: ColoresGranja.tinta,
    ),
    400,
  );
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: ColoresGranja.borde),
  );

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Figtree',
    scaffoldBackgroundColor: ColoresGranja.crema,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: const ColorScheme.light(
      primary: ColoresGranja.granero,
      onPrimary: ColoresGranja.papel,
      secondary: ColoresGranja.maiz,
      onSecondary: ColoresGranja.textoSobreMaiz,
      error: ColoresGranja.granero,
      surface: ColoresGranja.papel,
      onSurface: ColoresGranja.tinta,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ColoresGranja.crema,
      foregroundColor: ColoresGranja.tinta,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: _titulo(22, 800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ColoresGranja.papel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde,
      enabledBorder: borde,
      focusedBorder: borde.copyWith(
        borderSide: const BorderSide(color: ColoresGranja.tinta, width: 2),
      ),
      labelStyle: const TextStyle(color: ColoresGranja.tintaSuave),
      floatingLabelStyle: const TextStyle(color: ColoresGranja.tinta),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ColoresGranja.granero,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColoresGranja.granero,
        textStyle: conPeso(cuerpo, 700),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColoresGranja.crema,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresGranja.granero,
    ),
  );

  // Se mezcla después de crear el tema porque ThemeData(fontFamily:) le
  // pondría Figtree también a los títulos.
  return base.copyWith(
    textTheme: base.textTheme.merge(
      TextTheme(
        displaySmall: _titulo(34, 800),
        headlineSmall: _titulo(28, 800),
        titleLarge: _titulo(20, 700),
        titleMedium: conPeso(cuerpo.copyWith(fontSize: 17), 700),
        bodyLarge: cuerpo,
        bodyMedium: cuerpo.copyWith(fontSize: 15),
        bodySmall: cuerpo.copyWith(
          fontSize: 13,
          color: ColoresGranja.tintaSuave,
        ),
        labelLarge: conPeso(
          cuerpo.copyWith(
            fontSize: 12,
            letterSpacing: 1.4,
            color: ColoresGranja.tintaSuave,
          ),
          700,
        ),
      ),
    ),
  );
}
