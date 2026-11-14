import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/proveedores.dart';
import 'app/recordatorios.dart';
import 'app/rutas.dart';
import 'compartido/diseno/tema.dart';
import 'compartido/local/base_local.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _clave = String.fromEnvironment('SUPABASE_KEY');

// La dirección de Sentry a donde llegan los errores de la app. Sin ella la
// app corre igual y no reporta nada.
const _sentry = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_url.isEmpty || _clave.isEmpty) {
    throw StateError(
      'Faltan las claves de Supabase. Corre la app con '
      '--dart-define-from-file=.env.json (mira .env.example).',
    );
  }
  if (_sentry.isEmpty) return _arrancar();
  await SentryFlutter.init((opciones) => opciones.dsn = _sentry, appRunner: _arrancar);
}

Future<void> _arrancar() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _url, publishableKey: _clave);
  final baseLocal = await BaseLocal.abrir();
  runApp(
    ProviderScope(
      overrides: [baseLocalProvider.overrideWithValue(baseLocal)],
      child: const AppPollos(),
    ),
  );
}

class AppPollos extends ConsumerWidget {
  const AppPollos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(recordatoriosProvider);
    return MaterialApp.router(
      title: 'Mis pollos',
      theme: temaGranja(),
      routerConfig: ref.watch(rutasProvider),
      debugShowCheckedModeBanner: false,
      // La letra crece con la del celular hasta un 30 %. Más arriba las
      // cifras grandes y las tarjetas dejan de caber en pantallas angostas.
      builder: (context, pantalla) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: pantalla!,
      ),
    );
  }
}
