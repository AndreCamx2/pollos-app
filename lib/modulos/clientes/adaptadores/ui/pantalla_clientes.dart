import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/aviso_sincronizacion.dart';
import '../../../../app/proveedores.dart';
import '../../../../app/sincronizacion.dart';
import '../../../../compartido/diseno/colores.dart';
import '../../../../compartido/diseno/encabezado_maiz.dart';
import '../../../../compartido/diseno/espacios.dart';
import '../../../../compartido/diseno/estado_error.dart';
import '../../../../compartido/diseno/gallo.dart';
import '../../../../compartido/diseno/hoja_confirmar.dart';
import '../../../../compartido/diseno/pulsable.dart';
import '../../../../compartido/diseno/tarjeta_ticket.dart';
import '../../../../compartido/diseno/tema.dart';
import '../../../../compartido/formato.dart';
import '../../../lotes/dominio/lote.dart';
import '../../../registros/dominio/registro.dart';
import '../../dominio/cliente.dart';

/// Quién te compra y quién te debe.
class PantallaClientes extends ConsumerStatefulWidget {
  const PantallaClientes({super.key});

  @override
  ConsumerState<PantallaClientes> createState() => _PantallaClientesState();
}

class _PantallaClientesState extends ConsumerState<PantallaClientes> {
  final _busqueda = TextEditingController();
  String? _abierto;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final cuentas = ref.watch(cuentasClientesProvider);
    final todas = cuentas.asData?.value ?? const <CuentaCliente>[];
    final buscado = _busqueda.text.trim().toLowerCase();
    final visibles = [
      for (final cuenta in todas)
        if (buscado.isEmpty ||
            cuenta.cliente.nombre.toLowerCase().contains(buscado) ||
            (cuenta.cliente.detalle?.toLowerCase().contains(buscado) ?? false))
          cuenta,
    ];
    final teDeben = todas.fold(0, (suma, c) => suma + (c.alDia ? 0 : c.debe));
    final conFiado = todas.where((c) => !c.alDia).length;
    final primerNoRecurrente = visibles.indexWhere((c) => !c.cliente.recurrente);

