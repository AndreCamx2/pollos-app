-- Prueba las reglas de la base de datos con tres personas:
-- Ana (dueña), Beto (trabajador de Ana) y Carla (dueña de otra granja).
-- Todo corre dentro de una transacción que se deshace al final, así que se
-- puede correr en la base de desarrollo sin dejar datos.
--
-- Correr con psql:  psql "$URL_BASE_DESARROLLO" -v ON_ERROR_STOP=1 -f supabase/tests/reglas_del_negocio.sql
-- Si todo sale bien, la última línea dice: TODAS LAS PRUEBAS PASARON

begin;

create schema pruebas;
grant usage on schema pruebas to authenticated;

create function pruebas.debe_fallar(sentencia text, fragmento text)
returns void language plpgsql as $$
begin
  execute sentencia;
  raise exception 'Se esperaba un error con "%" y no lo hubo: %', fragmento, sentencia
    using errcode = 'P0099';
exception
  when sqlstate 'P0099' then raise;
  when others then
    if sqlerrm not ilike '%' || fragmento || '%' then
      raise exception 'Error distinto al esperado. Esperaba "%", llegó "%"', fragmento, sqlerrm;
    end if;
    raise notice 'ok: rechaza con "%"', fragmento;
end;
$$;

create function pruebas.igual(obtenido bigint, esperado bigint, regla text)
returns void language plpgsql as $$
begin
  if obtenido is distinct from esperado then
    raise exception 'FALLÓ: % (esperaba %, obtuvo %)', regla, esperado, obtenido;
  end if;
  raise notice 'ok: %', regla;
end;
$$;

create function pruebas.filas(sentencia text)
returns bigint language plpgsql as $$
declare
  n bigint;
begin
  execute sentencia;
  get diagnostics n = row_count;
  return n;
end;
$$;

grant execute on all functions in schema pruebas to authenticated;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'ana@prueba.co'),
  ('00000000-0000-0000-0000-00000000000b', 'beto@prueba.co'),
  ('00000000-0000-0000-0000-00000000000c', 'carla@prueba.co'),
  ('00000000-0000-0000-0000-00000000000d', 'dario@prueba.co');

\set ana   '\'{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}\''
\set beto  '\'{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}\''
\set carla '\'{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}\''
\set dario '\'{"sub":"00000000-0000-0000-0000-00000000000d","role":"authenticated"}\''

-- Ana crea su granja, invita a Beto y registra el lote del Galpón 1.
select set_config('request.jwt.claims', :ana, true);
set local role authenticated;

select public.crear_granja('Granja La Esperanza') as granja \gset
select public.crear_invitacion(:'granja', 'trabajador') as codigo \gset

insert into public.perfiles (id, nombre) values ('00000000-0000-0000-0000-00000000000a', 'Ana');
insert into public.galpones (id, granja_id, nombre, capacidad)
values ('10000000-0000-0000-0000-000000000001', :'granja', 'Galpón 1', 600);
insert into public.lotes (id, granja_id, galpon_id, fecha_llegada, cantidad_inicial, precio_compra_total)
values ('20000000-0000-0000-0000-000000000001', :'granja', '10000000-0000-0000-0000-000000000001',
        '2026-09-17', 500, 1750000);
insert into public.clientes (id, granja_id, nombre, detalle)
values ('30000000-0000-0000-0000-000000000001', :'granja', 'Doña Marta', 'Tienda La Esquina');
insert into public.ventas (id, granja_id, lote_id, cliente_id, fecha, pollos, libras, precio_libra, total)
values ('40000000-0000-0000-0000-000000000002', :'granja', '20000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001', '2026-10-09', 2, 10, 5400, 54000);

-- Beto entra con el código.
reset role;
select set_config('request.jwt.claims', :beto, true);
set local role authenticated;

select public.unirse_con_codigo(:'codigo') = :'granja' as entro;
select pruebas.igual(
  (select count(*) from public.miembros where granja_id = :'granja'),
  2, 'Beto entra a la granja con el código');

