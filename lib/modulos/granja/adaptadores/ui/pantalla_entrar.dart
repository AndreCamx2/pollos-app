import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class PantallaEntrar extends ConsumerStatefulWidget {
  const PantallaEntrar({super.key});

  @override
  ConsumerState<PantallaEntrar> createState() => _PantallaEntrarState();
}

class _PantallaEntrarState extends ConsumerState<PantallaEntrar> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  var _entrando = false;
  String? _errorCorreo;
  String? _errorClave;
  String? _error;

  @override
  void initState() {
    super.initState();
    _correo.addListener(() {
      if (_errorCorreo != null) setState(() => _errorCorreo = null);
    });
    _clave.addListener(() {
      if (_errorClave != null) setState(() => _errorClave = null);
    });
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_entrando) return;
    final correo = _correo.text.trim();
    setState(() {
      _errorCorreo = errorDeCorreo(correo);
      _errorClave = _clave.text.isEmpty ? 'Escribe tu contraseña.' : null;
      _error = null;
    });
    if (_errorCorreo != null || _errorClave != null) return;

    setState(() => _entrando = true);
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(email: correo.toLowerCase(), password: _clave.text);
      TextInput.finishAutofillContext();
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
      body: AutofillGroup(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            EncabezadoGallo(
              child: Column(
                children: [
                  const SizedBox(height: e24),
                  const Gallo(),
                  const SizedBox(height: e12),
                  Text('Mis pollos', style: textos.displaySmall, textAlign: TextAlign.center),
                  const SizedBox(height: e8),
                  Text(
                    'La cuenta clara de tu granja',
                    textAlign: TextAlign.center,
                    style: conPeso(
                      textos.bodyLarge!.copyWith(color: ColoresGranja.textoSobreMaiz),
                      600,
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
                  if (_error case final error?) ...[
                    AvisoDeEntrada(error),
                    const SizedBox(height: e16),
                  ] else ...[
                    Text(
                      'Entra con el correo y la contraseña que te dio el dueño de la granja.',
                      style: textos.bodyLarge!.copyWith(color: ColoresGranja.tintaSuave),
                    ),
                    const SizedBox(height: e20),
                  ],
                  CampoGranja(
                    etiqueta: 'Correo',
                    controller: _correo,
                    pista: 'Ingresa tu correo',
                    teclado: TextInputType.emailAddress,
                    autollenado: const [AutofillHints.email],
                    accionTeclado: TextInputAction.next,
                    error: _errorCorreo,
                  ),
                  const SizedBox(height: e16),
                  CampoGranja(
                    etiqueta: 'Contraseña',
                    controller: _clave,
                    pista: 'Ingresa tu contraseña',
                    clave: true,
                    autollenado: const [AutofillHints.password],
                    accionTeclado: TextInputAction.done,
                    alTerminar: (_) => _entrar(),
                    error: _errorClave,
                  ),
                  const SizedBox(height: e24),
                  BotonPrincipal(texto: 'Entrar', cargando: _entrando, onPressed: _entrar),
                  const SizedBox(height: e16),
                  Text(
                    '¿Se te olvidó la contraseña? Pídele al dueño de la granja que te dé una nueva.',
                    textAlign: TextAlign.center,
                    style: textos.bodyMedium!.copyWith(color: ColoresGranja.tintaSuave),
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

/// El error de Supabase al entrar o al guardar la cuenta, en una caja que se
/// ve aunque la persona no esté mirando un campo.
class AvisoDeEntrada extends StatelessWidget {
  const AvisoDeEntrada(this.mensaje, {super.key});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: e12),
        decoration: BoxDecoration(
          color: ColoresGranja.graneroClaro,
          borderRadius: BorderRadius.circular(radioCampo),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: ColoresGranja.granero, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mensaje,
                style: conPeso(
                  Theme.of(context).textTheme.bodyMedium!.copyWith(color: ColoresGranja.granero),
                  600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
