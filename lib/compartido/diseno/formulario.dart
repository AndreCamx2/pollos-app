import 'package:flutter/material.dart';

import 'hoja_confirmar.dart';

/// Lo que comparten los formularios: saber si la persona cambió algo y
/// mostrar el error junto al campo que lo tiene.
mixin FormularioGranja<T extends StatefulWidget> on State<T> {
  String? error;

  /// El campo donde está [error]; null si el error es del formulario entero.
  String? campoError;

  String? _inicial;

  /// Todo lo que la persona puede cambiar, en un solo texto, para saber si
  /// hay algo sin guardar.
  String get firma;

  /// Se llama al final de initState, cuando los campos ya tienen lo que
  /// traían.
  void recordarInicio() => _inicial = firma;

  bool get hayCambios => _inicial != null && firma != _inicial;

  void mostrarError(String mensaje, [String? campo]) => setState(() {
        error = mensaje;
        campoError = campo;
      });

  void limpiarError() {
    error = null;
    campoError = null;
  }

  String? errorDe(String campo) => campoError == campo ? error : null;

  /// El error que no es de ningún campo: va abajo, junto al botón.
  String? get errorGeneral => campoError == null ? error : null;
}

/// Pregunta antes de salir si hay algo escrito que no se ha guardado. Guardar
/// y salir con context.pop no pasa por aquí.
class ProtegerCambios extends StatelessWidget {
  const ProtegerCambios({super.key, required this.hayCambios, required this.child});

  final bool hayCambios;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hayCambios,
      onPopInvokedWithResult: (salio, _) async {
        if (salio) return;
        final descartar = await confirmar(
          context,
          titulo: '¿Descartar lo que escribiste?',
          detalle: 'Todavía no lo has guardado. Si sales ahora, se pierde.',
          accion: 'Descartar y salir',
        );
        if (descartar && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
