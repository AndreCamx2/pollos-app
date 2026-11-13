# Diseño

Identidad "Granero" con el gallo de la app. Los valores exactos viven en
`lib/compartido/diseno/`; en las pantallas no se escriben colores, espacios ni
radios sueltos.

## Colores (`ColoresGranja`)

Cada color significa siempre lo mismo.

| Token | Uso |
| --- | --- |
| `maiz` `#F2B632` | Encabezados, cifras sobre la tarjeta oscura, etapa de inicio |
| `granero` `#A3401F` | Acción principal y lo que sale: muertos, deuda, pérdida |
| `pasto` `#2F6B3A` | Lo que entra: abonos, ganancia, "al día" |
| `tinta` `#2B211A` | Texto y tarjeta oscura |
| `crema` `#FBF5EC` | Fondo |
| `lila` `#B9A8F2` | Solo medicina |
| `cresta` `#D63A22`, `pico` `#F08A24` | Solo el gallo |

## Letras

Bricolage Grotesque para títulos y cifras, Figtree para el texto, empacadas en
`assets/fuentes/`. Son variables: los pesos van con `conPeso()`, no con
`fontWeight` solo. Las cifras usan dígitos tabulares.

## Widgets de marca

| Widget | Para qué |
| --- | --- |
| `EncabezadoMaiz` + `TitularPantalla` | Franja amarilla con los galpones al fondo y botón de volver |
| `EncabezadoGranja` | Fecha, nombre de la granja y el gallo como firma en el cuadro oscuro |
| `TarjetaTicket`, `CifraTicket` | La tarjeta oscura con la cifra que importa |
| `BarraEtapa` | Avance de inicio a engorde |
| `IconoModulo` (`Figura`) | Iconos propios con trazo de 2,6 |
| `CampoGranja` | Campo con etiqueta arriba; `clave: true` pone el ojo para ver la contraseña |
| `FlechaDeLista` | Flecha de las listas desplegables, en un círculo maíz claro |
| `FichasOpcion`, `SelectorFecha` | Elegir entre opciones y fechas |
| `BotonPrincipal`, `BotonSecundario`, `Pulsable` | Botones y zonas que se tocan |
| `AvisoError`, `AvisoAtencion`, `EstadoError` | Errores y avisos |
| `FormularioGranja`, `ProtegerCambios` | Errores por campo y "¿Descartar lo que escribiste?" |
| `confirmar()` | Hoja para confirmar algo que cuesta deshacer |

## El gallo

`Gallo(gesto:, contorno:)` se dibuja con código (`compartido/diseno/gallo.dart`),
no con imágenes:

| Gesto | Dónde |
| --- | --- |
| `normal` | Entrada, firma del encabezado (con `contorno: crema` sobre el cuadro oscuro) |
| `cantando` | `GalloCantando` en la carga; sobre la tarjeta de un lote cerrado con ganancia |
| `dormido` | Pantallas vacías: galpones, clientes y cierres |
| `duda` | `EstadoError` |

El ícono de Android y la pantalla de arranque son PNG generados con el mismo
dibujo (`android/app/src/main/res/`): ícono adaptable con fondo maíz y, desde
Android 12, `values-v31/styles.xml`.

## Textos

- Español de Colombia, tuteo, como habla el dueño: "Te deben", "Toca cambiar a alimento de engorde".
- Plata `$1.248.000`, fechas "10 oct", libras con coma `245,5 lb`.
- Los campos dicen qué ingresar ("Ingresa el precio por libra"), no ejemplos.
- Sin emojis ni signos de celebración.
