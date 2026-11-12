import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/errores.dart';

/// La primera vez que alguien entra: escribe su nombre y cambia la contraseña
/// temporal que le dio el dueño.
class PantallaCompletarCuenta extends ConsumerStatefulWidget {
  const PantallaCompletarCuenta({super.key});

  @override
  ConsumerState<PantallaCompletarCuenta> createState() =>
      _PantallaCompletarCuentaState();
}

class _PantallaCompletarCuentaState
    extends ConsumerState<PantallaCompletarCuenta> {
  final _nombre = TextEditingController();
  final _clave = TextEditingController();
  var _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe tu nombre.');
      return;
    }
    if (_clave.text.length < 8) {
      setState(() => _error = 'La contraseña nueva necesita al menos 8 caracteres.');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final db = ref.read(supabaseProvider);
      // Primero el perfil (upsert) y al final la contraseña: si algo falla,
      // la persona puede volver a tocar Guardar sin chocar con lo que ya quedó.
      await db
          .from('perfiles')
          .upsert({'id': db.auth.currentUser!.id, 'nombre': nombre});
      await db.auth.updateUser(UserAttributes(password: _clave.text));
      ref.invalidate(miNombreProvider);
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          children: [
            Text('¿Cómo te llamas?', style: textos.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Así te verán los demás en la granja. Cambia también la contraseña '
              'que te dieron por una que solo sepas tú.',
              style: textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Tu nombre'),
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clave,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _guardar(),
              decoration: const InputDecoration(
                labelText: 'Contraseña nueva',
                helperText: 'Mínimo 8 caracteres',
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              AvisoError(error),
            ],
            const SizedBox(height: 24),
            BotonPrincipal(texto: 'Guardar', cargando: _guardando, onPressed: _guardar),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                child: const Text('No soy yo, salir'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
