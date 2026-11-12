import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../compartido/errores.dart';
import '../compartido/local/base_local.dart';
import '../modulos/clientes/adaptadores/local/repositorio_clientes_local.dart';
import '../modulos/clientes/dominio/cliente.dart';
import '../modulos/galpones/adaptadores/local/repositorio_galpones_local.dart';
import '../modulos/galpones/dominio/galpon.dart';
import '../modulos/granja/dominio/granja.dart';
import '../modulos/lotes/adaptadores/local/repositorio_lotes_local.dart';
import '../modulos/lotes/aplicacion/crear_lote.dart';
import '../modulos/lotes/dominio/lote.dart';
import '../modulos/lotes/puertos/repositorio_lotes.dart';
import '../modulos/registros/adaptadores/local/repositorio_registros_local.dart';
import '../modulos/registros/dominio/cuentas_lote.dart';
import '../modulos/registros/dominio/marca.dart';
import '../modulos/registros/dominio/registro.dart';

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
/// La granja que la persona eligió la última vez; queda guardada en el
/// celular para abrir en esa.
class GranjaElegida extends Notifier<String?> {
  @override
  String? build() {
    final id = ref.watch(usuarioIdProvider);
    if (id != null) _leerLaGuardada(id);
    return null;
  }

  Future<void> _leerLaGuardada(String usuarioId) async {
    final guardada = await ref.read(baseLocalProvider).leerDato('granja:$usuarioId');
    if (guardada is String && state == null) state = guardada;
  }

  void elegir(String granjaId) {
    state = granjaId;
    final id = ref.read(usuarioIdProvider);
    if (id != null) ref.read(baseLocalProvider).guardarDato('granja:$id', granjaId);
  }
}

final granjaElegidaProvider =
    NotifierProvider<GranjaElegida, String?>(GranjaElegida.new);

final granjaActualProvider = Provider<Granja?>((ref) {
  final granjas = ref.watch(misGranjasProvider).asData?.value ?? const [];
  if (granjas.isEmpty) return null;
  final elegida = ref.watch(granjaElegidaProvider);
  return granjas.firstWhere((g) => g.id == elegida, orElse: () => granjas.first);
});

