import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/errores.dart';

class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  var _verClave = false;
  var _entrando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty || _clave.text.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    setState(() {
      _entrando = true;
      _error = null;
    });
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(email: correo, password: _clave.text);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            children: [
              Text('Mis pollos', style: textos.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Entra con el correo y la contraseña que te dio el dueño de la granja.',
                style: textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _correo,
                decoration: const InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _clave,
                obscureText: !_verClave,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  suffixIcon: IconButton(
                    tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(
                      _verClave
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _verClave = !_verClave),
                  ),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                AvisoError(error),
              ],
              const SizedBox(height: 24),
              BotonPrincipal(texto: 'Entrar', cargando: _entrando, onPressed: _entrar),
            ],
          ),
        ),
      ),
    );
  }
}
