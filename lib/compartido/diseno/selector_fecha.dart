import 'package:flutter/material.dart';

import '../formato.dart';
import 'colores.dart';
import 'espacios.dart';
import 'movimiento.dart';
import 'pulsable.dart';
import 'tema.dart';

DateTime _soloDia(DateTime fecha) => DateTime(fecha.year, fecha.month, fecha.day);

/// Casi todo se anota el mismo día o pocos días después: las flechas mueven
/// la fecha de a un día, y al tocarla se abre el calendario para ir a
/// cualquier otra.
class SelectorFecha extends StatelessWidget {
  const SelectorFecha({
    super.key,
    required this.fecha,
    required this.alCambiar,
    this.desde,
  });

  final DateTime fecha;
  final ValueChanged<DateTime> alCambiar;

  /// La fecha más antigua que se puede elegir, por ejemplo la llegada del lote.
  final DateTime? desde;

  @override
  Widget build(BuildContext context) {
    final hoy = _soloDia(DateTime.now());
    final elegida = _soloDia(fecha);
    final haceDias = hoy.difference(elegida).inDays;
    final limite = desde == null ? null : _soloDia(desde!);
    final puedeAntes = limite == null || elegida.isAfter(limite);
    final corta = fechaCorta(elegida);

    Future<void> abrirCalendario() async {
      final nueva = await showModalBottomSheet<DateTime>(
        context: context,
        isScrollControlled: true,
        sheetAnimationStyle: animacionDeHoja,
        builder: (_) => _HojaCalendario(elegida: elegida, desde: limite, hasta: hoy),
      );
      if (nueva != null) alCambiar(nueva);
    }

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioCampo),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Un día antes',
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            onPressed: puedeAntes
                ? () => alCambiar(DateTime(elegida.year, elegida.month, elegida.day - 1))
                : null,
          ),
          Expanded(
            child: Semantics(
              label: 'Abrir el calendario',
              child: Pulsable(
                onTap: abrirCalendario,
                child: SizedBox.expand(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: ColoresGranja.tintaSuave,
                      ),
                      const SizedBox(width: e8),
                      Flexible(
                        child: Text(
                          switch (haceDias) {
                            0 => 'Hoy, $corta',
                            1 => 'Ayer, $corta',
                            _ => '$corta · hace $haceDias días',
                          },
                          overflow: TextOverflow.ellipsis,
                          style: conPeso(Theme.of(context).textTheme.bodyLarge!, 700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Un día después',
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            onPressed: haceDias <= 0
                ? null
                : () => alCambiar(DateTime(elegida.year, elegida.month, elegida.day + 1)),
          ),
        ],
      ),
    );
  }
}

/// El mes completo para tocar el día. Los días de antes de [desde] y los de
/// después de [hasta] salen apagados.
class _HojaCalendario extends StatefulWidget {
  const _HojaCalendario({required this.elegida, required this.hasta, this.desde});

  final DateTime elegida;
  final DateTime hasta;
  final DateTime? desde;

  @override
  State<_HojaCalendario> createState() => _HojaCalendarioState();
}

class _HojaCalendarioState extends State<_HojaCalendario> {
  late var _mes = DateTime(widget.elegida.year, widget.elegida.month);

  void _irA(int meses) => setState(() => _mes = DateTime(_mes.year, _mes.month + meses));

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final desde = widget.desde;
    final hasta = widget.hasta;
    final diasDelMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    // La semana empieza en lunes.
    final huecos = _mes.weekday - 1;
    final hayAntes = desde == null || _mes.isAfter(DateTime(desde.year, desde.month));
    final hayDespues = _mes.isBefore(DateTime(hasta.year, hasta.month));
    final nombre = mesLargo(_mes);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(e16, 0, e16, e16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  icon: const Icon(Icons.chevron_left_rounded, size: 28),
                  onPressed: hayAntes ? () => _irA(-1) : null,
                ),
                Expanded(
                  child: Text(
                    '${nombre[0].toUpperCase()}${nombre.substring(1)} ${_mes.year}',
                    textAlign: TextAlign.center,
                    style: textos.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  icon: const Icon(Icons.chevron_right_rounded, size: 28),
                  onPressed: hayDespues ? () => _irA(1) : null,
                ),
              ],
            ),
            const SizedBox(height: e8),
            Row(
              children: [
                for (final dia in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Text(dia, textAlign: TextAlign.center, style: textos.labelLarge),
                  ),
              ],
            ),
            const SizedBox(height: e4),
            // Siempre seis semanas, para que la hoja no cambie de alto al
            // pasar de un mes a otro.
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var casilla = 0; casilla < 42; casilla++)
                  if (casilla < huecos || casilla >= huecos + diasDelMes)
                    const SizedBox()
                  else
                    _dia(DateTime(_mes.year, _mes.month, casilla - huecos + 1), textos),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dia(DateTime dia, TextTheme textos) {
    final desde = widget.desde;
    final sePuede = !dia.isAfter(widget.hasta) && (desde == null || !dia.isBefore(desde));
    final esElegido = dia == widget.elegida;
    final esHoy = dia == widget.hasta;
    return Pulsable(
      onTap: sePuede ? () => Navigator.pop(context, dia) : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: esElegido ? ColoresGranja.granero : null,
          shape: BoxShape.circle,
          border: esHoy && !esElegido
              ? Border.all(color: ColoresGranja.granero, width: 2)
              : null,
        ),
        child: Text(
          '${dia.day}',
          style: conPeso(
            textos.bodyLarge!.copyWith(
              color: esElegido
                  ? ColoresGranja.papel
                  : sePuede
                      ? ColoresGranja.tinta
                      : ColoresGranja.textoSobreTinta,
            ),
            esElegido || esHoy ? 700 : 500,
          ),
        ),
      ),
    );
  }
}
