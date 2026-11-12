# Publicar una versión

Para la primera vez en producción, ver la sección "Pasar a producción" del
`README.md`. Esto es lo de cada versión nueva.

1. Rama desde `main`. Los cambios van con su entrada en `CHANGELOG.md` y la
   versión nueva en `pubspec.yaml`: `X.Y.Z+N`, donde `N` siempre sube.
2. `flutter analyze` y `flutter test` limpios.
3. Si hay migración nueva: archivo nuevo en `supabase/migrations/`, su prueba
   en `supabase/tests/reglas_del_negocio.sql`, y pegarla a mano en `pollos-dev`.
   En `pollos-app` nunca se pega: entra sola al fusionar.
4. Probar en el celular contra `pollos-dev`:
   `flutter run --dart-define-from-file=.env.json`.
5. Push, PR y merge con "Create a merge commit".
6. Etiqueta, después de bajar el merge:
   ```
   git checkout main
   git pull
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
   Si el pull se frena por `pubspec.lock`: `git checkout -- pubspec.lock`.
7. APK de producción, firmado con la llave de `android/key.properties`:
   ```
   flutter build apk --release --dart-define-from-file=.env.produccion.json
   ```
   Queda en `build/app/outputs/flutter-apk/app-release.apk`; se sube como
   `Mis-Pollos-X.Y.Z.apk`.
8. Release en GitHub con la etiqueta, la sección del CHANGELOG y el APK.
9. Instalar: `flutter install --release` por USB, o el APK por WhatsApp. Se
   instala encima de la versión anterior mientras la firma sea la misma.