/// Queda guardado en el celular para mostrar quién anotó o recibió algo
/// aunque no haya señal.
final miembrosProvider =
    FutureProvider.family<List<Miembro>, String>((ref, granjaId) async {
  final db = ref.watch(supabaseProvider);
  final miembros = await _oLoGuardado(
    ref.watch(baseLocalProvider),
    'miembros:$granjaId',
    () async {
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
      final nombres = {for (final p in perfiles) p['id']: p['nombre']};
      return [
        for (final f in filas)
          {
            'usuario_id': f['usuario_id'],
            'nombre': nombres[f['usuario_id']],
            'rol': f['rol'],
          },
      ];
    },
  );
  return [
    for (final m in miembros! as List)
      (
        usuarioId: m['usuario_id'] as String,
        nombre: m['nombre'] as String?,
        rol: Rol.values.byName(m['rol'] as String),
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

final repositorioRegistrosProvider = Provider(
  (ref) => RepositorioRegistrosLocal(
    ref.watch(baseLocalProvider),
    autor: ref.watch(usuarioIdProvider),
  ),
);

final repositorioClientesProvider = Provider(
  (ref) => RepositorioClientesLocal(
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

/// Un galpón con el lote que tiene adentro, si tiene, y sus cuentas.
typedef GalponConLote = ({Galpon galpon, Lote? lote, CuentasLote? cuentas});

final lotesProvider = FutureProvider<List<Lote>>((ref) {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  return ref.watch(repositorioLotesProvider).listar(granja.id);
});

/// Todo lo anotado en la granja, lo más reciente primero.
final registrosProvider = FutureProvider<List<Registro>>((ref) {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  return ref.watch(repositorioRegistrosProvider).listar(granja.id);
});

final galponesProvider = FutureProvider<List<GalponConLote>>((ref) async {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  final repositorio = ref.watch(repositorioGalponesProvider);
  final lotes = await ref.watch(lotesProvider.future);
  final registros = await ref.watch(registrosProvider.future);
  return [
    for (final galpon in await repositorio.listar(granja.id))
      if (lotes.where((l) => l.galponId == galpon.id && l.abierto).firstOrNull
          case final lote?)
        (galpon: galpon, lote: lote, cuentas: CuentasLote(lote, registros))
      else
        (galpon: galpon, lote: null, cuentas: null),
  ];
});

/// Cada cliente con lo que debe, ordenados como se muestran: primero los
/// recurrentes, los que más deben arriba.
final cuentasClientesProvider = FutureProvider<List<CuentaCliente>>((ref) async {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  final repositorio = ref.watch(repositorioClientesProvider);
  final abonos = await repositorio.abonos(granja.id);
  final ventas = [
    for (final registro in await ref.watch(registrosProvider.future))
      if (registro is Venta) registro,
  ];
  return [
    for (final cliente in await repositorio.clientes(granja.id))
      _cuenta(cliente, ventas, abonos),
  ]..sort(ordenDeClientes);
});

/// [ventas] vienen de la más reciente a la más antigua.
CuentaCliente _cuenta(Cliente cliente, List<Venta> ventas, List<Abono> abonos) {
  final suyas = [for (final v in ventas) if (v.clienteId == cliente.id) v];
  final fiadas = [for (final v in suyas) if (v.fiado) v];
  return CuentaCliente(
    cliente: cliente,
    totalFiado: fiadas.fold(0, (suma, venta) => suma + venta.total),
    abonos: [for (final a in abonos) if (a.clienteId == cliente.id) a],
    ventas: suyas.length,
    ultimoPrecio: suyas.firstOrNull?.precioLibra,
    primeraFiada: fiadas.lastOrNull?.fecha,
  );
}

final cuentaClienteProvider = Provider.family<CuentaCliente?, String>(
  (ref, clienteId) => ref
      .watch(cuentasClientesProvider)
      .asData
      ?.value
      .where((cuenta) => cuenta.cliente.id == clienteId)
      .firstOrNull,
);

/// Las marcas de alimento de la granja, las que se usan primero.
final marcasProvider = FutureProvider<List<MarcaConCompras>>((ref) async {
  ref.watch(cambiosLocalesProvider);
  final granja = ref.watch(granjaActualProvider);
  if (granja == null) return const [];
  final compras = [
    for (final registro in await ref.watch(registrosProvider.future))
      if (registro is CompraAlimento) registro,
  ];
  return marcasConCompras(
    await ref.watch(repositorioRegistrosProvider).marcas(granja.id),
    compras,
  );
});

/// El nombre con que se muestra la marca de una compra: el de la lista si la
/// compra ya está amarrada a una marca, o el que se escribió al comprar.
final nombreDeMarcaProvider = Provider<String Function(CompraAlimento)>((ref) {
  final nombres = {
    for (final m in ref.watch(marcasProvider).asData?.value ?? const <MarcaConCompras>[])
      m.marca.id: m.marca.nombre,
  };
  return (compra) => nombres[compra.marcaId] ?? compra.marca;
});

/// Las cuentas de un lote, abierto o cerrado.
final cuentasDeLoteProvider = Provider.family<CuentasLote?, String>((ref, loteId) {
  final lote = (ref.watch(lotesProvider).asData?.value ?? const <Lote>[])
      .where((l) => l.id == loteId)
      .firstOrNull;
  final registros = ref.watch(registrosProvider).asData?.value;
  if (lote == null || registros == null) return null;
  return CuentasLote(lote, registros);
});

/// Los lotes cerrados de la granja con sus cuentas, el cerrado más reciente
/// primero.
final lotesCerradosProvider = FutureProvider<List<CuentasLote>>((ref) async {
  final lotes = await ref.watch(lotesProvider.future);
  final registros = await ref.watch(registrosProvider.future);
  return [
    for (final lote in lotes)
      if (!lote.abierto) CuentasLote(lote, registros),
  ]..sort((a, b) => b.lote.cerradoEn!.compareTo(a.lote.cerradoEn!));
});

/// El nombre de cada galpón por su id, incluidos los que ya no tienen lote.
final nombresDeGalponesProvider = Provider<Map<String, String>>(
  (ref) => {
    for (final g in ref.watch(galponesProvider).asData?.value ?? const <GalponConLote>[])
      g.galpon.id: g.galpon.nombre,
  },
);

/// El nombre de cada cliente por su id.
final nombresDeClientesProvider = Provider<Map<String, String>>(
  (ref) => {
    for (final c in ref.watch(cuentasClientesProvider).asData?.value ?? const <CuentaCliente>[])
      c.cliente.id: c.cliente.nombre,
  },
);