    return Scaffold(
      floatingActionButton: _BotonNuevoCliente(
        alTocar: () => context.push('/clientes/nuevo'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          EncabezadoMaiz(
            tarjeta: TarjetaTicket(
              child: CifraTicket(
                etiqueta: 'Te deben en total',
                cifra: plata(teDeben),
                detalle: switch (conFiado) {
                  0 => 'Nadie te debe',
                  1 => '1 cliente con fiado',
                  _ => '$conFiado clientes con fiado',
                },
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clientes', style: textos.headlineSmall),
                Text(
                  'Quién te compra y quién te debe',
                  style: conPeso(
                    textos.bodyMedium!.copyWith(color: ColoresGranja.textoSobreMaiz),
                    600,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(e16, e8, e16, 0),
            child: Align(alignment: Alignment.centerLeft, child: AvisoSincronizacion()),
          ),
          if (todas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, e8, e16, e12),
              child: TextField(
                controller: _busqueda,
                decoration: const InputDecoration(
                  hintText: 'Buscar cliente',
                  prefixIcon: Icon(Icons.search_rounded, color: ColoresGranja.tintaSuave),
                ),
              ),
            ),
          if (cuentas.hasError)
            EstadoError(
              error: cuentas.error!,
              alReintentar: () => ref.invalidate(cuentasClientesProvider),
            )
          else if (todas.isEmpty && cuentas.hasValue)
            const _SinClientes()
          else if (visibles.isEmpty)
            Padding(
              padding: const EdgeInsets.all(e24),
              child: Text(
                'Ningún cliente se llama así. Revisa el nombre o crea uno nuevo.',
                textAlign: TextAlign.center,
                style: textos.bodyMedium!.copyWith(color: ColoresGranja.tintaSuave),
              ),
            ),
          for (final (i, cuenta) in visibles.indexed) ...[
            if (i == primerNoRecurrente)
              Padding(
                padding: const EdgeInsets.fromLTRB(e20, e16, e20, e8),
                child: Text('NO RECURRENTES', style: textos.labelLarge),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(e16, 0, e16, 10),
              child: _TarjetaCliente(
                cuenta: cuenta,
                abierta: _abierto == cuenta.cliente.id,
                alTocar: () => setState(
                  () => _abierto = _abierto == cuenta.cliente.id ? null : cuenta.cliente.id,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaCliente extends ConsumerWidget {
  const _TarjetaCliente({
    required this.cuenta,
    required this.abierta,
    required this.alTocar,
  });

  final CuentaCliente cuenta;
  final bool abierta;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final cliente = cuenta.cliente;
    final precio = cuenta.precioSugerido;
    final datos = [
      ?cliente.detalle,
      if (precio != null) '${plata(precio)} la libra',
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ColoresGranja.papel,
        borderRadius: BorderRadius.circular(radioTarjeta),
        border: Border.all(color: ColoresGranja.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: abierta,
            child: Pulsable(
              onTap: alTocar,
              child: Padding(
                padding: const EdgeInsets.all(e16),
                child: Row(
                  children: [
                    AvatarCliente(cuenta: cuenta),
                    const SizedBox(width: e12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cliente.nombre, style: textos.titleMedium, maxLines: 2),
                          for (final dato in datos)
                            Text(dato, style: textos.bodySmall, maxLines: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: e8),
                    if (cuenta.alDia)
                      const _FichaAlDia()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Debe', style: textos.bodySmall),
                          Text(
                            plata(cuenta.debe),
                            style: textos.titleLarge!.copyWith(color: ColoresGranja.granero),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: abierta ? _DetalleCliente(cuenta: cuenta) : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DetalleCliente extends ConsumerWidget {
  const _DetalleCliente({required this.cuenta});

  final CuentaCliente cuenta;

  static const _cuantos = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textos = Theme.of(context).textTheme;
    final granja = ref.watch(granjaActualProvider);
    final miId = ref.watch(usuarioIdProvider);
    final cliente = cuenta.cliente;
    final ventas = [
      for (final registro in ref.watch(registrosProvider).asData?.value ?? const <Registro>[])
        if (registro is Venta && registro.clienteId == cliente.id) registro,
    ];
    final galponDeLote = {
      for (final lote in ref.watch(lotesProvider).asData?.value ?? const <Lote>[])
        lote.id: lote.galponId,
    };
    final nombreGalpon = {
      for (final g in ref.watch(galponesProvider).asData?.value ?? const <GalponConLote>[])
        g.galpon.id: g.galpon.nombre,
    };
    final nombres = {
      if (granja != null)
        for (final miembro in ref.watch(miembrosProvider(granja.id)).asData?.value ?? const [])
          miembro.usuarioId: ?miembro.nombre,
    };
    final movimientos = <(DateTime, Widget)>[
      for (final venta in ventas)
        (
          venta.fecha,
          _FilaMovimiento(
            titulo: 'Venta · ${fechaCorta(venta.fecha)}',
            detalle: [
              ?nombreGalpon[galponDeLote[venta.loteId]],
              '${venta.pollos} ${venta.pollos == 1 ? 'pollo' : 'pollos'}, ${decimal(venta.libras)} lb',
              if (!venta.fiado) 'contado',
            ].join(' · '),
            valor: plata(venta.total),
          ),
        ),
      for (final abono in cuenta.abonos)
        (
          abono.fecha,
          _FilaMovimiento(
            titulo: 'Abono · ${fechaCorta(abono.fecha)}',
            detalle: switch (abono.recibidoPor) {
              final id? when id == miId => 'Recibiste tú',
              final id? when nombres[id] != null => 'Recibió ${nombres[id]}',
              _ => 'Abono',
            },
            valor: '−${plata(abono.valor)}',
            color: ColoresGranja.pasto,
            alTocar: granja != null &&
                    abono.puedeCambiarlo(administra: granja.rol.administra, usuarioId: miId)
                ? () => context.push('/clientes/${cliente.id}/abono/${abono.id}')
                : null,
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final puedeCorregir = granja != null &&
        cliente.puedeCambiarlo(administra: granja.rol.administra, usuarioId: miId);
    final telefono = cliente.telefono;

    return Padding(
      padding: const EdgeInsets.fromLTRB(e16, 0, e16, e16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (telefono != null)
            Padding(
              padding: const EdgeInsets.only(bottom: e8),
              child: Text('Celular: $telefono', style: textos.bodyMedium),
            ),
          if (movimientos.isEmpty)
            Text('Todavía no le has vendido nada.', style: textos.bodySmall)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: e12, vertical: e4),
              decoration: BoxDecoration(
                color: ColoresGranja.crema,
                borderRadius: BorderRadius.circular(radioCampo),
              ),
              child: Column(
                children: [for (final (_, fila) in movimientos.take(_cuantos)) fila],
              ),
            ),
          if (movimientos.length > _cuantos)
            Padding(
              padding: const EdgeInsets.only(top: e4),
              child: Text(
                'Y ${movimientos.length - _cuantos} movimientos más antiguos.',
                style: textos.bodySmall,
              ),
            ),
          if (!cuenta.alDia) ...[
            const SizedBox(height: e12),
            BotonPrincipal(
              texto: 'Registrar abono',
              onPressed: () => context.push('/clientes/${cliente.id}/abono'),
            ),
          ],
          if (puedeCorregir)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/clientes/${cliente.id}/editar'),
                  child: const Text('Corregir'),
                ),
                const SizedBox(width: e8),
                TextButton(
                  onPressed: () => _borrar(context, ref),
                  child: const Text('Borrar'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

extension on _DetalleCliente {
  /// Un cliente con ventas o abonos no se borra: se ofrece mandarlo al final
  /// de la lista como no recurrente.
  Future<void> _borrar(BuildContext context, WidgetRef ref) async {
    final cliente = cuenta.cliente;
    final repositorio = ref.read(repositorioClientesProvider);
    if (cuenta.sePuedeBorrar) {
      final acepto = await confirmar(
        context,
        titulo: '¿Borrar a ${cliente.nombre}?',
        detalle: 'Desaparece de la lista para todos en la granja. No se puede deshacer.',
        accion: 'Borrar cliente',
      );
      if (!acepto) return;
      await repositorio.borrarCliente(cliente);
    } else {
      final detalle = cuenta.alDia
          ? 'Tiene ventas o abonos anotados y se perderían sus cuentas.'
          : 'Todavía debe ${plata(cuenta.debe)} y tiene ventas anotadas.';
      if (!cliente.recurrente) {
        await confirmar(
          context,
          titulo: 'No se puede borrar a ${cliente.nombre}',
          detalle: '$detalle Ya está al final de la lista como no recurrente.',
          accion: 'Entendido',
        );
        return;
      }
      final acepto = await confirmar(
        context,
        titulo: 'No se puede borrar a ${cliente.nombre}',
        detalle: '$detalle Si ya no te compra, márcalo como no recurrente y pasa al '
            'final de la lista.',
        accion: 'Marcar como no recurrente',
      );
      if (!acepto) return;
      await repositorio.guardarCliente(
        Cliente.reconstruir(
          id: cliente.id,
          granjaId: cliente.granjaId,
          nombre: cliente.nombre,
          detalle: cliente.detalle,
          telefono: cliente.telefono,
          precioLibraSugerido: cliente.precioLibraSugerido,
          recurrente: false,
          creadoPor: cliente.creadoPor,
        ),
      );
    }
    await ref.read(sincronizacionProvider.notifier).huboCambios();
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento({
    required this.titulo,
    required this.detalle,
    required this.valor,
    this.color = ColoresGranja.tinta,
    this.alTocar,
  });

  final String titulo;
  final String detalle;
  final String valor;
  final Color color;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Pulsable(
      onTap: alTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: e8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: conPeso(textos.bodyMedium!.copyWith(color: color), 700),
                  ),
                  Text(detalle, style: textos.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: e8),
            Text(
              valor,
              style: conPeso(
                textos.bodyMedium!.copyWith(
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Las iniciales en un círculo: verde si está al día, rojizo si debe y gris
/// si no es recurrente.
class AvatarCliente extends StatelessWidget {
  const AvatarCliente({super.key, required this.cuenta, this.tamano = 44});

  final CuentaCliente cuenta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = !cuenta.cliente.recurrente
        ? (ColoresGranja.surco, ColoresGranja.tintaSuave)
        : cuenta.alDia
            ? (ColoresGranja.pastoClaro, ColoresGranja.pasto)
            : (ColoresGranja.graneroClaro, ColoresGranja.granero);
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
      child: Text(
        iniciales(cuenta.cliente.nombre),
        style: conPeso(
          Theme.of(context).textTheme.bodyMedium!.copyWith(color: color),
          800,
        ),
      ),
    );
  }
}

class _FichaAlDia extends StatelessWidget {
  const _FichaAlDia();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ColoresGranja.pastoClaro,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Al día',
        style: conPeso(
          Theme.of(context).textTheme.bodySmall!.copyWith(color: ColoresGranja.pasto),
          700,
        ),
      ),
    );
  }
}

class _SinClientes extends StatelessWidget {
  const _SinClientes();

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(e16),
      child: Container(
        padding: const EdgeInsets.all(e24),
        decoration: BoxDecoration(
          color: ColoresGranja.papel,
          borderRadius: BorderRadius.circular(radioTarjeta),
          border: Border.all(color: ColoresGranja.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gallo(tamano: 96, gesto: Gesto.dormido),
            const SizedBox(height: e12),
            Text('Todavía no hay clientes', style: textos.titleLarge),
            const SizedBox(height: e4),
            Text(
              'Agrega a quienes te compran. También los puedes crear al registrar una venta.',
              style: textos.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonNuevoCliente extends StatelessWidget {
  const _BotonNuevoCliente({required this.alTocar});

  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return Pulsable(
      onTap: alTocar,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: e20),
        decoration: BoxDecoration(
          color: ColoresGranja.granero,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: ColoresGranja.granero.withValues(alpha: 0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: ColoresGranja.papel),
            const SizedBox(width: e8),
            Text(
              'Nuevo cliente',
              style: conPeso(
                const TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 17,
                  color: ColoresGranja.papel,
                ),
                700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
