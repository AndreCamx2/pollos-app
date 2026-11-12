-- Marcas de alimento como lista propia de cada granja, y freno a las fechas
-- en el futuro.

-- 1. Marcas
-- Las compras apuntan a la marca por su id: corregir el nombre de una marca
-- la corrige en todas sus compras. La columna marca de compras_alimento
-- queda con el nombre que tenía al comprarse.

create table public.marcas (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  kilos_por_bulto numeric(6, 2) check (kilos_por_bulto > 0),
  en_uso boolean not null default true,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  cambiado_en timestamptz generated always as (coalesce(actualizado_en, creado_en)) stored,
  unique (id, granja_id)
);

create unique index marcas_nombre_unico on public.marcas (granja_id, lower(trim(nombre)));
create index on public.marcas (granja_id);

alter table public.marcas enable row level security;

create policy "ver" on public.marcas for select to authenticated
  using (granja_id in (select public.mis_granjas()));
create policy "crear" on public.marcas for insert to authenticated
  with check (granja_id in (select public.mis_granjas()));
create policy "editar" on public.marcas for update to authenticated
  using (
    granja_id in (select public.granjas_que_administro())
    or (creado_por = (select auth.uid()) and granja_id in (select public.mis_granjas()))
  );
create policy "borrar" on public.marcas for delete to authenticated
  using (
    granja_id in (select public.granjas_que_administro())
    or (creado_por = (select auth.uid()) and granja_id in (select public.mis_granjas()))
  );

create trigger sellar_autor before insert or update on public.marcas
  for each row execute function public.sellar_autor();
create trigger anotar_borrado after delete on public.marcas
  for each row execute function public.anotar_borrado();

-- Cada marca que ya se escribió en una compra pasa a la lista. Si se escribió
-- de varias formas ("Solla", "solla") queda la más usada, y en un empate la
-- que tiene mayúsculas. Los kilos son los de su compra más reciente.
with formas as (
  select granja_id, lower(trim(marca)) as clave, trim(marca) as nombre,
         count(*) as veces, max(fecha) as ultima
  from public.compras_alimento
  group by granja_id, lower(trim(marca)), trim(marca)
),
kilos as (
  select distinct on (granja_id, lower(trim(marca)))
    granja_id, lower(trim(marca)) as clave, kilos_por_bulto
  from public.compras_alimento
  order by granja_id, lower(trim(marca)), fecha desc, creado_en desc
)
insert into public.marcas (id, granja_id, nombre, kilos_por_bulto)
select distinct on (f.granja_id, f.clave)
  gen_random_uuid(), f.granja_id, f.nombre, k.kilos_por_bulto
from formas f
join kilos k using (granja_id, clave)
order by f.granja_id, f.clave, f.veces desc, (f.nombre <> lower(f.nombre)) desc, f.ultima desc;

alter table public.compras_alimento add column marca_id uuid;

-- Las compras de lotes ya cerrados también se completan.
alter table public.compras_alimento disable trigger validar_registro_de_lote;
update public.compras_alimento c set marca_id = m.id
from public.marcas m
where m.granja_id = c.granja_id and lower(trim(m.nombre)) = lower(trim(c.marca));
alter table public.compras_alimento enable trigger validar_registro_de_lote;

alter table public.compras_alimento
  add foreign key (marca_id, granja_id) references public.marcas (id, granja_id);
create index on public.compras_alimento (marca_id);

-- 2. Fechas en el futuro
-- La fecha la pone el celular; si su reloj está corrido, el registro quedaría
-- en el futuro. Se deja un día de margen por la diferencia de horas con UTC.
create function public.validar_fecha_no_futura()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if (to_jsonb(new) ->> tg_argv[0])::date > current_date + 1 then
    raise exception 'La fecha no puede ser en el futuro. Revisa la fecha del celular.';
  end if;
  return new;
end;
$$;

create trigger validar_fecha_no_futura before insert or update on public.lotes
  for each row execute function public.validar_fecha_no_futura('fecha_llegada');

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'compras_alimento', 'mortalidad', 'medicamentos', 'ventas', 'abonos'
  ] loop
    execute format(
      'create trigger validar_fecha_no_futura before insert or update on public.%I
         for each row execute function public.validar_fecha_no_futura(''fecha'')', tabla);
  end loop;
end;
$$;

revoke execute on function public.validar_fecha_no_futura() from public, anon, authenticated;