reset role;
select set_config('request.jwt.claims', :ana, true);
set local role authenticated;
select public.crear_invitacion(:'granja') as otro_codigo \gset

reset role;
select set_config('request.jwt.claims', :beto, true);
set local role authenticated;
select pruebas.debe_fallar(
  format($s$select public.unirse_con_codigo(%L)$s$, :'otro_codigo'),
  'Ya perteneces');

-- Freno de pollos.
insert into public.mortalidad (id, granja_id, lote_id, fecha, cantidad, causa, creado_por)
values ('50000000-0000-0000-0000-000000000001', :'granja', '20000000-0000-0000-0000-000000000001',
        '2026-10-06', 12, 'calor', '00000000-0000-0000-0000-00000000000a');

select pruebas.igual(
  (select count(*) from public.mortalidad
   where creado_por = '00000000-0000-0000-0000-00000000000b'),
  1, 'el autor lo pone la base de datos aunque el celular mande otro');

insert into public.ventas (id, granja_id, lote_id, cliente_id, fecha, pollos, libras, precio_libra, total, fiado)
values ('40000000-0000-0000-0000-000000000001', :'granja', '20000000-0000-0000-0000-000000000001',
        '30000000-0000-0000-0000-000000000001', '2026-10-10', 10, 50, 5400, 270000, true);

select pruebas.debe_fallar(
  format($s$insert into public.ventas (id, granja_id, lote_id, cliente_id, fecha, pollos, libras, precio_libra, total)
            values (gen_random_uuid(), %L, '20000000-0000-0000-0000-000000000001',
                    '30000000-0000-0000-0000-000000000001', '2026-10-10', 477, 1, 5400, 5400)$s$, :'granja'),
  'Solo quedan 476 pollos');

select pruebas.igual(
  pruebas.filas($s$update public.ventas set pollos = 486
                  where id = '40000000-0000-0000-0000-000000000001'$s$),
  1, 'editar una venta no cuenta dos veces sus propios pollos');

select pruebas.debe_fallar(
  $s$update public.ventas set pollos = 487 where id = '40000000-0000-0000-0000-000000000001'$s$,
  'Solo quedan 486 pollos');

update public.ventas set pollos = 10 where id = '40000000-0000-0000-0000-000000000001';

select pruebas.debe_fallar(
  format($s$insert into public.mortalidad (id, granja_id, lote_id, fecha, cantidad)
            values (gen_random_uuid(), %L, '20000000-0000-0000-0000-000000000001', '2026-09-01', 1)$s$,
         :'granja'),
  'anterior a la llegada');

-- Permisos del trabajador.
select pruebas.igual(
  pruebas.filas($s$update public.miembros set rol = 'dueno'
                  where usuario_id = '00000000-0000-0000-0000-00000000000b'$s$),
  0, 'el trabajador no se sube de rol él mismo');

select pruebas.igual(
  pruebas.filas($s$update public.ventas set fecha = '2026-10-11'
                  where id = '40000000-0000-0000-0000-000000000002'$s$),
  0, 'el trabajador no edita ventas que registró otro');

select pruebas.igual(
  pruebas.filas($s$delete from public.lotes where id = '20000000-0000-0000-0000-000000000001'$s$),
  0, 'el trabajador no borra lotes');

select pruebas.debe_fallar(
  format($s$insert into public.lotes (id, granja_id, galpon_id, fecha_llegada, cantidad_inicial, precio_compra_total)
            values (gen_random_uuid(), %L, '10000000-0000-0000-0000-000000000001', '2026-10-10', 100, 0)$s$,
         :'granja'),
  'row-level security');

select pruebas.debe_fallar(
  $s$select public.revisar_saldo('30000000-0000-0000-0000-000000000001')$s$,
  'permission denied');

select pruebas.igual(
  (select count(*) from public.perfiles where nombre = 'Ana'),
  1, 'el trabajador ve el nombre de sus compañeros');

-- Fiados y abonos.
insert into public.abonos (id, granja_id, cliente_id, fecha, valor)
values ('60000000-0000-0000-0000-000000000001', :'granja', '30000000-0000-0000-0000-000000000001',
        '2026-10-10', 270000);

