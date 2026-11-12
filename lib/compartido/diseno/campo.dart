import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato.dart';
import 'colores.dart';
import 'espacios.dart';
import 'tema.dart';

/// Un campo de formulario con la etiqueta arriba y la letra grande, para
/// escribir con el celular en una mano.
class CampoGranja extends StatelessWidget {
  const CampoGranja({
    super.key,
    required this.etiqueta,
    required this.controller,
    this.opcional = false,
    this.pista,
    this.ayuda,
    this.teclado,
    this.formatos,
    this.mayusculas = TextCapitalization.none,
    this.lineas = 1,
  });

  final String etiqueta;
  final TextEditingController controller;
  final bool opcional;
  final String? pista;
  final String? ayuda;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatos;
  final TextCapitalization mayusculas;

  /// Más de una para notas.
  final int lineas;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: etiqueta,
            style: conPeso(textos.bodyMedium!, 700),
            children: [
              if (opcional)
                TextSpan(
                  text: ' (opcional)',
                  style: conPeso(
                    textos.bodyMedium!.copyWith(color: ColoresGranja.tintaSuave),
                    500,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: e8),
        TextField(
          controller: controller,
          keyboardType: teclado,
          inputFormatters: formatos,
          textCapitalization: mayusculas,
          minLines: lineas > 1 ? 2 : null,
          maxLines: lineas,
          style: conPeso(
            textos.bodyLarge!.copyWith(
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            700,
          ),
          decoration: InputDecoration(
            hintText: pista,
            hintStyle: conPeso(
              textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
              400,
            ),
            helperText: ayuda,
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }
}

/// Va poniendo los puntos de miles mientras la persona escribe: 1750000 se
/// ve como 1.750.000.
class MilesAlEscribir extends TextInputFormatter {
  const MilesAlEscribir();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue anterior,
    TextEditingValue nuevo,
  ) {
    final numero = leerEntero(nuevo.text);
    final texto = numero == null ? '' : miles(numero);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
