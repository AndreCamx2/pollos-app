-- Lo que necesitan los celulares para trabajar sin señal y ponerse al día
-- cuando vuelve: saber qué cambió y qué se borró desde la última vez.

-- 1. Cuándo cambió cada fila por última vez

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'galpones', 'lotes', 'compras_alimento', 'mortalidad', 'medicamentos',
    'clientes', 'ventas', 'abonos'
  ] loop
    execute format(
      'alter table public.%I add column cambiado_en timestamptz
         generated always as (coalesce(actualizado_en, creado_en)) stored', tabla);
  end loop;
end;
$$;

-- 2. Registro de lo borrado
-- Una fila borrada desaparece sin dejar rastro, así que un celular que estaba
-- sin señal la seguiría mostrando. Aquí queda anotado para que la quite.

create table public.borrados (
  tabla text not null,
  fila_id uuid not null,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  borrado_en timestamptz not null default now(),
  primary key (tabla, fila_id)
);

create index on public.borrados (granja_id);

alter table public.borrados enable row level security;

-- Solo se puede leer: las filas las escribe el trigger de abajo.
create policy "ver" on public.borrados for select to authenticated
  using (granja_id in (select public.mis_granjas()));

-- Cuando se borra la granja completa no se anota nada: ya no existe a quién
-- avisarle y la fila apuntaría a una granja borrada.
create function public.anotar_borrado()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from public.granjas where id = old.granja_id) then
    insert into public.borrados (tabla, fila_id, granja_id)
    values (tg_table_name, old.id, old.granja_id)
    on conflict (tabla, fila_id) do update set borrado_en = now();
  end if;
  return null;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'galpones', 'lotes', 'compras_alimento', 'mortalidad', 'medicamentos',
    'clientes', 'ventas', 'abonos'
  ] loop
    execute format(
      'create trigger anotar_borrado after delete on public.%I
         for each row execute function public.anotar_borrado()', tabla);
  end loop;
end;
$$;

revoke execute on function public.anotar_borrado() from public, anon, authenticated;
