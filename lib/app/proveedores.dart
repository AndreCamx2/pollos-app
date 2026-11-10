import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../compartido/errores.dart';
import '../compartido/local/base_local.dart';
import '../modulos/galpones/adaptadores/local/repositorio_galpones_local.dart';
import '../modulos/galpones/dominio/galpon.dart';
import '../modulos/granja/dominio/granja.dart';
import '../modulos/lotes/adaptadores/local/repositorio_lotes_local.dart';
import '../modulos/lotes/aplicacion/crear_lote.dart';
import '../modulos/lotes/dominio/lote.dart';
import '../modulos/lotes/puertos/repositorio_lotes.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

/// main() la abre antes de arrancar la app y la entrega aquí.
final baseLocalProvider = Provider<BaseLocal>(
  (ref) => throw StateError('Falta abrir la base local en main().'),
);

final sesionProvider = StreamProvider<Session?>(
  (ref) => ref
      .watch(supabaseProvider)
      .auth
      .onAuthStateChange
      .map((cambio) => cambio.session),
);

final usuarioIdProvider = Provider<String?>((ref) {
  ref.watch(sesionProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

/// Pide el dato por internet y lo deja guardado en el celular. Sin señal
/// devuelve el último guardado, para que la app abra en el galpón.
Future<Object?> _oLoGuardado(
  BaseLocal local,
  String clave,
  Future<Object?> Function() pedir,
) async {
  try {
    final dato = await pedir().timeout(const Duration(seconds: 8));
    if (dato != null) await local.guardarDato(clave, dato);
    return dato;
  } catch (e) {
    final guardado = await local.leerDato(clave);
    if (!esFallaDeRed(e) || guardado == null) rethrow;
    return guardado;
  }
}

/// Null mientras la persona no haya escrito su nombre la primera vez.
final miNombreProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(usuarioIdProvider);
  if (id == null) return null;
  final supabase = ref.watch(supabaseProvider);
  final nombre = await _oLoGuardado(
    ref.watch(baseLocalProvider),
    'nombre:$id',
    () async {
      final fila = await supabase
          .from('perfiles')
          .select('nombre')
          .eq('id', id)
          .maybeSingle();
      return fila?['nombre'];
    },
  );
  return nombre as String?;
});

final misGranjasProvider = FutureProvider<List<Granja>>((ref) async {
  final id = ref.watch(usuarioIdProvider);
  if (id == null) return const [];
  final supabase = ref.watch(supabaseProvider);
  final granjas = await _oLoGuardado(
    ref.watch(baseLocalProvider),
    'granjas:$id',
    () async {
      final filas = await supabase
          .from('miembros')
          .select('rol, granjas(id, nombre)')
          .eq('usuario_id', id)
          .order('unido_en');
      return [
        for (final fila in filas)
          {
            'id': fila['granjas']['id'],
            'nombre': fila['granjas']['nombre'],
            'rol': fila['rol'],
          },
      ];
    },
  );
  return [
    for (final granja in granjas! as List)
      (
        id: granja['id'] as String,
        nombre: granja['nombre'] as String,
        rol: Rol.values.byName(granja['rol'] as String),
      ),
  ];
});

// shortcut: la granja elegida se olvida al cerrar la app y se vuelve a la
// primera; guardarla con shared_preferences si los dueños de varias lo piden.
class GranjaElegida extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(usuarioIdProvider);
    return null;
  }

  void elegir(String granjaId) => state = granjaId;
}

final granjaElegidaProvider =
    NotifierProvider<GranjaElegida, String?>(GranjaElegida.new);

final granjaActualProvider = Provider<Granja?>((ref) {
  final granjas = ref.watch(misGranjasProvider).asData?.value ?? const [];
  if (granjas.isEmpty) return null;
  final elegida = ref.watch(granjaElegidaProvider);
  return granjas.firstWhere((g) => g.id == elegida, orElse: () => granjas.first);
});

final miembrosProvider =
    FutureProvider.family<List<Miembro>, String>((ref, granjaId) async {
  final db = ref.watch(supabaseProvider);
  final filas = await db
      .from('miembros')
      .select('usuario_id, rol')
      .eq('granja_id', granjaId)
      .order('unido_en');
  // miembros y perfiles no tienen llave entre sí (las dos apuntan a
  // auth.users), así que los nombres se piden aparte.
  final perfiles = await db
      .from('perfiles')
      .select('id, nombre')
      .inFilter('id', [for (final f in filas) f['usuario_id']]);
  final nombres = {
    for (final p in perfiles) p['id'] as String: p['nombre'] as String,
  };
  return [
    for (final f in filas)
      (
        usuarioId: f['usuario_id'] as String,
        nombre: nombres[f['usuario_id']],
        rol: Rol.values.byName(f['rol'] as String),
      ),
  ];
});

/// Sube de número cada vez que cambia algo en la base local, sea porque la
/// persona guardó o porque llegó algo del servidor. Lo que se lee de la base
/// local lo observa para volver a leer.
class CambiosLocales extends Notifier<int> {
  @override
  int build() => 0;

  void avisar() => state++;
}

final cambiosLocalesProvider =
    NotifierProvider<CambiosLocales, int>(CambiosLocales.new);

final repositorioGalponesProvider = Provider(
  (ref) => RepositorioGalponesLocal(
    ref.watch(baseLocalProvider),
    autor: ref.watch(usuarioIdProvider),
  ),
);

final repositorioLotesProvider = Provider<RepositorioLotes>(
  (ref) => RepositorioLotesLocal(
    ref.watch(baseLocalProvider),
    autor: ref.watch(usuarioIdProvider),
  ),
);

final crearLoteProvider = Provider(
  (ref) => CrearLote(
    repositorio: ref.watch(repositorioLotesProvider),
    generarId: nuevoId,
    reloj: DateTime.now,
  ),
);

/// Los ids nacen en el celular para poder registrar sin señal.
String nuevoId() => const Uuid().v4();

/// Un galpón con el lote que tiene adentro, si tiene.
typedef GalponConLote = ({Galpon galpon, Lote? lote});

final lotesProvider = FutureProvider<List<Lote>>((ref) {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  return ref.watch(repositorioLotesProvider).listar(granja.id);
});

final galponesProvider = FutureProvider<List<GalponConLote>>((ref) async {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  final repositorio = ref.watch(repositorioGalponesProvider);
  final lotes = await ref.watch(lotesProvider.future);
  return [
    for (final galpon in await repositorio.listar(granja.id))
      (
        galpon: galpon,
        lote: lotes.where((l) => l.galponId == galpon.id && l.abierto).firstOrNull,
      ),
  ];
});
