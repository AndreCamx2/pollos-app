# Cambios

Cada versión corresponde a una parte del proyecto. El número de la derecha del
`+` en `pubspec.yaml` sube con cada APK que se instala.

## 1.5.0 · Por dentro

- Cuando hay una versión más nueva publicada en GitHub, la app avisa en
  Galpones y lleva a la página para descargarla.
- Lo que anotan los demás baja cada tres minutos con la app abierta, sin
  tener que salir y volver a entrar.
- GitHub revisa el código y corre las pruebas de la app en cada cambio
  (`.github/workflows/app.yml`).
- Los errores de la app se reportan a Sentry si `SENTRY_DSN` está en el
  archivo de claves; sin él, la app corre igual y no reporta.

## 1.4.0 · Recordatorios

- El celular avisa a las 7 de la mañana el día 22 de cada lote, para pasar a
  alimento de engorde, y el día 45, para vender. Les llega a todos los de la
  granja, con la app cerrada y sin señal.
- Si ya se compró engorde, el aviso del día 22 no sale. Un lote cerrado deja
  de avisar.
- Android: sube a AGP 9.1.1 y compila con Android 37, que es lo que piden
  los avisos.

## 1.3.0 · Cierre en PDF

- El cierre de un lote, o cómo va uno abierto, sale en una hoja en PDF con la
  ganancia, la inversión, los pollos, los indicadores y a quién se le vendió.
  Se envía por WhatsApp o por donde se quiera desde el menú de compartir.
- El resumen en texto sigue ahí.

## 1.2.0 · Cuenta

- Cada persona cambia su contraseña desde Personas, sin pedírsela al dueño.
- El dueño y los administradores ven los códigos de invitación sin usar y
  anulan el que ya no haga falta.
- El dueño y los administradores cambian el nombre de la granja.

## 1.1.0 · Cartera

- Cada cliente puede tener un cupo de fiado. Si una venta fiada lo pasa, la
  app avisa en cuánto, pero deja guardarla. El cliente muestra cuánto cupo le
  queda.
- Al fiarle a un cliente no recurrente sale un aviso.
- Desde el cliente se le escribe por WhatsApp o se le llama. Si debe, el
  mensaje ya lleva el saldo escrito.
- Base de datos: migración `20261116000000_cupo_de_fiado.sql`.

## 1.0.1 · Arreglos y calendario

- La fecha se elige en un calendario: se toca y sale el mes completo. Las
  flechas de un día siguen ahí para lo de ayer.
- Si el servidor está caído u ocupado, los cambios esperan y suben solos
  después, en vez de quedar como "no se pudo subir".
- La app ya no se daña si una versión más nueva estrena una causa de muerte,
  un tipo de alimento o un rol que esta no conoce.
- La primera vez se guarda primero la contraseña y después el nombre, para
  que nadie se quede con la contraseña que le dio el dueño.
- Cerrar sesión o salir de la granja avisa si hay cambios sin subir.
- En libras, kilos y metros el punto de miles se lee bien: 1.250 son mil
  doscientas cincuenta, no una y cuarto.
- Los campos vuelven a mostrar un ejemplo corto ("Ej.: 500") en vez de una
  frase, y en un gris más claro para que no parezca un dato ya escrito.
- Con la letra del celular grande, los botones, la barra de abajo y la fecha
  crecen en vez de cortarse. La letra de la app sube hasta un 30 %.
- Las fechas de otro año dicen el año, y después de una semana ya no dicen
  "hace tantos días".
- El gallo aparece mientras carga cada pantalla, en vez de la rueda gris o un
  instante en blanco.
- Base de datos: migración `20261115000000_no_borrar_en_lote_cerrado.sql`.
  En un lote cerrado tampoco se puede borrar lo anotado sin reabrirlo.

## 1.0.0 · Lista para usar con datos reales

- Entrada nueva con el gallo de la app: cada error sale debajo de su campo, el
  correo se revisa antes de mandarlo y hay mensajes claros para contraseña
  equivocada, falta de señal y demasiados intentos.
- La primera vez, la contraseña nueva se escribe dos veces, las dos con el
  ojo para verla, y la lista de requisitos se marca mientras se escribe.
- El gallo es el ícono de la app en el celular.
- El gallo acompaña la app: firma el encabezado, canta mientras carga y sobre
  un lote con ganancia, duerme en las pantallas vacías y pone cara de duda en
  los errores. La app abre en el maíz con el gallo, sin el instante en blanco.
- Iconos con el trazo más firme, listas desplegables en blanco con la flecha en
  un círculo, Personas con el encabezado de la granja y la pantalla sin granja
  con el del gallo.
- El resumen que se comparte termina con "Hecho con Mis pollos".
- El dueño cambia el rol de cada persona o la saca de la granja, y cualquiera
  puede salirse. Siempre queda al menos un dueño.
- La app recuerda la última granja elegida.
- Los campos dicen qué ingresar en vez de mostrar ejemplos.
- Ya no aparece por un instante la pantalla de unirse a una granja al entrar.
- Firma propia del APK y guía para pasar a producción en el README.
- Base de datos: migración `20261114000000_solo_cambiar_rol.sql`.

## 0.6.0 · Cierres

- Al cerrar un lote, los pollos tienen que cuadrar: si en las cuentas quedan
  vivos, la app pregunta si se murieron, si faltan (robados, perdidos o mal
  contados) o si todavía hay pollos. Los faltantes se anotan aparte de la
  mortalidad.
- Cierre del lote: cuánto ganaste o perdiste, cómo fue el lote, la inversión
  desglosada, indicadores (peso promedio, conversión alimenticia, costo y
  ganancia por pollo), por qué se murieron y a quién le vendiste. Con
  comparación contra tus otros lotes del año.
- "Ver cómo va": el mismo reporte para un lote abierto.
- Pestaña Cierres: lo ganado en el año, los últimos 6 meses o todo, con una
  gráfica de ganancia por lote y la lista de lotes cerrados.
- Compartir el resumen del lote por WhatsApp u otra app.
- Base de datos: migración `20261113000000_faltantes.sql`.

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
