import 'package:flutter/material.dart';

import 'colores.dart';
import 'espacios.dart';
import 'movimiento.dart';
import 'tema.dart';

/// Cualquier cosa que se toca se encoge un poco, para que se note que la app
/// recibió el toque. Reemplaza la onda de tinta de Material.
class Pulsable extends StatefulWidget {
  const Pulsable({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  var _presionado = false;

  void _presionar(bool valor) {
    if (widget.onTap != null) setState(() => _presionado = valor);
  }

  @override
  Widget build(BuildContext context) {
    final quieto = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _presionar(true),
        onTapUp: (_) => _presionar(false),
        onTapCancel: () => _presionar(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _presionado && !quieto ? 0.97 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curvas.salida,
          child: widget.child,
        ),
      ),
    );
  }
}

class BotonPrincipal extends StatelessWidget {
  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.cargando = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Pulsable(
      onTap: cargando ? null : onPressed,
      child: AnimatedOpacity(
        opacity: onPressed == null ? 0.45 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          // Alto mínimo y no fijo: con la letra grande el texto baja a dos
          // renglones y el botón crece con él.
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: e16, vertical: e12),
          decoration: BoxDecoration(
            color: ColoresGranja.granero,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: ColoresGranja.granero.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            heightFactor: 1,
            child: cargando
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: ColoresGranja.papel,
                    ),
                  )
                : Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: conPeso(
                      const TextStyle(
                        fontFamily: 'Figtree',
                        fontSize: 18,
                        color: ColoresGranja.papel,
                      ),
                      700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Para la acción que importa pero no es la principal de la pantalla.
class BotonSecundario extends StatelessWidget {
  const BotonSecundario({super.key, required this.texto, required this.onPressed});

  final String texto;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Pulsable(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: e16, vertical: e12),
        decoration: BoxDecoration(
          color: ColoresGranja.papel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ColoresGranja.tinta, width: 2),
        ),
        child: Center(
          heightFactor: 1,
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: conPeso(
              const TextStyle(
                fontFamily: 'Figtree',
                fontSize: 18,
                color: ColoresGranja.tinta,
              ),
              700,
            ),
          ),
        ),
      ),
    );
  }
}
