# Base de datos

El esquema vive en `migrations/`. Cada cambio futuro va en un archivo nuevo con
fecha en el nombre; los archivos que ya se aplicaron no se editan.

## Aplicarlo en Supabase

1. Crea dos proyectos: `pollos-dev` para probar y `pollos-app` para los datos reales.
2. En cada uno: *SQL Editor* → *New query* → pega el contenido de
   `migrations/20261110000000_esquema_inicial.sql` → *Run*.
3. En *Authentication* → *Sign In / Providers*:
   - Deja activo *Email* y también *Confirm email*.
   - Apaga *Allow new users to sign up*. Así nadie crea cuenta por su cuenta;
     las cuentas las creas tú (siguiente sección).

Con la [CLI de Supabase](https://supabase.com/docs/guides/cli) el paso 2 es
`supabase link --project-ref <id>` y luego `supabase db push`.

## Quién puede entrar

Los registros públicos están cerrados, así que cada cuenta la creas tú, tanto
la de un dueño nuevo como la de un trabajador:

1. *Authentication* → *Users* → *Add user* → *Create new user*.
2. Escribe el correo y una contraseña temporal y marca *Auto Confirm User*.
3. Pásale el correo y la contraseña a la persona por un canal privado.

Después, en la app:

- Un **dueño nuevo** entra y crea su granja. Cada granja ve solo sus datos.
- Un **trabajador o administrador** entra y escribe el código que le dio el
  dueño de su granja.

Para abrir una granja más, solo creas la cuenta de su dueño.

## Roles

| Rol | Qué puede hacer |
| --- | --- |
| dueno | Todo, incluido cambiar roles, sacar personas y borrar la granja |
| administrador | Crear y editar galpones y lotes, cerrar lotes, invitar personas, editar cualquier registro |
| trabajador | Registrar alimento, muertos, medicina, ventas, clientes y abonos; editar o borrar solo lo que él registró |

El dueño o un administrador llama `crear_invitacion(granja, 'trabajador')` y
comparte el código de 8 letras. La otra persona llama `unirse_con_codigo(codigo)`.
El código sirve una sola vez y vence a los 7 días.

## Respaldos

El plan gratis de Supabase no guarda copias. El flujo
`.github/workflows/respaldo-supabase.yml` saca una copia cifrada cada 3 días y
GitHub la guarda 90 días (pestaña *Actions* → *Respaldo de Supabase* → la
ejecución → *Artifacts*). La consulta también evita que Supabase pause el
proyecto.

Para activarlo, en GitHub: *Settings* → *Secrets and variables* → *Actions* →
*New repository secret*:

- `SUPABASE_DB_URL`: en Supabase, botón *Connect* → *Session pooler*, con la
  contraseña de la base puesta en lugar de `[YOUR-PASSWORD]`.
- `CLAVE_RESPALDO`: una frase larga que inventes. Guárdala también en tu gestor
  de contraseñas o en papel: sin ella las copias no se pueden abrir.

Luego, en *Actions* → *Respaldo de Supabase* → *Run workflow*, córrelo una vez
para comprobar que sale una copia.

### Restaurar una copia

Desde *Git Bash* (viene con Git para Windows y trae `gpg`):

```
unzip respaldo-pollos-AAAA-MM-DD.zip
gpg -d respaldo-pollos-AAAA-MM-DD.tar.gz.gpg | tar xzf -
psql --single-transaction --variable ON_ERROR_STOP=1 \
  --file roles.sql --file esquema.sql \
  --command 'SET session_replication_role = replica' \
  --file datos.sql \
  --dbname "<cadena de conexión del proyecto donde restauras>"
```

Restaura en un proyecto vacío, nunca encima de los datos reales. Hazlo una vez
en `pollos-dev` apenas tengas la primera copia: un respaldo que nunca se probó
no se sabe si sirve.

## Pruebas

`tests/reglas_del_negocio.sql` revisa las reglas que la base de datos hace
cumplir: que una granja no vea a otra, que no se vendan pollos de más, que los
abonos no pasen de la deuda, qué puede hacer un trabajador, las invitaciones y
el cierre de lotes. Corre dentro de una transacción que se deshace al final.

GitHub las corre solas en cada push que toque `supabase/` (pestaña *Actions*,
flujo *Base de datos*). Para correrlas a mano contra `pollos-dev` hace falta
`psql`:

```
psql "<cadena de conexión de pollos-dev>" -v ON_ERROR_STOP=1 -f supabase/tests/reglas_del_negocio.sql
```

La última línea debe decir `TODAS LAS PRUEBAS PASARON`.
