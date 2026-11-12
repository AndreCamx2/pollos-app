# Diagramas

GitHub dibuja estos diagramas solos (Mermaid). Son texto: cuando cambie el
código, se corrigen aquí en la misma rama.

1. [Módulos y capas](#1-módulos-y-capas)
2. [Cómo trabaja sin señal](#2-cómo-trabaja-sin-señal)
3. [Modelo de datos](#3-modelo-de-datos)
4. [A qué pantalla entra cada persona](#4-a-qué-pantalla-entra-cada-persona)
5. [Pantallas](#5-pantallas)
6. [Vida de un lote](#6-vida-de-un-lote)
7. [De un cambio al celular](#7-de-un-cambio-al-celular)

## 1. Módulos y capas

Cada módulo de negocio tiene su dominio en Dart puro y sus adaptadores. Las
pantallas nunca hablan con Supabase directo, salvo el módulo `granja`, que
necesita internet de todos modos. Detalle en [arquitectura.md](arquitectura.md).

```mermaid
flowchart TB
  subgraph app["lib/app"]
    rutas["rutas.dart<br/>go_router"]
    prov["proveedores.dart<br/>Riverpod"]
    sinc["sincronizacion.dart"]
  end

  subgraph modulos["lib/modulos"]
    direction LR
    granja["granja<br/>cuentas, personas, roles"]
    galpones["galpones"]
    lotes["lotes"]
    registros["registros<br/>alimento, marcas, muertos,<br/>medicina, ventas, CuentasLote"]
    clientes["clientes<br/>clientes y abonos"]
    cierres["cierres<br/>reporte y periodos"]
  end

  subgraph capas["Dentro de cada módulo"]
    direction LR
    ui["adaptadores/ui<br/>pantallas"] --> aplicacion["aplicacion<br/>casos de uso"]
    ui --> dominio["dominio<br/>reglas en Dart puro"]
    aplicacion --> dominio
    aplicacion --> puertos["puertos<br/>interfaces"]
    local["adaptadores/local<br/>repositorios"] -. implementa .-> puertos
  end

  subgraph compartido["lib/compartido"]
    direction LR
    diseno["diseno<br/>widgets de marca y el gallo"]
    base["local<br/>BaseLocal (sqflite)"]
    sincro["sincronizacion<br/>Sincronizador, Remoto"]
    utiles["formato, fechas,<br/>cifras, errores"]
  end

  rutas --> modulos
  prov --> modulos
  modulos --> compartido
  local --> base
  sinc --> sincro
  sincro --> base
  sincro --> supa[("Supabase")]
  granja --> supa
```

## 2. Cómo trabaja sin señal

Todo se guarda primero en el celular. El sincronizador sube la cola en orden y
después baja lo que cambiaron los demás.

```mermaid
sequenceDiagram
  autonumber
  actor P as Persona
  participant UI as Pantalla
  participant R as Repositorio
  participant L as BaseLocal (SQLite)
  participant S as Sincronizador
  participant DB as Supabase

  P->>UI: Guarda una venta
  UI->>R: guardar(venta)
  R->>R: Reglas del dominio<br/>(no más pollos de los vivos)
  R->>L: Escribe la fila y la pone en pendientes
  UI->>S: huboCambios()

  alt Hay señal
    loop Cada pendiente, en orden
      S->>DB: guardar o borrar la fila
      alt Supabase la acepta
        DB-->>S: ok
        S->>L: Quita el pendiente
      else Supabase la rechaza (otra venta ganó los pollos)
        DB-->>S: error con el motivo
        S->>L: La marca como rechazada
        Note over UI: "1 cambio no se pudo subir.<br/>Toca para revisar"
      end
    end
    S->>DB: ¿Qué cambió desde la última vez?<br/>(cambiado_en y borrados)
    DB-->>S: Filas nuevas, editadas y borradas
    S->>L: Las guarda en el celular
  else Sin señal
    Note over S,L: La cola queda igual.<br/>Se reintenta al volver a la app<br/>y cada 30 segundos.
  end
```

## 3. Modelo de datos

Todas las tablas del negocio llevan `granja_id`, y las reglas por fila (RLS)
solo muestran las de las granjas de la persona. Además tienen `creado_por`,
`creado_en`, `actualizado_por`, `actualizado_en` y `cambiado_en`, que no se
repiten en el diagrama.

```mermaid
erDiagram
  granjas ||--o{ miembros : tiene
  perfiles ||--o{ miembros : "es"
  granjas ||--o{ invitaciones : crea
  granjas ||--o{ galpones : tiene
  granjas ||--o{ marcas : tiene
  granjas ||--o{ clientes : tiene
  galpones ||--o{ lotes : "aloja (uno abierto)"
  lotes ||--o{ compras_alimento : recibe
  marcas ||--o{ compras_alimento : "de la marca"
  lotes ||--o{ mortalidad : registra
  lotes ||--o{ medicamentos : registra
  lotes ||--o{ ventas : vende
  clientes ||--o{ ventas : compra
  clientes ||--o{ abonos : paga

  granjas {
    uuid id PK
    text nombre
  }
  perfiles {
    uuid id PK "usuario de Supabase"
    text nombre
  }
  miembros {
    uuid granja_id PK
    uuid usuario_id PK
    text rol "dueno, administrador, trabajador"
  }
  invitaciones {
    text codigo PK "8 letras"
    uuid granja_id FK
    text rol
    timestamptz vence_en "7 días"
    uuid usada_por
  }
  galpones {
    uuid id PK
    text nombre "único en la granja"
    int capacidad
    numeric largo_m
    numeric ancho_m
    text ubicacion
  }
  lotes {
    uuid id PK
    uuid galpon_id FK
    date fecha_llegada
    int cantidad_inicial
    bigint precio_compra_total
    timestamptz cerrado_en "null si está abierto"
  }
  marcas {
    uuid id PK
    text nombre "único en la granja"
    numeric kilos_por_bulto
    bool en_uso
  }
  compras_alimento {
    uuid id PK
    uuid lote_id FK
    uuid marca_id FK
    date fecha
    text tipo "inicio o engorde"
    int bultos
    numeric kilos_por_bulto
    bigint precio_por_bulto
  }
  mortalidad {
    uuid id PK
    uuid lote_id FK
    date fecha
    int cantidad
    text causa "calor, enfermedad, aplastamiento, otra, faltante"
    text nota
  }
  medicamentos {
    uuid id PK
    uuid lote_id FK
    date fecha
    text nombre
    bigint costo
  }
  clientes {
    uuid id PK
    text nombre
    text detalle
    text telefono
    bigint precio_libra_sugerido
    bool recurrente
  }
  ventas {
    uuid id PK
    uuid lote_id FK
    uuid cliente_id FK
    date fecha
    int pollos
    numeric libras
    bigint precio_libra
    bigint total "libras por precio"
    bool fiado
  }
  abonos {
    uuid id PK
    uuid cliente_id FK
    date fecha
    bigint valor "no más de lo que debe"
    uuid recibido_por
  }
```

La tabla `borrados` (tabla, fila_id, granja_id, borrado_en) anota cada fila que
se borra, para que los celulares que estaban sin señal también la quiten. Las
vistas `resumen_lotes` y `saldo_clientes` calculan los totales en el servidor.

## 4. A qué pantalla entra cada persona

`_destino` en `lib/app/rutas.dart` decide la pantalla cada vez que cambia la
sesión, el nombre o las granjas.

```mermaid
flowchart TD
  inicio([Se abre la app]) --> sesion{¿Ya cargó<br/>la sesión?}
  sesion -- No --> cargando[/cargando<br/>el gallo cantando/]
  sesion -- Sí --> hay{¿Hay sesión?}
  hay -- No --> entrar[/entrar/]
  hay -- Sí --> datos{¿Llegaron nombre<br/>y granjas de esta cuenta?}
  datos -- No --> cargando
  datos -- Sí --> nombre{¿Tiene nombre?}
  nombre -- No --> completar[/completar-cuenta<br/>nombre y contraseña nueva/]
  nombre -- Sí --> granjas{¿Tiene granjas?}
  granjas -- No --> sin[/sin-granja<br/>crear o unirse con código/]
  granjas -- Sí --> galpones[/ Galpones /]

  entrar -. inicia sesión .-> datos
  completar -. guarda .-> datos
  sin -. crea o se une .-> datos
```

## 5. Pantallas

Las tres secciones de la barra de abajo y a dónde se llega desde cada una.

```mermaid
flowchart LR
  subgraph barra["Barra de abajo"]
    G["Galpones /"]
    C["Clientes /clientes"]
    X["Cierres /cierres"]
  end

  G --> P["Personas /personas"]
  G --> GN["Nuevo galpón"]
  G --> GD["Galpón /galpones/:id"]
  GD --> GE["Editar galpón"]
  GD --> LN["Nuevo lote"]
  GD --> LE["Editar lote"]
  GD --> REG["Alimento · Muertos · Medicina · Venta<br/>/lotes/:lote/…"]
  GD --> CL["Cierre del lote<br/>/lotes/:id/cierre"]
  REG --> MA["Nueva o editar marca"]
  REG --> CN["Nuevo cliente"]

  C --> CN
  C --> CE["Editar cliente"]
  C --> AB["Abono /clientes/:id/abono"]

  X --> CL
```

## 6. Vida de un lote

```mermaid
stateDiagram-v2
  [*] --> Inicio: Llegan los pollitos<br/>(nuevo lote en un galpón vacío)
  Inicio --> Engorde: Día 22, la app avisa<br/>hasta que se compra engorde
  Inicio: Alimento de inicio
  Engorde: Alimento de engorde
  Engorde --> Vendiendo: Primera venta, cerca del día 45
  Vendiendo: Vendiendo (ventas, muertos, medicina)
  Vendiendo --> Cuadrar: Cerrar el lote
  Cuadrar: ¿Cuadran los pollos?
  Cuadrar --> Cerrado: Quedan 0 vivos, o los que<br/>quedan se murieron o faltan
  Cuadrar --> Vendiendo: Todavía hay pollos
  Cerrado --> [*]: Reporte, resumen por WhatsApp<br/>y el galpón queda libre
```

## 7. De un cambio al celular

Pasos completos en [publicar-una-version.md](publicar-una-version.md).

```mermaid
flowchart LR
  rama["Rama nueva<br/>y cambios"] --> pruebas["flutter analyze<br/>flutter test"]
  pruebas --> dev["Migración nueva:<br/>a mano en pollos-dev"]
  dev --> pr["Push y PR"]
  pr --> ci{{"GitHub Actions<br/>Base de datos:<br/>migraciones y reglas"}}
  ci -- verde --> merge["Merge a main"]
  merge --> supa[("pollos-app<br/>aplica las migraciones<br/>nuevas solo")]
  merge --> tag["git pull<br/>etiqueta vX.Y.Z"]
  tag --> apk["APK release<br/>firmado con pollos-firma.jks"]
  apk --> release["Release en GitHub<br/>Mis-Pollos-X.Y.Z.apk"]
  release --> cel["Celulares<br/>se instala encima"]
  respaldo{{"Respaldo de Supabase<br/>cada 3 días"}} -.-> supa
```
