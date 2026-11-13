import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/movimiento.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../dominio/granja.dart';

Future<void> mostrarSelectorGranja(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: const AnimationStyle(
      curve: Curvas.hoja,
      duration: Duration(milliseconds: 280),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (_) => const _SelectorGranja(),
  );
}

class _SelectorGranja extends ConsumerWidget {
  const _SelectorGranja();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final granjas = ref.watch(misGranjasProvider).asData?.value ?? const <Granja>[];
    final actual = ref.watch(granjaActualProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(e20, 0, e20, e16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus granjas', style: textos.titleLarge),
            const SizedBox(height: e12),
            for (final granja in granjas)
              Padding(
                padding: const EdgeInsets.only(bottom: e8),
                child: Pulsable(
                  onTap: () {
                    ref.read(granjaElegidaProvider.notifier).elegir(granja.id);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(e16),
                    decoration: BoxDecoration(
                      color: ColoresGranja.papel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: granja.id == actual?.id
                            ? ColoresGranja.tinta
                            : ColoresGranja.borde,
                        width: granja.id == actual?.id ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(granja.nombre, style: textos.titleMedium),
                              Text(granja.rol.etiqueta, style: textos.bodySmall),
                            ],
                          ),
                        ),
                        if (granja.id == actual?.id)
                          const Icon(Icons.check_rounded, color: ColoresGranja.granero),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
