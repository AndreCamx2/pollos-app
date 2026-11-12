# Mis pollos

App para llevar las cuentas de una granja de pollos de engorde: galpones,
lotes, alimento, muertos, medicina, ventas, fiados y el cierre de cada lote.
Funciona sin señal y sube los datos a Supabase cuando hay internet.

Flutter + Supabase. El código está organizado por módulos en `lib/modulos/`
(dominio, puertos, aplicación y adaptadores); lo común va en `lib/compartido/`.
Qué trae cada versión está en `CHANGELOG.md` y la base de datos en
`supabase/README.md`.

Más documentación en `docs/`:

- [Arquitectura](docs/arquitectura.md): módulos, capas y cómo trabaja sin señal.
- [Diseño](docs/diseno.md): colores, letras, widgets de marca y el gallo.
- [Publicar una versión](docs/publicar-una-version.md): de la rama al APK en el Release.
- [Diagramas](docs/diagramas.md): módulos, sincronización sin señal, modelo de datos, pantallas, vida de un lote y publicación.

## Correr la app en desarrollo

1. Copia `.env.example` como `.env.json` y pon la URL y la clave publicable
   del proyecto `pollos-dev` (Supabase → Project Settings → API Keys).
2. `flutter pub get`
3. `flutter run --dart-define-from-file=.env.json`

Pruebas: `flutter analyze` y `flutter test`. Las reglas de la base de datos
se prueban con `supabase/tests/reglas_del_negocio.sql`.

## Pasar a producción

Se hace una sola vez. Los datos reales van en un proyecto aparte de
`pollos-dev`, para poder probar sin dañar nada.

`pollos-dev` no va conectado a GitHub: ahí se pega a mano cada migración nueva
para probarla antes de fusionar.

### 1. El proyecto de Supabase

1. En Supabase crea el proyecto `pollos-app`. Como región elige
   *South America (São Paulo)*, la más cercana a Colombia. Guarda la contraseña
   de la base de datos en un lugar seguro.
2. Antes de correr cualquier migración, conecta el proyecto con GitHub:
   *Project Settings* → *Integrations* → *GitHub* → elige `AndreCamx2/pollos-app`,
   *Working directory* `.`, *Deploy to production* encendido y *Automatic
   branching* apagado (las ramas de vista previa se cobran). Desde ahí, cada
   merge a `main` aplica solo las migraciones nuevas de `supabase/migrations/`.
   Supabase anota cuáles ya aplicó; por eso no se pegan a mano en este
   proyecto, porque las que entran por el SQL Editor no quedan anotadas y la
   integración las intentaría correr otra vez.
3. *Authentication* → *Sign In / Providers*: deja *Email* y *Confirm email*
   activos y apaga *Allow new users to sign up*.
4. Crea las cuentas de la familia como dice `supabase/README.md` (*Add user*
   con *Auto Confirm User*).

### 2. Las claves de producción

Copia `.env.example` como `.env.produccion.json` con la URL y la clave
publicable de `pollos-app`. Git no sube ese archivo.

### 3. La llave para firmar el APK

Con esta llave Android reconoce que una actualización es de la misma app. Si se
pierde, la app nueva no se instala encima de la vieja y toca desinstalar.
Guarda una copia del archivo `.jks` y de sus claves fuera del PC.

1. Crea la llave (keytool viene con Android Studio):

   ```
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool" -genkey -v -keystore C:\Users\andre\claves\pollos-firma.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias pollos
   ```

2. Copia `android/key.properties.example` como `android/key.properties` y pon
   las dos claves que elegiste. Git no sube ese archivo ni la llave.

### 4. El APK

```
flutter build apk --release --dart-define-from-file=.env.produccion.json
```

El APK queda en `build\app\outputs\flutter-apk\app-release.apk`. Súbelo al
Release de la versión en GitHub y pásalo a cada celular. En un celular que
tenía la versión de pruebas hay que desinstalarla primero, porque está firmada
con otra llave y apunta a `pollos-dev`.

### 5. El respaldo

El flujo *Respaldo de Supabase* (`.github/workflows/respaldo-supabase.yml`)
saca una copia cifrada cada 3 días y de paso evita que Supabase pause el
proyecto por no usarse.

1. En GitHub: *Settings* → *Secrets and variables* → *Actions* → *New
   repository secret*:
   - `SUPABASE_DB_URL`: en Supabase, *Connect* → *Session pooler*, la cadena
     de conexión de `pollos-app` con la contraseña de la base de datos.
   - `CLAVE_RESPALDO`: una frase larga que solo tú sepas. Sin ella la copia
     no se puede abrir.
2. *Actions* → *Respaldo de Supabase* → *Run workflow*. Al terminar, la copia
   aparece en *Artifacts* de esa corrida.