select pruebas.debe_fallar(
  format($s$insert into public.abonos (id, granja_id, cliente_id, fecha, valor)
            values (gen_random_uuid(), %L, '30000000-0000-0000-0000-000000000001', '2026-10-10', 1)$s$,
         :'granja'),
  'superan lo que compró fiado por $1');

select pruebas.igual(
  (select saldo from public.saldo_clientes where id = '30000000-0000-0000-0000-000000000001'),
  0, 'Doña Marta queda al día');

select pruebas.igual(
  (select precio_libra_sugerido from public.saldo_clientes where id = '30000000-0000-0000-0000-000000000001'),
  5400, 'sugiere el precio de la última venta');

select pruebas.igual(
  (select vivos from public.resumen_lotes where id = '20000000-0000-0000-0000-000000000001'),
  476, 'el resumen cuenta vivos = 500 - 12 muertos - 12 vendidos');

-- Lo que solo puede hacer la dueña.
reset role;
select set_config('request.jwt.claims', :ana, true);
set local role authenticated;

select pruebas.debe_fallar(
  $s$delete from public.ventas where id = '40000000-0000-0000-0000-000000000001'$s$,
  'superan lo que compró fiado');

select pruebas.debe_fallar(
  $s$update public.lotes set cantidad_inicial = 23 where id = '20000000-0000-0000-0000-000000000001'$s$,
  'Ya salieron 24 pollos');

select pruebas.debe_fallar(
  format($s$insert into public.lotes (id, granja_id, galpon_id, fecha_llegada, cantidad_inicial, precio_compra_total)
            values (gen_random_uuid(), %L, '10000000-0000-0000-0000-000000000001', '2026-10-10', 100, 0)$s$,
         :'granja'),
  'un_lote_abierto_por_galpon');

select pruebas.debe_fallar(
  $s$delete from public.miembros where usuario_id = '00000000-0000-0000-0000-00000000000a'$s$,
  'al menos un dueño');

select pruebas.igual(
  pruebas.filas($s$update public.miembros set rol = 'administrador'
                  where usuario_id = '00000000-0000-0000-0000-00000000000b'$s$),
  1, 'la dueña cambia de rol a Beto');

update public.miembros set rol = 'trabajador'
where usuario_id = '00000000-0000-0000-0000-00000000000b';

select pruebas.debe_fallar(
  $s$update public.miembros set usuario_id = '00000000-0000-0000-0000-00000000000d'
     where usuario_id = '00000000-0000-0000-0000-00000000000b'$s$,
  'permission denied');

select pruebas.debe_fallar(
  $s$update public.miembros set rol = 'trabajador'
     where usuario_id = '00000000-0000-0000-0000-00000000000a'$s$,
  'al menos un dueño');

update public.lotes set cerrado_en = now() where id = '20000000-0000-0000-0000-000000000001';

select pruebas.debe_fallar(
  format($s$insert into public.medicamentos (id, granja_id, lote_id, fecha, nombre, costo)
            values (gen_random_uuid(), %L, '20000000-0000-0000-0000-000000000001', '2026-10-10', 'Vitaminas', 45000)$s$,
         :'granja'),
  'ya está cerrado');

select pruebas.debe_fallar(
  $s$delete from public.mortalidad where lote_id = '20000000-0000-0000-0000-000000000001'$s$,
  'ya está cerrado');

-- Lo que se borra queda anotado para los celulares que estaban sin señal.
insert into public.galpones (id, granja_id, nombre)
values ('10000000-0000-0000-0000-000000000002', :'granja', 'Galpón 2');

select pruebas.igual(
  (select count(*) from public.galpones
   where id = '10000000-0000-0000-0000-000000000002' and cambiado_en = creado_en),
  1, 'una fila nueva cambió por última vez cuando se creó');

update public.galpones set capacidad = 600 where id = '10000000-0000-0000-0000-000000000002';

