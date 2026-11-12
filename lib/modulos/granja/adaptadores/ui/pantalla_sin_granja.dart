import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/errores.dart';

class PantallaSinGranja extends ConsumerWidget {
  const PantallaSinGranja({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          children: [
            Text('Todavía no tienes granja', style: textos.displaySmall),
            const SizedBox(height: 24),
            _Opcion(
              titulo: 'Crear mi granja',
              ayuda: 'Si eres el dueño. Después invitas a tu gente.',
              etiqueta: 'Nombre de la granja',
              boton: 'Crear granja',
              siVacio: 'Escribe el nombre de la granja.',
              enviar: (db, nombre) async =>
                  await db.rpc('crear_granja', params: {'nombre_granja': nombre})
                      as String,
            ),
            const SizedBox(height: 16),
            _Opcion(
              titulo: 'Unirme con un código',
              ayuda: 'El dueño o el administrador te lo da desde Personas.',
              etiqueta: 'Código de 8 letras',
              boton: 'Unirme',
              siVacio: 'Escribe el código que te dieron.',
              esCodigo: true,
              enviar: (db, codigo) async =>
                  await db.rpc('unirse_con_codigo', params: {'codigo_recibido': codigo})
                      as String,
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                child: const Text('Salir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Opcion extends ConsumerStatefulWidget {
  const _Opcion({
    required this.titulo,
    required this.ayuda,
    required this.etiqueta,
    required this.boton,
    required this.siVacio,
    required this.enviar,
    this.esCodigo = false,
  });

  final String titulo;
  final String ayuda;
  final String etiqueta;
  final String boton;
  final String siVacio;
  final bool esCodigo;

  /// Devuelve el id de la granja a la que quedó la persona.
  final Future<String> Function(SupabaseClient db, String valor) enviar;

  @override
  ConsumerState<_Opcion> createState() => _OpcionState();
}

class _OpcionState extends ConsumerState<_Opcion> {
  final _campo = TextEditingController();
  var _enviando = false;
  String? _error;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final valor = _campo.text.trim();
    if (valor.isEmpty) {
      setState(() => _error = widget.siVacio);
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final granjaId = await widget.enviar(ref.read(supabaseProvider), valor);
      ref.read(granjaElegidaProvider.notifier).elegir(granjaId);
      ref.invalidate(misGranjasProvider);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.titulo, style: textos.titleLarge),
          const SizedBox(height: 4),
          Text(widget.ayuda, style: textos.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _campo,
            decoration: InputDecoration(labelText: widget.etiqueta),
            textCapitalization: widget.esCodigo
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            autocorrect: !widget.esCodigo,
            maxLength: widget.esCodigo ? 8 : null,
            onSubmitted: (_) => _enviar(),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 8),
            AvisoError(error),
          ],
          const SizedBox(height: 16),
          BotonPrincipal(texto: widget.boton, cargando: _enviando, onPressed: _enviar),
        ],
      ),
    );
  }
}
