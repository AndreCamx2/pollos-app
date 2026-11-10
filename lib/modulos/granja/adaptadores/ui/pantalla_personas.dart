import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/movimiento.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/errores.dart';
import '../../dominio/granja.dart';

class PantallaPersonas extends ConsumerWidget {
  const PantallaPersonas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granja = ref.watch(granjaActualProvider);
    if (granja == null) return const Scaffold();
    final miId = ref.watch(usuarioIdProvider);
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Personas')),
      body: ref.watch(miembrosProvider(granja.id)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EstadoError(
              error: error,
              alReintentar: () => ref.invalidate(miembrosProvider(granja.id)),
            ),
            data: (miembros) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(granja.nombre.toUpperCase(), style: textos.labelLarge),
                const SizedBox(height: 8),
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
                        _FilaMiembro(miembro: miembro, soyYo: miembro.usuarioId == miId),
                      ],
                    ],
                  ),
                ),
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
                    onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({required this.miembro, required this.soyYo});

  final Miembro miembro;
  final bool soyYo;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final nombre = miembro.nombre;
    return Padding(
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
        ],
      ),
    );
  }
}

/// "María José Peñaloza" -> "MP"; "Jo" -> "J".
String iniciales(String nombre) {
  final palabras = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (palabras.isEmpty) return '';
  final primera = palabras.first.characters.first;
  final ultima = palabras.length > 1 ? palabras.last.characters.first : '';
  return (primera + ultima).toUpperCase();
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
                    ayuda: 'Registra alimento, muertos, medicina, ventas, clientes y abonos.',
                    elegido: _rol,
                    alElegir: (rol) => setState(() => _rol = rol),
                  ),
                  const SizedBox(height: 8),
                  _OpcionRol(
                    rol: Rol.administrador,
                    ayuda: 'Además maneja galpones y lotes, cierra lotes e invita personas.',
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
