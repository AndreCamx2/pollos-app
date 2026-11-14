import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../modulos/lotes/dominio/recordatorios.dart';
import 'proveedores.dart';

const _canal = NotificationDetails(
  android: AndroidNotificationDetails(
    'lotes',
    'Recordatorios de los lotes',
    channelDescription: 'El día de pasar a engorde y el día de vender.',
    importance: Importance.high,
    priority: Priority.high,
  ),
);

/// Deja programados en el celular los avisos de los lotes abiertos. Quedan
/// guardados en Android, así que suenan aunque la app esté cerrada y no
/// haya señal.
class _Programador {
  final _avisos = FlutterLocalNotificationsPlugin();
  var _listo = false;

  /// Borra lo que había y programa [recordatorios]: así un lote que se cerró
  /// o al que ya se le compró engorde deja de avisar.
  Future<void> programar(List<Recordatorio> recordatorios) async {
    if (!_listo) {
      await _avisos.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_aviso'),
        ),
      );
      _listo = true;
    }
    if (recordatorios.isNotEmpty) {
      await _avisos
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    await _avisos.cancelAll();
    for (final (numero, recordatorio) in recordatorios.indexed) {
      // La hora va como instante en UTC: es la misma de la granja sin tener
      // que cargar la tabla de zonas horarias.
      final cuando = recordatorio.cuando.toUtc();
      await _avisos.zonedSchedule(
        id: numero,
        title: recordatorio.titulo,
        body: recordatorio.texto,
        scheduledDate: tz.TZDateTime.utc(
          cuando.year,
          cuando.month,
          cuando.day,
          cuando.hour,
          cuando.minute,
        ),
        notificationDetails: _canal,
        // Con unos minutos de margen basta, y así no hace falta el permiso
        // de alarmas exactas.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}

/// Vuelve a programar los recordatorios cada vez que cambian los lotes de la
/// granja que está abierta: al abrir uno, al cerrarlo o al comprar engorde.
final recordatoriosProvider = Provider<void>((ref) {
  final programador = _Programador();
  ref.listen(
    galponesProvider,
    (_, galpones) async {
      final cargados = galpones.asData?.value;
      if (cargados == null) return;
      final ahora = DateTime.now();
      try {
        await programador.programar([
          for (final (:galpon, :lote, :cuentas) in cargados)
            if (lote != null && cuentas != null)
              ...recordatoriosDe(
                lote,
                galpon: galpon.nombre,
                yaComproEngorde: cuentas.primerEngorde != null,
                ahora: ahora,
              ),
        ]);
      } on Exception {
        // Sin recordatorios la app sigue sirviendo: no se molesta a nadie
        // por un celular que no deja programarlos.
      }
    },
    fireImmediately: true,
  );
});
