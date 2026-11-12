import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/gallo.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/errores.dart';
import 'encabezado_gallo.dart';

class PantallaSinGranja extends ConsumerWidget {
  const PantallaSinGranja({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          EncabezadoGallo(
            child: Row(
              children: [
                const Gallo(tamano: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Todavía no tienes granja', style: textos.headlineSmall),
                      Text(
                        'Crea la tuya o únete a una',
                        style: conPeso(
                          textos.bodyMedium!.copyWith(color: ColoresGranja.textoSobreMaiz),
                          600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Opcion(
                  titulo: 'Crear mi granja',
                  ayuda: 'Si eres el dueño. Después invitas a tu gente.',
                  etiqueta: 'Nombre de la granja',
                  pista: 'Ingresa el nombre de la granja',
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
                  pista: 'Ingresa el código',
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
        ],
      ),
    );
  }
}

class _Opcion extends ConsumerStatefulWidget {
  const _Opcion({
    required this.titulo,
    required this.ayuda,
    required this.etiqueta,
    required this.pista,
    required this.boton,
    required this.siVacio,
    required this.enviar,
    this.esCodigo = false,
  });

  final String titulo;
  final String ayuda;
  final String etiqueta;
  final String pista;
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
          CampoGranja(
            etiqueta: widget.etiqueta,
            controller: _campo,
            pista: widget.pista,
            mayusculas: widget.esCodigo
                ? TextCapitalization.characters
                : TextCapitalization.sentences,
            formatos: widget.esCodigo ? [LengthLimitingTextInputFormatter(8)] : null,
            alTerminar: (_) => _enviar(),
            error: _error,
          ),
          const SizedBox(height: 16),
          BotonPrincipal(texto: widget.boton, cargando: _enviando, onPressed: _enviar),
        ],
      ),
    );
  }
}