select pruebas.igual(
  (select count(*) from public.galpones
   where id = '10000000-0000-0000-0000-000000000002' and cambiado_en = actualizado_en),
  1, 'al editarla, cambió por última vez cuando se editó');

delete from public.galpones where id = '10000000-0000-0000-0000-000000000002';

reset role;
select set_config('request.jwt.claims', :beto, true);
set local role authenticated;

select pruebas.igual(
  (select count(*) from public.borrados
   where tabla = 'galpones' and fila_id = '10000000-0000-0000-0000-000000000002'),
  1, 'un compañero se entera de que borraron el galpón');

select pruebas.debe_fallar(
  format($s$insert into public.borrados (tabla, fila_id, granja_id)
            values ('lotes', gen_random_uuid(), %L)$s$, :'granja'),
  'row-level security');

select pruebas.igual(
  (select count(*) from public.clientes
   where id = '30000000-0000-0000-0000-000000000001' and recurrente),
  1, 'un cliente nuevo cuenta como recurrente');

-- Marcas de alimento.
insert into public.marcas (id, granja_id, nombre, kilos_por_bulto)
values ('70000000-0000-0000-0000-000000000001', :'granja', 'Solla', 40);

select pruebas.debe_fallar(
  format($s$insert into public.marcas (id, granja_id, nombre)
            values (gen_random_uuid(), %L, ' solla ')$s$, :'granja'),
  'marcas_nombre_unico');

select pruebas.debe_fallar(
  format($s$insert into public.mortalidad (id, granja_id, lote_id, fecha, cantidad)
            values (gen_random_uuid(), %L, '20000000-0000-0000-0000-000000000001',
                    current_date + 5, 1)$s$, :'granja'),
  'fecha del celular');

-- Los pollos que no aparecen al cerrar se anotan como faltantes. El lote de
-- prueba ya está cerrado, así que se revisa la regla misma.
select pruebas.igual(
  (select count(*) from pg_constraint
   where conname = 'mortalidad_causa_check'
     and pg_get_constraintdef(oid) like '%faltante%'),
  1, 'faltante es una causa aceptada');

-- Carla, de otra granja, no ve ni toca nada de Ana.
reset role;
select set_config('request.jwt.claims', :carla, true);
set local role authenticated;

select public.crear_granja('Granja El Porvenir') is not null;

select pruebas.igual((select count(*) from public.lotes), 0, 'otra granja no ve los lotes de Ana');
select pruebas.igual((select count(*) from public.saldo_clientes), 0, 'otra granja no ve los clientes de Ana');
select pruebas.igual((select count(*) from public.perfiles), 0, 'otra granja no ve los perfiles de Ana');

select pruebas.debe_fallar(
  format($s$select public.crear_invitacion(%L)$s$, :'granja'),
  'Solo el dueño o un administrador');

select pruebas.debe_fallar(
  format($s$insert into public.clientes (id, granja_id, nombre) values (gen_random_uuid(), %L, 'Intruso')$s$,
         :'granja'),
  'row-level security');

select pruebas.igual((select count(*) from public.borrados), 0, 'otra granja no ve lo que borró Ana');
select pruebas.igual((select count(*) from public.marcas), 0, 'otra granja no ve las marcas de Ana');

insert into public.galpones (id, granja_id, nombre)
select '10000000-0000-0000-0000-000000000003', id, 'Galpón 1' from public.granjas;

select pruebas.igual(
  pruebas.filas($s$delete from public.granjas$s$),
  1, 'borrar la granja completa no tropieza con el registro de borrados');

-- El código de Beto ya se usó.
reset role;
select set_config('request.jwt.claims', :dario, true);
set local role authenticated;

select pruebas.debe_fallar(
  format($s$select public.unirse_con_codigo(%L)$s$, :'codigo'),
  'Ese código no sirve');

reset role;
select pruebas.igual(
  pruebas.filas(format($s$delete from public.granjas where id = %L$s$, :'granja')),
  1, 'una granja con lotes cerrados y registros se puede borrar completa');

select 'TODAS LAS PRUEBAS PASARON' as resultado;
rollback;
