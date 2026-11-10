# Cambios

Cada versión corresponde a una parte del proyecto. El número de la derecha del
`+` en `pubspec.yaml` sube con cada APK que se instala.

## 0.4.0 · Lo diario del lote

- Anotar compras de alimento (inicio o engorde, marca, bultos, kilos y precio),
  pollos muertos (cuántos, causa y nota) y medicina (qué, cuánto costó y cómo
  se da). Todo funciona sin señal.
- El detalle del galpón muestra vivos, muertos y mortalidad de verdad, lo
  invertido separado en pollitos, alimento y medicina, y los últimos
  movimientos. Tocar uno deja corregirlo o borrarlo.
- Avisa que toca cambiar a engorde hasta que se anota la primera compra.
- Reglas: nada antes de la llegada del lote, en el futuro ni en un lote
  cerrado; no más muertos que vivos; el trabajador solo corrige lo suyo; un
  lote con registros no se borra.
- La cola de cambios sube en el orden exacto en que se hicieron: cerrar un
  lote llega después de lo que se anotó en él.

## 0.3.0 · Galpones y lotes sin señal

- Galpones: agregar, corregir y borrar (solo si nunca tuvo lotes).
- Lotes: recibir pollitos en un galpón libre, corregir, cerrar y reabrir. Un
  galpón tiene un solo lote abierto.
- La app guarda todo en el celular y lo sube cuando hay internet. Arriba dice
  si está al día, sin señal o con cambios por subir, y muestra lo que el
  servidor no aceptó para corregirlo o descartarlo.
- Después de entrar una vez, la app abre sin señal.
- Base de datos: migración `20261110010000_trabajar_sin_senal.sql`.

## 0.2.0 · Entrar y granjas

- Entrar con correo y contraseña, completar el nombre y cambiar la contraseña
  temporal.
- Crear una granja o unirse con un código de invitación.
- Personas de la granja e invitaciones con rol.
- Tema de la granja: colores, letras y botones propios.

## 0.1.0 · Base de datos

- Esquema de Supabase con granjas, roles, invitaciones y reglas del negocio.
- Pruebas de las reglas en cada cambio y respaldo cifrado cada 3 días.
