import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/proveedores.dart';
import 'app/rutas.dart';
import 'compartido/diseno/tema.dart';
import 'compartido/local/base_local.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _clave = String.fromEnvironment('SUPABASE_KEY');

Future<void> main() async {
  if (_url.isEmpty || _clave.isEmpty) {
    throw StateError(
      'Faltan las claves de Supabase. Corre la app con '
      '--dart-define-from-file=.env.json (mira .env.example).',
    );
  }
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
    return MaterialApp.router(
      title: 'Mis pollos',
      theme: temaGranja(),
      routerConfig: ref.watch(rutasProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
