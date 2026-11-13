import 'package:flutter_test/flutter_test.dart';
import 'package:pollos_app/modulos/clientes/dominio/cliente.dart';
import 'package:pollos_app/modulos/lotes/dominio/lote.dart';
import 'package:pollos_app/modulos/registros/dominio/cuentas_lote.dart';
import 'package:pollos_app/modulos/registros/dominio/marca.dart';
import 'package:pollos_app/modulos/registros/dominio/registro.dart';

void main() {
  final hoy = DateTime(2026, 10, 10);
  final lote = Lote.reconstruir(
    id: 'lote-1',
    granjaId: 'granja-1',
    galponId: 'galpon-1',
    fechaLlegada: DateTime(2026, 9, 17),
    cantidadInicial: 500,
    precioCompraTotal: 1750000,
  );

  Mortalidad muertos(int cantidad, {String id = 'm1', DateTime? fecha, int vivos = 500}) =>
      Mortalidad.nueva(
        id: id,
        lote: lote,
        fecha: fecha ?? DateTime(2026, 10, 6),
        cantidad: cantidad,
        causa: CausaMuerte.calor,
        vivosSinEste: vivos,
        hoy: hoy,
      );

  const solla = Marca.reconstruir(id: 'solla', granjaId: 'granja-1', nombre: 'Solla');

  CompraAlimento compra(TipoAlimento tipo, {int bultos = 10, int precio = 98000}) =>
      CompraAlimento.nueva(
        id: 'c-$tipo',
        lote: lote,
        fecha: DateTime(2026, 10, 5),
        tipo: tipo,
        marca: solla,
        kilosPorBulto: 40,
        bultos: bultos,
        precioPorBulto: precio,
        hoy: hoy,
      );

  group('Fechas y lote', () {
    test('no se anota nada antes de que llegaran los pollitos', () {
      expect(
        () => muertos(1, fecha: DateTime(2026, 9, 16)),
        throwsA(isA<RegistroInvalido>()),
      );
    });

    test('el día de la llegada sí se puede anotar', () {
      expect(muertos(1, fecha: DateTime(2026, 9, 17)).cantidad, 1);
    });

    test('no se anota nada en el futuro', () {
      expect(
        () => muertos(1, fecha: DateTime(2026, 10, 11)),
        throwsA(isA<RegistroInvalido>()),
      );
    });

    test('en un lote cerrado no se anota nada', () {
      expect(
        () => Medicamento.nueva(
          id: 'v1',
          lote: lote.cerrar(DateTime(2026, 10, 9)),
          fecha: DateTime(2026, 10, 8),
          nombre: 'Vitaminas',
          costo: 80000,
          hoy: hoy,
        ),
        throwsA(isA<RegistroInvalido>()),
      );
    });
  });

  group('Muertos', () {
    test('no deja anotar más muertos que los vivos', () {
      expect(
        () => muertos(489, vivos: 488),
        throwsA(
          isA<RegistroInvalido>().having(
            (e) => e.mensaje,
            'mensaje',
            'Solo quedan 488 pollos vivos en este lote.',
          ),
        ),
      );
    });

    test('rechaza cero muertos', () {
      expect(() => muertos(0), throwsA(isA<RegistroInvalido>()));
    });

    test('una nota en blanco no se guarda', () {
      final registro = Mortalidad.nueva(
        id: 'm1',
        lote: lote,
        fecha: DateTime(2026, 10, 6),
        cantidad: 3,
        nota: '   ',
        vivosSinEste: 500,
        hoy: hoy,
      );
      expect(registro.nota, isNull);
      expect(registro.causa, isNull);
    });
  });

  group('Alimento y medicina', () {
    test('10 bultos de 40 kilos a \$98.000: \$980.000 y 400 kilos', () {
      final registro = compra(TipoAlimento.inicio);
      expect(registro.total, 980000);
      expect(registro.kilos, 400);
      expect(registro.marca, 'Solla');
      expect(registro.marcaId, 'solla');
    });

    test('rechaza una compra sin marca o sin bultos', () {
      expect(
        () => CompraAlimento.nueva(
          id: 'c1',
          lote: lote,
          fecha: hoy,
          tipo: TipoAlimento.inicio,
          marca: null,
          kilosPorBulto: 40,
          bultos: 10,
          precioPorBulto: 98000,
          hoy: hoy,
        ),
        throwsA(isA<RegistroInvalido>()),
      );
      expect(() => compra(TipoAlimento.inicio, bultos: 0), throwsA(isA<RegistroInvalido>()));
    });

    test('rechaza una medicina sin nombre', () {
      expect(
        () => Medicamento.nueva(
          id: 'v1',
          lote: lote,
          fecha: hoy,
          nombre: '',
          costo: 45000,
          hoy: hoy,
        ),
        throwsA(isA<RegistroInvalido>()),
      );
    });
  });

  group('Ventas', () {
    const jaime = Cliente.reconstruir(id: 'jaime', granjaId: 'granja-1', nombre: 'Don Jaime');

    Venta venta({
      int pollos = 10,
      double libras = 50,
      int precio = 5600,
      bool fiado = false,
      int vivos = 488,
      int debe = 0,
    }) =>
        Venta.nueva(
          id: 'v1',
          lote: lote,
          cliente: jaime,
          fecha: DateTime(2026, 10, 10),
          pollos: pollos,
          libras: libras,
          precioLibra: precio,
          fiado: fiado,
          vivosSinEsta: vivos,
          debeSinEsta: debe,
          hoy: hoy,
        );

    test('50 libras a \$5.600 son \$280.000', () {
      expect(venta().total, 280000);
    });

    test('245,5 libras a \$5.600 son \$1.374.800, sin errores de decimales', () {
      expect(venta(libras: 245.5).total, 1374800);
      expect(totalVenta(0.29, 5600), 1624);
    });

    test('no deja vender más pollos de los vivos', () {
      expect(
        () => venta(pollos: 489),
        throwsA(
          isA<RegistroInvalido>().having(
            (e) => e.mensaje,
            'mensaje',
            'Solo quedan 488 pollos vivos en este lote.',
          ),
        ),
      );
    });

    test('rechaza una venta sin libras o sin precio', () {
      expect(() => venta(libras: 0), throwsA(isA<RegistroInvalido>()));
      expect(() => venta(precio: 0), throwsA(isA<RegistroInvalido>()));
    });

    test('una venta fiada suma a lo que debe el cliente y una de contado no', () {
      expect(venta(fiado: true).fiadoPorCobrar, 280000);
      expect(venta().fiadoPorCobrar, 0);
    });

    test('no deja pasar a contado una venta ya abonada', () {
      expect(() => venta(debe: -200000), throwsA(isA<RegistroInvalido>()));
      expect(venta(fiado: true, debe: -200000).fiado, isTrue);
    });

    test('avisa si las libras por pollo salen raras', () {
      expect(venta().pesoRaro, isFalse);
      expect(venta(libras: 15).pesoRaro, isTrue);
      expect(venta(libras: 90).pesoRaro, isTrue);
    });
  });

  group('Topes contra errores de dedo', () {
    test('no acepta 5.000 bultos en una compra', () {
      expect(
        () => compra(TipoAlimento.inicio, bultos: 5000),
        throwsA(isA<RegistroInvalido>().having((e) => e.campo, 'campo', 'bultos')),
      );
    });

    test('no acepta \$9.800.000 por bulto', () {
      expect(
        () => compra(TipoAlimento.inicio, precio: 9800000),
        throwsA(isA<RegistroInvalido>().having((e) => e.campo, 'campo', 'precio')),
      );
    });

    test('no acepta más de 100.000 pollitos en un lote', () {
      expect(
        () => Lote.nuevo(
          id: 'l2',
          granjaId: 'granja-1',
          galponId: 'galpon-1',
          fechaLlegada: hoy,
          cantidadInicial: 500000,
          precioCompraTotal: 1750000,
          hoy: hoy,
        ),
        throwsA(isA<LoteInvalido>().having((e) => e.campo, 'campo', 'pollitos')),
      );
    });

    test('el error dice en qué campo está', () {
      expect(
        () => muertos(1, fecha: DateTime(2026, 9, 16)),
        throwsA(isA<RegistroInvalido>().having((e) => e.campo, 'campo', 'fecha')),
      );
    });
  });

  group('Marcas', () {
    test('no deja dos marcas con el mismo nombre', () {
      expect(
        () => Marca.nueva(id: 'otra', granjaId: 'granja-1', nombre: ' SOLLA ', otras: [solla]),
        throwsA(isA<RegistroInvalido>()),
      );
    });

    test('al corregir una marca puede conservar su nombre', () {
      final corregida = Marca.nueva(
        id: 'solla',
        granjaId: 'granja-1',
        nombre: 'Solla',
        kilosPorBulto: 40,
        otras: [solla],
      );
      expect(corregida.kilosPorBulto, 40);
    });

    test('rechaza kilos por bulto fuera de 1 a 100', () {
      expect(
        () => Marca.nueva(id: 'x', granjaId: 'granja-1', nombre: 'Italcol', kilosPorBulto: 400, otras: const []),
        throwsA(isA<RegistroInvalido>()),
      );
    });

    test('las que ya no se usan van al final', () {
      const vieja = Marca.reconstruir(id: 'a', granjaId: 'granja-1', nombre: 'Agrinal', enUso: false);
      final lista = marcasConCompras([vieja, solla], [compra(TipoAlimento.inicio)]);
      expect([for (final m in lista) m.marca.id], ['solla', 'a']);
      expect(lista.first.compras, 1);
      expect(lista.first.ultimoPrecio, 98000);
    });
  });

  group('Quién puede cambiar un registro', () {
    final deBeto = Mortalidad.reconstruir(
      id: 'm1',
      granjaId: 'granja-1',
      loteId: 'lote-1',
      fecha: DateTime(2026, 10, 6),
      cantidad: 3,
      creadoPor: 'beto',
    );

    test('el trabajador cambia lo que anotó él', () {
      expect(deBeto.puedeCambiarlo(administra: false, usuarioId: 'beto'), isTrue);
    });

    test('el trabajador no cambia lo que anotó otro', () {
      expect(deBeto.puedeCambiarlo(administra: false, usuarioId: 'carlos'), isFalse);
    });

    test('el dueño y el administrador cambian cualquier registro', () {
      expect(deBeto.puedeCambiarlo(administra: true, usuarioId: 'ana'), isTrue);
    });
  });

  group('Cuentas del lote', () {
    final otroLote = Mortalidad.reconstruir(
      id: 'm9',
      granjaId: 'granja-1',
      loteId: 'lote-2',
      fecha: DateTime(2026, 10, 1),
      cantidad: 50,
    );

    test('500 que llegaron y 12 muertos: quedan 488 y la mortalidad es 2,4 %', () {
      final cuentas = CuentasLote(lote, [
        muertos(3, id: 'm1'),
        muertos(9, id: 'm2', fecha: DateTime(2026, 10, 7)),
        otroLote,
      ]);
      expect(cuentas.muertos, 12);
      expect(cuentas.vivos, 488);
      expect(cuentas.mortalidad, closeTo(2.4, 0.001));
    });

    test('lo invertido suma pollitos, alimento de inicio y de engorde, y medicina', () {
      final cuentas = CuentasLote(lote, [
        compra(TipoAlimento.inicio),
        compra(TipoAlimento.engorde, bultos: 20, precio: 104000),
        Medicamento.nueva(
          id: 'v1',
          lote: lote,
          fecha: DateTime(2026, 10, 2),
          nombre: 'Vitaminas',
          costo: 80000,
          hoy: hoy,
        ),
      ]);
      expect(cuentas.alimentoInicio, 980000);
      expect(cuentas.alimentoEngorde, 2080000);
      expect(cuentas.medicina, 80000);
      expect(cuentas.invertido, 1750000 + 980000 + 2080000 + 80000);
    });

    test('desde el día 22 avisa que toca engorde hasta que se compra', () {
      final dia23 = DateTime(2026, 10, 10);
      expect(CuentasLote(lote, [compra(TipoAlimento.inicio)]).tocaCambiarAEngorde(dia23), isTrue);
      expect(
        CuentasLote(lote, [compra(TipoAlimento.engorde)]).tocaCambiarAEngorde(dia23),
        isFalse,
      );
      expect(CuentasLote(lote, const []).tocaCambiarAEngorde(DateTime(2026, 10, 1)), isFalse);
    });

    test('500 que llegaron, 12 muertos y 30 vendidos: quedan 458', () {
      final cuentas = CuentasLote(lote, [
        muertos(12),
        Venta.reconstruir(
          id: 'v1',
          granjaId: 'granja-1',
          loteId: 'lote-1',
          fecha: DateTime(2026, 10, 9),
          clienteId: 'jaime',
          pollos: 30,
          libras: 152,
          precioLibra: 5600,
          fiado: false,
        ),
      ]);
      expect(cuentas.vendidos, 30);
      expect(cuentas.vivos, 458);
      expect(cuentas.ventas, 851200);
      expect(cuentas.ganancia, 851200 - 1750000);
    });

    test('al corregir unos muertos no se cuentan dos veces', () {
      final tres = muertos(3);
      expect(CuentasLote(lote, [tres]).vivosSin(tres), 500);
    });

    test('sabe cuál es el registro más antiguo del lote', () {
      final cuentas = CuentasLote(lote, [
        muertos(1, id: 'm1', fecha: DateTime(2026, 10, 7)),
        compra(TipoAlimento.inicio),
      ]);
      expect(cuentas.primerRegistro, DateTime.utc(2026, 10, 5));
      expect(CuentasLote(lote, const []).tieneRegistros, isFalse);
    });
  });
}
