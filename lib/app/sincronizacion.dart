import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../compartido/errores.dart';
import '../compartido/local/base_local.dart';
import '../compartido/sincronizacion/remoto.dart';
import '../compartido/sincronizacion/sincronizador.dart';
import 'proveedores.dart';

final sincronizadorProvider = Provider(
  (ref) => Sincronizador(
    ref.watch(baseLocalProvider),
    RemotoSupabase(ref.watch(supabaseProvider)),
  ),
);

/// [falla] trae la frase para mostrar cuando no se pudo sincronizar por algo
/// distinto a la señal.
typedef EstadoSincronizacion = ({
  bool trabajando,
  bool sinSenal,
  String? falla,
  int porSubir,
  int rechazados,
});

/// Sincroniza la granja actual al abrir la app, al volver a ella, después de
/// cada cambio y cada medio minuto mientras quede algo por subir.
class Sincronizacion extends Notifier<EstadoSincronizacion> {
  var _trabajando = false;
  var _pidieronOtra = false;
  var _sinSenal = false;
  String? _falla;

  @override
  EstadoSincronizacion build() {
    final granjaId = ref.watch(granjaActualProvider.select((g) => g?.id));
    if (granjaId != null) {
      final reloj = Timer.periodic(const Duration(seconds: 30), (_) {
        if (state.porSubir > 0) sincronizar();
      });
      final alVolver = AppLifecycleListener(onResume: sincronizar);
      ref.onDispose(() {
        reloj.cancel();
        alVolver.dispose();
      });
      Future.microtask(sincronizar);
    }
    return (
      trabajando: false,
      sinSenal: false,
      falla: null,
      porSubir: 0,
      rechazados: 0,
    );
  }

  /// Las pantallas la llaman después de guardar o borrar algo.
  Future<void> huboCambios() async {
    ref.read(cambiosLocalesProvider.notifier).avisar();
    await _publicar();
    unawaited(sincronizar());
  }

  Future<void> sincronizar() async {
    final granjaId = ref.read(granjaActualProvider)?.id;
    if (granjaId == null) return;
    if (_trabajando) {
      _pidieronOtra = true;
      return;
    }
    _trabajando = true;
    await _publicar();
    try {
      await ref.read(sincronizadorProvider).sincronizar(granjaId);
      _sinSenal = false;
      _falla = null;
    } catch (e) {
      _sinSenal = esFallaDeRed(e);
      _falla = _sinSenal ? null : mensajeDeError(e);
    }
    _trabajando = false;
    ref.read(cambiosLocalesProvider.notifier).avisar();
    await _publicar();
    if (_pidieronOtra) {
      _pidieronOtra = false;
      unawaited(sincronizar());
    }
  }

  Future<void> reintentar(Pendiente pendiente) async {
    await ref.read(baseLocalProvider).reintentar(pendiente);
    await huboCambios();
  }

  /// Necesita señal: trae del servidor cómo quedó la fila.
  Future<void> descartar(Pendiente pendiente) async {
    await ref.read(sincronizadorProvider).descartar(pendiente);
    await huboCambios();
  }

  Future<void> _publicar() async {
    final granjaId = ref.read(granjaActualProvider)?.id;
    if (granjaId == null) return;
    final cuenta = await ref.read(baseLocalProvider).cuentaPendientes(granjaId);
    state = (
      trabajando: _trabajando,
      sinSenal: _sinSenal,
      falla: _falla,
      porSubir: cuenta.porSubir,
      rechazados: cuenta.rechazados,
    );
  }
}

final sincronizacionProvider =
    NotifierProvider<Sincronizacion, EstadoSincronizacion>(Sincronizacion.new);

final rechazadosProvider = FutureProvider<List<Pendiente>>((ref) {
  ref.watch(cambiosLocalesProvider);
  final granjaId = ref.watch(granjaActualProvider.select((g) => g?.id));
  if (granjaId == null) return const [];
  return ref.watch(baseLocalProvider).pendientes(granjaId, rechazados: true);
});
