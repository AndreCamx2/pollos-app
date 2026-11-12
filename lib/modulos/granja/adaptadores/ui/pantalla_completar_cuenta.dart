import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/proveedores.dart';
import '../../../../compartido/diseno/campo.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/gallo.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/errores.dart';
import '../../dominio/cuenta.dart';
import 'encabezado_gallo.dart';
import 'pantalla_entrar.dart';

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
  final _repetida = TextEditingController();
  var _guardando = false;
  String? _errorNombre;
  String? _errorClave;
  String? _errorRepetida;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() {
      if (_errorNombre != null) setState(() => _errorNombre = null);
    });
    // La lista de requisitos se va marcando mientras escribe.
    _clave.addListener(() => setState(() => _errorClave = null));
    _repetida.addListener(() {
      if (_errorRepetida != null) setState(() => _errorRepetida = null);
    });
  }

  @override
  void dispose() {
    _nombre.dispose();
    _clave.dispose();
    _repetida.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _errorNombre = errorDeNombre(_nombre.text);
      _errorClave = errorDeClaveNueva(_clave.text);
      _errorRepetida = _errorClave == null
          ? errorDeClaveRepetida(_clave.text, _repetida.text)
          : null;
      _error = null;
    });
    if (_errorNombre != null || _errorClave != null || _errorRepetida != null) return;

    setState(() => _guardando = true);
    try {
      final db = ref.read(supabaseProvider);
      final nombre = _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      // Primero el perfil (upsert) y al final la contraseña: si algo falla,
      // la persona puede volver a tocar Guardar sin chocar con lo que ya quedó.
      await db
          .from('perfiles')
          .upsert({'id': db.auth.currentUser!.id, 'nombre': nombre});
      await db.auth.updateUser(UserAttributes(password: _clave.text));
      TextInput.finishAutofillContext();
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
    final requisitos = requisitosDeClave(_clave.text);
    return Scaffold(
      body: AutofillGroup(
        child: ListView(
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
                        Text('¿Cómo te llamas?', style: textos.headlineSmall),
                        Text(
                          'Es la primera vez que entras',
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
              padding: const EdgeInsets.fromLTRB(e24, e16, e24, e24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Así te verán los demás en la granja. Cambia también la contraseña '
                    'que te dieron por una que solo sepas tú.',
                    style: textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: e16),
                    AvisoDeEntrada(error),
                  ],
                  const SizedBox(height: e20),
                  CampoGranja(
                    etiqueta: 'Tu nombre',
                    controller: _nombre,
                    pista: 'Ingresa tu nombre',
                    mayusculas: TextCapitalization.words,
                    autollenado: const [AutofillHints.name],
                    accionTeclado: TextInputAction.next,
                    error: _errorNombre,
                  ),
                  const SizedBox(height: e16),
                  CampoGranja(
                    etiqueta: 'Contraseña nueva',
                    controller: _clave,
                    pista: 'Ingresa la contraseña nueva',
                    clave: true,
                    autollenado: const [AutofillHints.newPassword],
                    accionTeclado: TextInputAction.next,
                    error: _errorClave,
                  ),
                  const SizedBox(height: e16),
                  CampoGranja(
                    etiqueta: 'Escríbela otra vez',
                    controller: _repetida,
                    pista: 'Repite la contraseña nueva',
                    clave: true,
                    autollenado: const [AutofillHints.newPassword],
                    accionTeclado: TextInputAction.done,
                    alTerminar: (_) => _guardar(),
                    error: _errorRepetida,
                  ),
                  const SizedBox(height: e12),
                  _Requisito('Al menos 8 letras o números', cumple: requisitos.largo),
                  const SizedBox(height: e8),
                  _Requisito('Tiene letras y números', cumple: requisitos.letrasYNumeros),
                  const SizedBox(height: e24),
                  BotonPrincipal(texto: 'Guardar', cargando: _guardando, onPressed: _guardar),
                  const SizedBox(height: e12),
                  Center(
                    child: TextButton(
                      onPressed: () => ref.read(supabaseProvider).auth.signOut(),
                      child: const Text('No soy yo, salir'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Requisito extends StatelessWidget {
  const _Requisito(this.texto, {required this.cumple});

  final String texto;
  final bool cumple;

  @override
  Widget build(BuildContext context) {
    final color = cumple ? ColoresGranja.pasto : ColoresGranja.tintaSuave;
    return Semantics(
      label: '$texto: ${cumple ? 'cumple' : 'falta'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            cumple ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: e8),
          Expanded(
            child: Text(
              texto,
              style: conPeso(
                Theme.of(context).textTheme.bodyMedium!.copyWith(color: color),
                cumple ? 700 : 500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
