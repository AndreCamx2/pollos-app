// DOMINIO: los avisos que el celular le da a la granja en los días que
// importan de un lote, en Dart puro.

import 'lote.dart';

/// Un aviso que el celular muestra un día a una hora, haya señal o no.
typedef Recordatorio = ({DateTime cuando, String titulo, String texto});

/// La hora del aviso: temprano, antes de la primera ronda por el galpón.
const horaDelRecordatorio = 7;

/// Los avisos que le faltan a un lote abierto: el día 22 para pasar a
/// alimento de engorde, si todavía no se ha comprado, y el día 45 para
/// vender. Solo los que caen después de [ahora].
List<Recordatorio> recordatoriosDe(
  Lote lote, {
  required String galpon,
  required bool yaComproEngorde,
  required DateTime ahora,
}) {
  if (!lote.abierto) return const [];
  DateTime aLas7(DateTime dia) => DateTime(dia.year, dia.month, dia.day, horaDelRecordatorio);
  return [
    if (!yaComproEngorde)
      (
        cuando: aLas7(lote.fechaCambioAEngorde),
        titulo: '$galpon: toca pasar a engorde',
        texto: 'El lote cumple 22 días hoy. Desde ahora el alimento es de engorde.',
      ),
    (
      cuando: aLas7(lote.fechaDeVenta),
      titulo: '$galpon: el lote ya está para vender',
      texto: 'Cumple 45 días hoy. Es buen momento para ofrecerlo a tus clientes.',
    ),
  ].where((recordatorio) => recordatorio.cuando.isAfter(ahora)).toList();
}
