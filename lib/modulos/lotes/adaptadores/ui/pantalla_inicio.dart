import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_granja.dart';
import '../../../granja/adaptadores/ui/selector_granja.dart';

// shortcut: solo el encabezado; los galpones y lotes llegan en la parte 3.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    if (granja == null) return const Scaffold();
    final variasGranjas = (ref.watch(misGranjasProvider).asData?.value.length ?? 0) > 1;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
          children: [
            EncabezadoGranja(
              nombre: granja.nombre,
              alCambiarGranja: variasGranjas ? () => mostrarSelectorGranja(context) : null,
              accion: IconButton(
                tooltip: 'Personas',
                icon: const Icon(Icons.group_outlined),
                onPressed: () => context.push('/personas'),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ColoresGranja.papel,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: ColoresGranja.borde),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Todavía no hay galpones', style: textos.titleLarge),
                    const SizedBox(height: 4),
                    Text('Muy pronto podrás agregarlos desde aquí.', style: textos.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
