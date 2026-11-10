import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modulos/granja/dominio/granja.dart';

final supabaseProvider = Provider((ref) => Supabase.instance.client);

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

/// Null mientras la persona no haya escrito su nombre la primera vez.
final miNombreProvider = FutureProvider<String?>((ref) async {
  final id = ref.watch(usuarioIdProvider);
  if (id == null) return null;
  final fila = await ref
      .watch(supabaseProvider)
      .from('perfiles')
      .select('nombre')
      .eq('id', id)
      .maybeSingle();
  return fila?['nombre'] as String?;
});

final misGranjasProvider = FutureProvider<List<Granja>>((ref) async {
  final id = ref.watch(usuarioIdProvider);
  if (id == null) return const [];
  final filas = await ref
      .watch(supabaseProvider)
      .from('miembros')
      .select('rol, granjas(id, nombre)')
      .eq('usuario_id', id)
      .order('unido_en');
  return [
    for (final fila in filas)
      (
        id: fila['granjas']['id'] as String,
        nombre: fila['granjas']['nombre'] as String,
        rol: Rol.values.byName(fila['rol'] as String),
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
