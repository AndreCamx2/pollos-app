import 'package:flutter/material.dart';

import 'espacios.dart';
import 'gallo.dart';

/// Lo que se ve mientras llegan los datos de una pantalla.
class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(e24),
        child: GalloCantando(tamano: 72),
      ),
    );
  }
}
