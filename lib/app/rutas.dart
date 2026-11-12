import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../compartido/diseno/estado_error.dart';
import '../modulos/cierres/adaptadores/ui/pantalla_cierre_lote.dart';
import '../modulos/cierres/adaptadores/ui/pantalla_cierres.dart';
import '../modulos/clientes/adaptadores/ui/pantalla_abono.dart';
import '../modulos/clientes/adaptadores/ui/pantalla_clientes.dart';
import '../modulos/clientes/adaptadores/ui/pantalla_formulario_cliente.dart';
import '../modulos/galpones/adaptadores/ui/pantalla_formulario_galpon.dart';
import '../modulos/galpones/adaptadores/ui/pantalla_galpon.dart';
import '../modulos/galpones/adaptadores/ui/pantalla_galpones.dart';
import '../modulos/granja/adaptadores/ui/pantalla_completar_cuenta.dart';
import '../modulos/granja/adaptadores/ui/pantalla_entrar.dart';
import '../modulos/granja/adaptadores/ui/pantalla_personas.dart';
import '../modulos/granja/adaptadores/ui/pantalla_sin_granja.dart';
import '../modulos/lotes/adaptadores/ui/pantalla_formulario_lote.dart';
import '../modulos/registros/adaptadores/ui/pantalla_compra_alimento.dart';
import '../modulos/registros/adaptadores/ui/pantalla_formulario_marca.dart';
import '../modulos/registros/adaptadores/ui/pantalla_medicina.dart';
import '../modulos/registros/adaptadores/ui/pantalla_muertos.dart';
import '../modulos/registros/adaptadores/ui/pantalla_venta.dart';
import 'barra_secciones.dart';
import 'proveedores.dart';

const _deEntrada = {'/cargando', '/entrar', '/completar-cuenta', '/sin-granja'};

final rutasProvider = Provider<GoRouter>((ref) {
  final cambios = ValueNotifier(0);
  void avisar(Object? _, Object? _) => cambios.value++;
  ref.listen(sesionProvider, avisar);
  ref.listen(miNombreProvider, avisar);
  ref.listen(misGranjasProvider, avisar);

  final rutas = GoRouter(
    initialLocation: '/cargando',
    refreshListenable: cambios,
    redirect: (context, state) => _destino(ref, state.matchedLocation),
    routes: [
      GoRoute(path: '/cargando', builder: (_, _) => const _PantallaCargando()),
      GoRoute(path: '/entrar', builder: (_, _) => const PantallaEntrar()),
      GoRoute(
        path: '/completar-cuenta',
        builder: (_, _) => const PantallaCompletarCuenta(),
      ),
      GoRoute(path: '/sin-granja', builder: (_, _) => const PantallaSinGranja()),
      ShellRoute(
        builder: (_, estado, pantalla) =>
            BarraSecciones(ruta: estado.matchedLocation, child: pantalla),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PantallaGalpones()),
          GoRoute(path: '/clientes', builder: (_, _) => const PantallaClientes()),
          GoRoute(path: '/cierres', builder: (_, _) => const PantallaCierres()),
        ],
      ),
      GoRoute(path: '/personas', builder: (_, _) => const PantallaPersonas()),
      GoRoute(
        path: '/galpones/nuevo',
        builder: (_, _) => const PantallaFormularioGalpon(),
      ),
      GoRoute(
        path: '/galpones/:id',
        builder: (_, estado) => PantallaGalpon(galponId: estado.pathParameters['id']!),
      ),
      GoRoute(
        path: '/galpones/:id/editar',
        builder: (_, estado) =>
            PantallaFormularioGalpon(galponId: estado.pathParameters['id']),
      ),
      GoRoute(
        path: '/lotes/nuevo',
        builder: (_, estado) => PantallaFormularioLote(
          galponId: estado.uri.queryParameters['galpon'],
        ),
      ),
      GoRoute(
        path: '/lotes/:id/editar',
        builder: (_, estado) =>
            PantallaFormularioLote(loteId: estado.pathParameters['id']),
      ),
      for (final (camino, pantalla) in <(String, Widget Function({required String loteId, String? registroId}))>[
        ('alimento', PantallaCompraAlimento.new),
        ('muertos', PantallaMuertos.new),
        ('medicina', PantallaMedicina.new),
        ('venta', PantallaVenta.new),
      ])
        GoRoute(
          path: '/lotes/:lote/$camino',
          builder: (_, estado) => pantalla(loteId: estado.pathParameters['lote']!),
          routes: [
            GoRoute(
              path: ':registro',
              builder: (_, estado) => pantalla(
                loteId: estado.pathParameters['lote']!,
                registroId: estado.pathParameters['registro'],
              ),
            ),
          ],
        ),
      GoRoute(
        path: '/lotes/:id/cierre',
        builder: (_, estado) => PantallaCierreLote(loteId: estado.pathParameters['id']!),
      ),
      GoRoute(path: '/marcas/nueva', builder: (_, _) => const PantallaFormularioMarca()),
      GoRoute(
        path: '/marcas/:id/editar',
        builder: (_, estado) => PantallaFormularioMarca(marcaId: estado.pathParameters['id']),
      ),
      GoRoute(
        path: '/clientes/nuevo',
        builder: (_, _) => const PantallaFormularioCliente(),
      ),
      GoRoute(
        path: '/clientes/:id/editar',
        builder: (_, estado) =>
            PantallaFormularioCliente(clienteId: estado.pathParameters['id']),
      ),
      GoRoute(
        path: '/clientes/:id/abono',
        builder: (_, estado) => PantallaAbono(clienteId: estado.pathParameters['id']!),
        routes: [
          GoRoute(
            path: ':abono',
            builder: (_, estado) => PantallaAbono(
              clienteId: estado.pathParameters['id']!,
              abonoId: estado.pathParameters['abono'],
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    rutas.dispose();
    cambios.dispose();
  });
  return rutas;
});

/// Cada persona pasa por: entrar, escribir su nombre, tener una granja.
/// Mientras le falte un paso, la app la lleva a ese paso.
String? _destino(Ref ref, String ruta) {
  String? ir(String destino) => ruta == destino ? null : destino;

  final sesion = ref.read(sesionProvider);
  if (!sesion.hasValue && !sesion.hasError) return ir('/cargando');
  if (sesion.asData?.value == null) return ir('/entrar');

  final nombre = ref.read(miNombreProvider);
  final granjas = ref.read(misGranjasProvider);
  if (!nombre.hasValue || !granjas.hasValue) return ir('/cargando');
  if (nombre.requireValue == null) return ir('/completar-cuenta');
  if (granjas.requireValue.isEmpty) return ir('/sin-granja');

  return _deEntrada.contains(ruta) ? '/' : null;
}

class _PantallaCargando extends ConsumerWidget {
  const _PantallaCargando();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error =
        ref.watch(miNombreProvider).error ?? ref.watch(misGranjasProvider).error;
    return Scaffold(
      body: SafeArea(
        child: error == null
            ? const Center(child: CircularProgressIndicator())
            : EstadoError(
                error: error,
                alReintentar: () {
                  ref.invalidate(miNombreProvider);
                  ref.invalidate(misGranjasProvider);
                },
              ),
      ),
    );
  }
}
