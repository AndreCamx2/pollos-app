import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/movimiento.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/errores.dart';
import '../../../../compartido/formato.dart';
import '../../dominio/granja.dart';

class PantallaPersonas extends ConsumerWidget {
  const PantallaPersonas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    if (granja == null) return const Scaffold();
    final miId = ref.watch(usuarioIdProvider);
    final miembros = ref.watch(miembrosProvider(granja.id));
    final cuantos = miembros.asData?.value.length;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          EncabezadoMaiz(
            child: TitularPantalla(
              titulo: 'Personas',
              subtitulo: cuantos == null
                  ? granja.nombre
                  : '${granja.nombre} · $cuantos ${cuantos == 1 ? 'persona' : 'personas'}',
            ),
          ),
          ...miembros.when<List<Widget>>(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (error, _) => [
              EstadoError(
                error: error,
                alReintentar: () => ref.invalidate(miembrosProvider(granja.id)),
              ),
            ],
            data: (miembros) => [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: ColoresGranja.papel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ColoresGranja.borde),
                      ),
                      child: Column(
                        children: [
                          for (final (i, miembro) in miembros.indexed) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: ColoresGranja.borde,
                              ),
                            _FilaMiembro(
                              miembro: miembro,
                              soyYo: miembro.usuarioId == miId,
                              alTocar: granja.rol == Rol.dueno && miembro.usuarioId != miId
                                  ? () => showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        sheetAnimationStyle: animacionDeHoja,
                                        builder: (_) =>
                                            _HojaMiembro(granja: granja, miembro: miembro),
                                      )
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (granja.rol == Rol.dueno && miembros.length > 1) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Toca a una persona para cambiarle el rol o sacarla de la granja.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (granja.rol.administra) ...[
                      const SizedBox(height: 24),
                      BotonPrincipal(
                        texto: 'Invitar a alguien',
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          sheetAnimationStyle: const AnimationStyle(
                            curve: Curvas.hoja,
                            duration: Duration(milliseconds: 280),
                            reverseDuration: Duration(milliseconds: 220),
                          ),
                          builder: (_) => _HojaInvitar(granjaId: granja.id),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: () => _salir(context, ref, granja),
                        style: TextButton.styleFrom(foregroundColor: ColoresGranja.granero),
                        child: const Text('Salir de esta granja'),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                        child: const Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _salir(BuildContext context, WidgetRef ref, Granja granja) async {
  final sale = await confirmar(
    context,
    titulo: '¿Salir de ${granja.nombre}?',
    detalle: 'Dejarás de ver sus galpones y sus cuentas. Para volver vas a '
        'necesitar un código nuevo.',
    accion: 'Salir de la granja',
  );
  if (!sale) return;
  final db = ref.read(supabaseProvider);
  try {
    await db
        .from('miembros')
        .delete()
        .eq('granja_id', granja.id)
        .eq('usuario_id', db.auth.currentUser!.id);
    ref.invalidate(misGranjasProvider);
    if (context.mounted) Navigator.maybePop(context);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
    }
  }
}

class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({required this.miembro, required this.soyYo, this.alTocar});

  final Miembro miembro;
  final bool soyYo;

  /// Solo el dueño lo tiene, para cambiar el rol o sacar a la persona.
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final nombre = miembro.nombre;
    return Pulsable(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: ColoresGranja.maizClaro,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: nombre == null
                      ? const Icon(Icons.person_outline_rounded, color: ColoresGranja.textoSobreMaiz)
                      : Text(
                          iniciales(nombre),
                          style: conPeso(
                            textos.bodyMedium!.copyWith(color: ColoresGranja.textoSobreMaiz),
                            700,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre == null
                        ? 'Aún no ha entrado'
                        : soyYo
                            ? '$nombre (tú)'
                            : nombre,
                    style: textos.titleMedium,
                    maxLines: 2,
                  ),
                  Text(miembro.rol.etiqueta, style: textos.bodySmall),
                ],
              ),
            ),
            if (alTocar != null)
              const Icon(Icons.chevron_right_rounded, color: ColoresGranja.tintaSuave),
          ],
        ),
      ),
    );
  }
}

const _queHace = {
  Rol.dueno: 'Puede todo, incluido cambiar roles, sacar personas y borrar la granja.',
  Rol.administrador: 'Maneja galpones y lotes, cierra lotes e invita personas.',
  Rol.trabajador: 'Registra alimento, muertos, medicina, ventas, clientes y abonos.',
};

class _HojaMiembro extends ConsumerStatefulWidget {
  const _HojaMiembro({required this.granja, required this.miembro});

  final Granja granja;
  final Miembro miembro;

  @override
  ConsumerState<_HojaMiembro> createState() => _HojaMiembroState();
}

class _HojaMiembroState extends ConsumerState<_HojaMiembro> {
  late var _rol = widget.miembro.rol;
  var _guardando = false;
  String? _error;

  String get _nombre => widget.miembro.nombre ?? 'esta persona';

