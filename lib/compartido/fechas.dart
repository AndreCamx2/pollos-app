/// El día sin la hora y en UTC, para que comparar fechas y contar días no
/// falle por horas o cambios de horario.
DateTime soloFecha(DateTime fecha) =>
    DateTime.utc(fecha.year, fecha.month, fecha.day);

/// Como la guardan las columnas de tipo fecha: "2026-10-10".
String fechaParaBase(DateTime fecha) =>
    soloFecha(fecha).toIso8601String().substring(0, 10);
