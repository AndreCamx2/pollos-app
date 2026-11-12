import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../formato.dart';
import 'colores.dart';
import 'espacios.dart';
import 'tema.dart';

/// Un campo de formulario con la etiqueta arriba y la letra grande, para
/// escribir con el celular en una mano.
class CampoGranja extends StatefulWidget {
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
    this.error,
    this.clave = false,
    this.autollenado,
    this.accionTeclado,
    this.alTerminar,
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

  /// Se muestra en rojo debajo del campo.
  final String? error;

  /// Oculta lo escrito y pone el ojo para verlo.
  final bool clave;

  final Iterable<String>? autollenado;
  final TextInputAction? accionTeclado;
  final ValueChanged<String>? alTerminar;

  @override
  State<CampoGranja> createState() => _CampoGranjaState();
}

class _CampoGranjaState extends State<CampoGranja> {
  var _verClave = false;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final oculto = widget.clave && !_verClave;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.etiqueta,
            style: conPeso(textos.bodyMedium!, 700),
            children: [
              if (widget.opcional)
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
          controller: widget.controller,
          keyboardType: widget.clave ? TextInputType.visiblePassword : widget.teclado,
          inputFormatters: widget.formatos,
          textCapitalization: widget.mayusculas,
          obscureText: oculto,
          autocorrect: !widget.clave,
          enableSuggestions: !widget.clave,
          autofillHints: widget.autollenado,
          textInputAction: widget.accionTeclado,
          onSubmitted: widget.alTerminar,
          minLines: widget.lineas > 1 ? 2 : null,
          maxLines: widget.lineas,
          style: conPeso(
            textos.bodyLarge!.copyWith(
              fontSize: 20,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            700,
          ),
          decoration: InputDecoration(
            hintText: widget.pista,
            hintStyle: conPeso(
              textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
              400,
            ),
            helperText: widget.ayuda,
            helperMaxLines: 3,
            errorText: widget.error,
            errorMaxLines: 3,
            suffixIcon: widget.clave
                ? IconButton(
                    tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    color: ColoresGranja.tintaSuave,
                    icon: Icon(
                      _verClave
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _verClave = !_verClave),
                  )
                : null,
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
    // Doce cifras alcanzan para cualquier plata de la granja; más sería un
    // dedo pegado y no cabría en un número.
    final digitos = nuevo.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 12) return anterior;
    final numero = leerEntero(digitos);
    final texto = numero == null ? '' : miles(numero);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Para campos de cantidades enteras: solo números y como mucho siete cifras.
final soloCantidad = <TextInputFormatter>[
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(7),
];

/// Para libras, kilos y metros: números con coma o punto.
final soloDecimal = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
  LengthLimitingTextInputFormatter(9),
];