  Future<void> _hacer(Future<List<Map<String, dynamic>>> Function() cambio) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final filas = await cambio();
      // Sin filas es que la política no lo dejó: quizás ya no es dueño.
      if (filas.isEmpty) throw const _SinPermiso();
      ref.invalidate(miembrosProvider(widget.granja.id));
      if (mounted) Navigator.pop(context);
    } on _SinPermiso {
      if (mounted) setState(() => _error = 'Solo el dueño puede cambiar a las personas.');
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  PostgrestFilterBuilder<T> _fila<T>(PostgrestFilterBuilder<T> consulta) => consulta
      .eq('granja_id', widget.granja.id)
      .eq('usuario_id', widget.miembro.usuarioId);

  Future<void> _sacar() async {
    final saca = await confirmar(
      context,
      titulo: '¿Sacar a $_nombre?',
      detalle: 'Ya no podrá ver ni anotar nada en ${widget.granja.nombre}. Lo que '
          'registró se queda. Para volver necesitará un código nuevo.',
      accion: 'Sacar de la granja',
    );
    if (!saca) return;
    final db = ref.read(supabaseProvider);
    await _hacer(() => _fila(db.from('miembros').delete()).select());
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final db = ref.read(supabaseProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.miembro.nombre ?? 'Aún no ha entrado', style: textos.titleLarge),
            const SizedBox(height: 12),
            for (final rol in Rol.values) ...[
              _OpcionRol(
                rol: rol,
                ayuda: _queHace[rol]!,
                elegido: _rol,
                alElegir: (rol) => setState(() => _rol = rol),
              ),
              const SizedBox(height: 8),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: 4),
              AvisoError(error),
            ],
            const SizedBox(height: 12),
            BotonPrincipal(
              texto: 'Guardar el rol',
              cargando: _guardando,
              onPressed: _rol == widget.miembro.rol
                  ? null
                  : () => _hacer(
                        () => _fila(db.from('miembros').update({'rol': _rol.name})).select(),
                      ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _guardando ? null : _sacar,
              style: TextButton.styleFrom(foregroundColor: ColoresGranja.granero),
              child: const Text('Sacar de la granja'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinPermiso implements Exception {
  const _SinPermiso();
}

class _HojaInvitar extends ConsumerStatefulWidget {
  const _HojaInvitar({required this.granjaId});

  final String granjaId;

  @override
  ConsumerState<_HojaInvitar> createState() => _HojaInvitarState();
}

class _HojaInvitarState extends ConsumerState<_HojaInvitar> {
  var _rol = Rol.trabajador;
  var _creando = false;
  var _copiado = false;
  String? _codigo;
  String? _error;

  Future<void> _crearCodigo() async {
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      final codigo = await ref.read(supabaseProvider).rpc(
        'crear_invitacion',
        params: {'id_granja': widget.granjaId, 'rol_invitado': _rol.name},
      ) as String;
      if (mounted) setState(() => _codigo = codigo);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  Future<void> _copiar(String codigo) async {
    await Clipboard.setData(ClipboardData(text: codigo));
    if (mounted) setState(() => _copiado = true);
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final codigo = _codigo;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: codigo == null
              ? [
                  Text('¿Qué va a hacer?', style: textos.titleLarge),
                  const SizedBox(height: 12),
                  _OpcionRol(
                    rol: Rol.trabajador,
                    ayuda: _queHace[Rol.trabajador]!,
                    elegido: _rol,
                    alElegir: (rol) => setState(() => _rol = rol),
                  ),
                  const SizedBox(height: 8),
                  _OpcionRol(
                    rol: Rol.administrador,
                    ayuda: _queHace[Rol.administrador]!,
                    elegido: _rol,
                    alElegir: (rol) => setState(() => _rol = rol),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 12),
                    AvisoError(error),
                  ],
                  const SizedBox(height: 20),
                  BotonPrincipal(texto: 'Crear código', cargando: _creando, onPressed: _crearCodigo),
                ]
              : [
                  Text('Pásale este código', style: textos.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Entra a la app y lo escribe en "Unirme con un código". '
                    'Sirve una sola vez y vence en 7 días.',
                    style: textos.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SelectableText(
                      codigo,
                      style: textos.displaySmall!.copyWith(letterSpacing: 6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  BotonPrincipal(
                    texto: _copiado ? 'Copiado' : 'Copiar código',
                    onPressed: () => _copiar(codigo),
                  ),
                ],
        ),
      ),
    );
  }
}

class _OpcionRol extends StatelessWidget {
  const _OpcionRol({
    required this.rol,
    required this.ayuda,
    required this.elegido,
    required this.alElegir,
  });

  final Rol rol;
  final String ayuda;
  final Rol elegido;
  final ValueChanged<Rol> alElegir;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final activo = rol == elegido;
    return Semantics(
      selected: activo,
      inMutuallyExclusiveGroup: true,
      child: Pulsable(
        onTap: () => alElegir(rol),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColoresGranja.papel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: activo ? ColoresGranja.tinta : ColoresGranja.borde,
              width: activo ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(rol.etiqueta, style: textos.titleMedium),
              const SizedBox(height: 2),
              Text(ayuda, style: textos.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
