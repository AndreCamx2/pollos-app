# Arquitectura

Cómo está armado el código de Mis pollos. Las reglas del negocio están en
`supabase/README.md` (roles) y en el dominio de cada módulo.

## Capas por módulo

El código se organiza por módulos de negocio en `lib/modulos/`. Cada módulo
tiene, según lo que necesite:

| Carpeta | Qué va ahí |
| --- | --- |
| `dominio/` | Las reglas en Dart puro, sin Flutter ni Supabase. Aquí se prueban casi todas las reglas. |
| `puertos/` | Las interfaces que el dominio necesita (por ejemplo `RepositorioLotes`). |
| `aplicacion/` | Casos de uso que juntan varias piezas (`CrearLote`). |
| `adaptadores/local/` | Repositorios que guardan en la base del celular. |
| `adaptadores/ui/` | Pantallas. |

Módulos:

- `granja`: entrar, completar la cuenta, crear o unirse a una granja, personas y roles. Llama a Supabase directo porque necesita internet.
- `galpones`: galpones y el detalle del galpón con su lote.
- `lotes`: lotes, edad y etapa del alimento.
- `registros`: alimento, marcas, muertos, medicina y ventas, más `CuentasLote`, que calcula todo lo del lote (vivos, invertido, ganancia, conversión…).
- `clientes`: clientes, abonos y lo que debe cada uno.
- `cierres`: reporte del lote y la pestaña Cierres por periodo.

Lo común está en `lib/compartido/`: `diseno/` (widgets de marca), `local/`
(base del celular), `sincronizacion/`, `formato.dart`, `fechas.dart`,
`cifras.dart` (topes y avisos de cifras raras) y `errores.dart` (convierte
cualquier error en una frase para la persona).

`lib/app/` une las piezas: `proveedores.dart` (Riverpod), `rutas.dart`
(go_router, decide a qué pantalla ir según la sesión, el nombre y las
granjas), `sincronizacion.dart` y la barra de secciones.

## Sin señal primero

```
Pantalla → Repositorio → SQLite del celular ⇄ Sincronizador ⇄ Supabase
```

- `BaseLocal` (sqflite, versión 4) guarda las tablas del negocio
  (`columnasLocales`: galpones, lotes, clientes, marcas, compras_alimento,
  mortalidad, medicamentos, ventas y abonos), la cola `pendientes` y
  `datos_guardados` (lo último que se bajó de cuentas y granjas, para abrir sin
  señal).
- Cada cambio se guarda en la tabla local y entra a `pendientes` con la fila
  como quedó. Se sube en el mismo orden.
- `Sincronizador.sincronizar()` primero sube la cola y después baja lo que
  cambió en Supabase desde la última vez (`cambiado_en`, con 5 minutos de
  margen) y lo que se borró (tabla `borrados`).
- `Sincronizacion` (en `lib/app/`) lo corre al abrir la app, al volver a ella,
  después de cada cambio (`huboCambios()`) y cada 30 segundos mientras quede
  algo por subir.
- Si Supabase rechaza un cambio, queda marcado como rechazado con el motivo y
  la app muestra "N cambios no se pudieron subir". La persona lo corrige o lo
  descarta, y se vuelve a lo que tiene el servidor.
- Los booleanos se guardan como 1/0 en SQLite y se convierten al subir
  (`columnasSiNo`).

Cuando cambian las columnas de una tabla local hay que subir la versión de
`BaseLocal` y agregar el paso en `actualizarTablas`.

## Reglas en dos capas

El dominio en Dart da el mensaje amable antes de guardar. Supabase hace cumplir
la regla de verdad con RLS por granja y triggers, porque un dato puede llegar
tarde desde un celular que estuvo sin señal. Las excepciones de dominio traen
el `campo` para mostrar el error debajo del campo correcto.

## Base de datos

- Migraciones en `supabase/migrations/`, una por cambio; las aplicadas no se editan.
- `pollos-dev`: se prueba cada migración a mano. `pollos-app`: conectado a
  GitHub, aplica las migraciones al fusionar en `main`.
- `supabase/tests/reglas_del_negocio.sql` prueba las reglas; el flujo
  "Base de datos" lo corre en cada PR.
