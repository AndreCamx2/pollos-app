import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../compartido/diseno/colores.dart';
import '../compartido/diseno/icono_modulo.dart';
import '../compartido/diseno/pulsable.dart';
import '../compartido/diseno/tema.dart';

/// Las secciones principales con la barra de abajo para pasar de una a otra.
class BarraSecciones extends StatelessWidget {
  const BarraSecciones({super.key, required this.ruta, required this.child});

  final String ruta;
  final Widget child;

  static const _secciones = [
    ('/', 'Galpones', Figura.galpon),
    ('/clientes', 'Clientes', Figura.personas),
    ('/cierres', 'Cierres', Figura.barras),
  ];

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: ColoresGranja.crema,
          border: Border(top: BorderSide(color: ColoresGranja.borde)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (final (camino, nombre, figura) in _secciones)
                  Expanded(
                    child: Semantics(
                      selected: ruta == camino,
                      child: Pulsable(
                        onTap: ruta == camino ? null : () => context.go(camino),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconoModulo(
                              figura,
                              fondo: Colors.transparent,
                              color: ruta == camino
                                  ? ColoresGranja.granero
                                  : ColoresGranja.tintaSuave,
                              tamano: 44,
                            ),
                            Text(
                              nombre,
                              style: conPeso(
                                textos.bodySmall!.copyWith(
                                  color: ruta == camino
                                      ? ColoresGranja.granero
                                      : ColoresGranja.tintaSuave,
                                ),
                                ruta == camino ? 700 : 600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
