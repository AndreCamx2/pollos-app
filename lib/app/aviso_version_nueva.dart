import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../compartido/diseno/espacios.dart';
import '../compartido/diseno/estado_error.dart';
import '../compartido/diseno/pulsable.dart';
import '../compartido/version.dart';

/// [pagina] es la del Release en GitHub, donde está el APK para descargar.
typedef VersionNueva = ({String version, Uri pagina});

/// La última versión publicada, si es más nueva que la instalada. Se
/// pregunta una vez al abrir la app; sin señal o si GitHub no responde, no
/// se avisa nada.
final versionNuevaProvider = FutureProvider<VersionNueva?>((ref) async {
  try {
    final respuesta = await http
        .get(
          Uri.https('api.github.com', '/repos/AndreCamx2/pollos-app/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 8));
    if (respuesta.statusCode != 200) return null;
    final publicada = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final etiqueta = publicada['tag_name'] as String? ?? '';
    final pagina = Uri.tryParse(publicada['html_url'] as String? ?? '');
    if (pagina == null || !esMasNueva(etiqueta, versionDeLaApp)) return null;
    return (version: etiqueta.replaceFirst(RegExp('^v'), ''), pagina: pagina);
  } on Exception {
    return null;
  }
});

class AvisoVersionNueva extends ConsumerWidget {
  const AvisoVersionNueva({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nueva = ref.watch(versionNuevaProvider).asData?.value;
    if (nueva == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(e16, e8, e16, 0),
      child: Pulsable(
        onTap: () => launchUrl(nueva.pagina, mode: LaunchMode.externalApplication),
        child: AvisoAtencion(
          'Hay una versión nueva de Mis pollos (${nueva.version}). Toca para descargarla.',
        ),
      ),
    );
  }
}
