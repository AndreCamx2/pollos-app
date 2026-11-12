# Cambios

Cada versión corresponde a una parte del proyecto. El número de la derecha del
`+` en `pubspec.yaml` sube con cada APK que se instala.

## 0.5.2 · Arreglo

- La 0.5.1 no compilaba: la lista de formatos de los campos de cantidades
  estaba marcada como constante sin poder serlo.

## 0.5.1 · Marcas de alimento y validaciones

- Marcas de alimento como lista propia: se eligen en un menú desplegable al
  comprar, se crean ahí mismo y se corrigen o borran (una marca con compras
  no se borra; se marca "Ya no la uso" y pasa al final). Al elegirla se
  ponen sus kilos por bulto y el precio de su última compra. Corregir el
  nombre de una marca lo corrige en todas sus compras.
- Avisos de cifra rara: si un precio se aleja mucho de lo normal en la
  granja (un cero de más o de menos), la app pide revisarlo. No bloquea.
- Topes para errores de dedo: pollitos, bultos, kilos, libras, metros y
  precios con un máximo razonable.
- Al salir de un formulario con algo escrito, pregunta antes de descartarlo.
- El error aparece en rojo en el campo que está mal.
- Aviso si se va a anotar algo que ya se anotó el mismo día en el lote.
- Celular del cliente: 10 números que empiecen por 3.
- Un abono no puede tener fecha anterior a la primera venta fiada.
- Base de datos: migración `20261112000000_marcas_y_fechas.sql` (lista de
  marcas a partir de las compras que ya había, y ninguna fecha más de un día
  en el futuro, por si el reloj del celular está corrido).

## 0.5.0 · Clientes, ventas y fiado

- Barra de abajo para pasar entre Galpones y Clientes.
- Clientes: crear, corregir y borrar (solo si no tiene ventas ni abonos).
  Cada uno muestra cuánto debe o si está al día, y al tocarlo sus ventas y
  abonos. Arriba, lo que te deben en total.
- Cliente no recurrente: para quien compró una vez. Va al final de las
  listas en vez de borrarlo, así no se pierden sus ventas.
- Nueva venta desde el galpón: cliente en un menú desplegable (con opción de
  crearlo ahí mismo), pollos, libras, precio por libra, contado o fiado. Se
  llena con el precio de la última venta a ese cliente.
- Abonos: cuánto pagó, quién recibió la plata y cuánto queda debiendo.
- El galpón muestra los vendidos reales, lo vendido y cuánto falta para
  recuperar lo invertido. La entrada muestra lo que te deben.
- Reglas: no vender más pollos de los vivos; un abono no pasa de la deuda;
  una venta ya abonada no se borra ni se pasa a contado; aviso si las libras
  por pollo salen raras.
- Base de datos: migración `20261111000000_clientes_no_recurrentes.sql`.

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
