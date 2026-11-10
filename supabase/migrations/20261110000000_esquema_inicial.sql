-- Esquema de la app de pollos para Supabase.
-- La plata va en pesos enteros (bigint). Los ids de los registros los genera el
-- celular (uuid), así un registro hecho sin señal conserva su id al subir.

-- 1. Granjas, personas y roles

create table public.granjas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(trim(nombre)) > 0),
  creada_en timestamptz not null default now()
);

create table public.miembros (
  granja_id uuid not null references public.granjas (id) on delete cascade,
  usuario_id uuid not null references auth.users (id) on delete cascade,
  rol text not null default 'trabajador'
    check (rol in ('dueno', 'administrador', 'trabajador')),
  unido_en timestamptz not null default now(),
  primary key (granja_id, usuario_id)
);

create table public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0)
);

create table public.invitaciones (
  codigo text primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  rol text not null check (rol in ('administrador', 'trabajador')),
  creada_por uuid references auth.users (id) on delete set null,
  vence_en timestamptz not null default now() + interval '7 days',
  usada_por uuid references auth.users (id) on delete set null,
  usada_en timestamptz
);

-- 2. Datos del negocio
-- Las llaves dobles (id, granja_id) impiden que un registro de una granja
-- apunte a un lote o cliente de otra.

create table public.galpones (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  capacidad integer check (capacidad > 0),
  largo_m numeric(6, 2) check (largo_m > 0),
  ancho_m numeric(6, 2) check (ancho_m > 0),
  ubicacion text,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  unique (id, granja_id)
);

create unique index galpones_nombre_unico
  on public.galpones (granja_id, lower(trim(nombre)));

create table public.lotes (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  galpon_id uuid not null,
  fecha_llegada date not null,
  cantidad_inicial integer not null check (cantidad_inicial > 0),
  precio_compra_total bigint not null check (precio_compra_total >= 0),
  cerrado_en timestamptz,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  unique (id, granja_id),
  foreign key (galpon_id, granja_id) references public.galpones (id, granja_id)
);

create unique index un_lote_abierto_por_galpon
  on public.lotes (galpon_id) where cerrado_en is null;

create table public.compras_alimento (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  lote_id uuid not null,
  fecha date not null,
  tipo text not null check (tipo in ('inicio', 'engorde')),
  marca text not null check (length(trim(marca)) > 0),
  kilos_por_bulto numeric(6, 2) not null check (kilos_por_bulto > 0),
  bultos integer not null check (bultos > 0),
  precio_por_bulto bigint not null check (precio_por_bulto >= 0),
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  foreign key (lote_id, granja_id) references public.lotes (id, granja_id)
);

create table public.mortalidad (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  lote_id uuid not null,
  fecha date not null,
  cantidad integer not null check (cantidad > 0),
  causa text check (causa in ('calor', 'enfermedad', 'aplastamiento', 'otra')),
  nota text,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  foreign key (lote_id, granja_id) references public.lotes (id, granja_id)
);

create table public.medicamentos (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  lote_id uuid not null,
  fecha date not null,
  nombre text not null check (length(trim(nombre)) > 0),
  costo bigint not null check (costo >= 0),
  nota text,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  foreign key (lote_id, granja_id) references public.lotes (id, granja_id)
);

create table public.clientes (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  nombre text not null check (length(trim(nombre)) > 0),
  detalle text,
  telefono text,
  precio_libra_sugerido bigint check (precio_libra_sugerido > 0),
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  unique (id, granja_id)
);

create table public.ventas (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  lote_id uuid not null,
  cliente_id uuid not null,
  fecha date not null,
  pollos integer not null check (pollos > 0),
  libras numeric(8, 2) not null check (libras > 0),
  precio_libra bigint not null check (precio_libra >= 0),
  total bigint not null check (total = round(libras * precio_libra)),
  fiado boolean not null default false,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  foreign key (lote_id, granja_id) references public.lotes (id, granja_id),
  foreign key (cliente_id, granja_id) references public.clientes (id, granja_id)
);

create table public.abonos (
  id uuid primary key,
  granja_id uuid not null references public.granjas (id) on delete cascade,
  cliente_id uuid not null,
  fecha date not null,
  valor bigint not null check (valor > 0),
  recibido_por uuid references auth.users (id) on delete set null,
  creado_por uuid references auth.users (id) on delete set null,
  creado_en timestamptz not null default now(),
  actualizado_por uuid references auth.users (id) on delete set null,
  actualizado_en timestamptz,
  foreign key (cliente_id, granja_id) references public.clientes (id, granja_id)
);

create index on public.miembros (usuario_id);
create index on public.invitaciones (granja_id);
create index on public.lotes (granja_id);
create index on public.lotes (galpon_id);
create index on public.clientes (granja_id);
create index on public.compras_alimento (granja_id);
create index on public.compras_alimento (lote_id);
create index on public.mortalidad (granja_id);
create index on public.mortalidad (lote_id);
create index on public.medicamentos (granja_id);
create index on public.medicamentos (lote_id);
create index on public.ventas (granja_id);
create index on public.ventas (lote_id);
create index on public.ventas (cliente_id);
create index on public.abonos (granja_id);
create index on public.abonos (cliente_id);

-- 3. Quién puede ver y cambiar qué (RLS)
-- Las políticas usan "granja_id in (select ...)" para que Postgres calcule las
-- granjas del usuario una vez por consulta y no una vez por fila.

create function public.mis_granjas()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select granja_id from public.miembros where usuario_id = auth.uid();
$$;

create function public.granjas_que_administro()
returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select granja_id from public.miembros
  where usuario_id = auth.uid() and rol in ('dueno', 'administrador');
$$;

-- security definer porque una política de miembros no puede consultar
-- miembros sin entrar en recursión.
create function public.es_dueno(id_granja uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.miembros
    where granja_id = id_granja and usuario_id = auth.uid() and rol = 'dueno'
  );
$$;

alter table public.granjas enable row level security;
alter table public.miembros enable row level security;
alter table public.perfiles enable row level security;
alter table public.invitaciones enable row level security;
alter table public.galpones enable row level security;
alter table public.lotes enable row level security;
alter table public.compras_alimento enable row level security;
alter table public.mortalidad enable row level security;
alter table public.medicamentos enable row level security;
alter table public.clientes enable row level security;
alter table public.ventas enable row level security;
alter table public.abonos enable row level security;

create policy "ver mis granjas" on public.granjas for select to authenticated
  using (id in (select public.mis_granjas()));
create policy "renombrar" on public.granjas for update to authenticated
  using (id in (select public.granjas_que_administro()));
create policy "borrar solo el dueno" on public.granjas for delete to authenticated
  using (public.es_dueno(id));

create policy "ver compañeros" on public.miembros for select to authenticated
  using (granja_id in (select public.mis_granjas()));
create policy "cambiar rol solo el dueno" on public.miembros for update to authenticated
  using (public.es_dueno(granja_id)) with check (public.es_dueno(granja_id));
create policy "salir o sacar" on public.miembros for delete to authenticated
  using (usuario_id = (select auth.uid()) or public.es_dueno(granja_id));

create policy "ver perfiles de compañeros" on public.perfiles for select to authenticated
  using (
    id = (select auth.uid())
    or id in (select usuario_id from public.miembros)
  );
create policy "crear mi perfil" on public.perfiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy "editar mi perfil" on public.perfiles for update to authenticated
  using (id = (select auth.uid()));

create policy "ver invitaciones" on public.invitaciones for select to authenticated
  using (granja_id in (select public.granjas_que_administro()));
create policy "anular invitaciones" on public.invitaciones for delete to authenticated
  using (granja_id in (select public.granjas_que_administro()));

-- Galpones y lotes: todos los ven, solo dueño y administrador los cambian.
do $$
declare
  tabla text;
begin
  foreach tabla in array array['galpones', 'lotes'] loop
    execute format(
      'create policy "ver" on public.%I for select to authenticated
         using (granja_id in (select public.mis_granjas()))', tabla);
    execute format(
      'create policy "crear" on public.%I for insert to authenticated
         with check (granja_id in (select public.granjas_que_administro()))', tabla);
    execute format(
      'create policy "editar" on public.%I for update to authenticated
         using (granja_id in (select public.granjas_que_administro()))', tabla);
    execute format(
      'create policy "borrar" on public.%I for delete to authenticated
         using (granja_id in (select public.granjas_que_administro()))', tabla);
  end loop;
end;
$$;

-- Registros del día a día: cualquier miembro los crea; el trabajador solo
-- edita o borra lo que él mismo registró.
do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'compras_alimento', 'mortalidad', 'medicamentos', 'clientes', 'ventas', 'abonos'
  ] loop
    execute format(
      'create policy "ver" on public.%I for select to authenticated
         using (granja_id in (select public.mis_granjas()))', tabla);
    execute format(
      'create policy "crear" on public.%I for insert to authenticated
         with check (granja_id in (select public.mis_granjas()))', tabla);
    execute format(
      'create policy "editar" on public.%I for update to authenticated
         using (
           granja_id in (select public.granjas_que_administro())
           or (creado_por = (select auth.uid()) and granja_id in (select public.mis_granjas()))
         )', tabla);
    execute format(
      'create policy "borrar" on public.%I for delete to authenticated
         using (
           granja_id in (select public.granjas_que_administro())
           or (creado_por = (select auth.uid()) and granja_id in (select public.mis_granjas()))
         )', tabla);
  end loop;
end;
$$;

-- 4. Granjas e invitaciones

create function public.crear_granja(nombre_granja text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  nueva uuid;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;
  insert into public.granjas (nombre) values (nombre_granja) returning id into nueva;
  insert into public.miembros (granja_id, usuario_id, rol)
  values (nueva, auth.uid(), 'dueno');
  return nueva;
end;
$$;

create function public.crear_invitacion(id_granja uuid, rol_invitado text default 'trabajador')
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  nuevo text;
begin
  if id_granja not in (select public.granjas_que_administro()) then
    raise exception 'Solo el dueño o un administrador pueden invitar personas';
  end if;
  nuevo := upper(substr(md5(gen_random_uuid()::text), 1, 8));
  insert into public.invitaciones (codigo, granja_id, rol, creada_por)
  values (nuevo, id_granja, rol_invitado, auth.uid());
  return nuevo;
end;
$$;

create function public.unirse_con_codigo(codigo_recibido text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  inv public.invitaciones;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;
  select * into inv from public.invitaciones
  where codigo = upper(trim(codigo_recibido))
  for update;
  if inv.codigo is null or inv.usada_en is not null or inv.vence_en < now() then
    raise exception 'Ese código no sirve: revisa que esté bien escrito o pide uno nuevo';
  end if;
  if exists (
    select 1 from public.miembros
    where granja_id = inv.granja_id and usuario_id = auth.uid()
  ) then
    raise exception 'Ya perteneces a esa granja';
  end if;
  insert into public.miembros (granja_id, usuario_id, rol)
  values (inv.granja_id, auth.uid(), inv.rol);
  update public.invitaciones set usada_por = auth.uid(), usada_en = now()
  where codigo = inv.codigo;
  return inv.granja_id;
end;
$$;

create function public.conservar_un_dueno()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if old.rol = 'dueno'
     and exists (select 1 from public.granjas where id = old.granja_id)
     and not exists (
       select 1 from public.miembros where granja_id = old.granja_id and rol = 'dueno'
     ) then
    raise exception 'La granja necesita al menos un dueño. Nombra a otro antes de salir.';
  end if;
  return null;
end;
$$;

create trigger conservar_un_dueno after update or delete on public.miembros
  for each row execute function public.conservar_un_dueno();

-- 5. Reglas del negocio que la base de datos hace cumplir

-- Quién creó y quién cambió cada registro lo pone la base de datos, no el
-- celular, para que nadie pueda registrar a nombre de otro.
create function public.sellar_autor()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.creado_por := auth.uid();
    new.creado_en := now();
  else
    new.granja_id := old.granja_id;
    new.creado_por := old.creado_por;
    new.creado_en := old.creado_en;
    new.actualizado_por := auth.uid();
    new.actualizado_en := now();
  end if;
  return new;
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
      'create trigger sellar_autor before insert or update on public.%I
         for each row execute function public.sellar_autor()', tabla);
  end loop;
end;
$$;

create function public.validar_registro_de_lote()
returns trigger
language plpgsql set search_path = ''
as $$
declare
  lote public.lotes;
begin
  select * into lote from public.lotes where id = new.lote_id;
  if lote.cerrado_en is not null then
    raise exception 'Este lote ya está cerrado. Reábrelo para registrar cambios.';
  end if;
  if new.fecha < lote.fecha_llegada then
    raise exception 'La fecha no puede ser anterior a la llegada del lote (%)',
      to_char(lote.fecha_llegada, 'DD/MM/YYYY');
  end if;
  return new;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array['compras_alimento', 'mortalidad', 'medicamentos', 'ventas'] loop
    execute format(
      'create trigger validar_registro_de_lote before insert or update on public.%I
         for each row execute function public.validar_registro_de_lote()', tabla);
  end loop;
end;
$$;

-- No dejar vender ni registrar muertos de más. La fila que se edita no se
-- cuenta dos veces. security definer para que el bloqueo del lote funcione
-- también con un trabajador, que no puede editar lotes.
create function public.validar_salida_de_pollos()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  quedan integer;
  salen integer;
begin
  -- Bloquea el lote para que dos celulares no saquen los mismos pollos a la vez.
  perform 1 from public.lotes where id = new.lote_id for update;

  select l.cantidad_inicial
    - coalesce((select sum(m.cantidad) from public.mortalidad m
                where m.lote_id = l.id and m.id <> new.id), 0)
    - coalesce((select sum(v.pollos) from public.ventas v
                where v.lote_id = l.id and v.id <> new.id), 0)
  into quedan
  from public.lotes l
  where l.id = new.lote_id;

  if tg_table_name = 'ventas' then
    salen := new.pollos;
  else
    salen := new.cantidad;
  end if;

  if salen > quedan then
    raise exception 'Solo quedan % pollos vivos en este lote', quedan;
  end if;
  return new;
end;
$$;

create trigger validar_salida_de_pollos before insert or update on public.ventas
  for each row execute function public.validar_salida_de_pollos();
create trigger validar_salida_de_pollos before insert or update on public.mortalidad
  for each row execute function public.validar_salida_de_pollos();

create function public.validar_cantidad_inicial()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  salieron integer;
begin
  select coalesce((select sum(cantidad) from public.mortalidad where lote_id = new.id), 0)
       + coalesce((select sum(pollos) from public.ventas where lote_id = new.id), 0)
  into salieron;
  if new.cantidad_inicial < salieron then
    raise exception 'Ya salieron % pollos de este lote entre muertos y vendidos', salieron;
  end if;
  return new;
end;
$$;

create trigger validar_cantidad_inicial before update of cantidad_inicial on public.lotes
  for each row when (new.cantidad_inicial < old.cantidad_inicial)
  execute function public.validar_cantidad_inicial();

-- Nadie puede quedar debiendo menos de cero: ni abonando de más ni borrando o
-- cambiando una venta fiada que ya estaba abonada.
create function public.revisar_saldo(id_cliente uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  cliente text;
  saldo bigint;
begin
  -- Bloquea al cliente para que dos abonos al mismo tiempo no pasen los dos.
  select nombre into cliente from public.clientes where id = id_cliente for update;
  select coalesce((select sum(total) from public.ventas
                   where cliente_id = id_cliente and fiado), 0)
       - coalesce((select sum(valor) from public.abonos
                   where cliente_id = id_cliente), 0)
  into saldo;
  if saldo < 0 then
    raise exception 'Con este cambio los abonos de % superan lo que compró fiado por $%',
      cliente, replace(to_char(-saldo, 'FM999,999,999,999'), ',', '.');
  end if;
end;
$$;

create function public.validar_saldo_cliente()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if tg_op <> 'DELETE' then
    perform public.revisar_saldo(new.cliente_id);
  end if;
  if tg_op = 'DELETE' then
    perform public.revisar_saldo(old.cliente_id);
  elsif tg_op = 'UPDATE' then
    if old.cliente_id <> new.cliente_id then
      perform public.revisar_saldo(old.cliente_id);
    end if;
  end if;
  return null;
end;
$$;

create trigger validar_saldo_cliente after insert or update on public.abonos
  for each row execute function public.validar_saldo_cliente();
create trigger validar_saldo_cliente after update or delete on public.ventas
  for each row execute function public.validar_saldo_cliente();

-- 6. Vistas con los totales

create view public.resumen_lotes with (security_invoker = true) as
select
  l.id,
  l.granja_id,
  l.galpon_id,
  g.nombre as galpon,
  l.fecha_llegada,
  l.cerrado_en,
  l.cantidad_inicial,
  coalesce(m.muertos, 0) as muertos,
  coalesce(v.vendidos, 0) as vendidos,
  l.cantidad_inicial - coalesce(m.muertos, 0) - coalesce(v.vendidos, 0) as vivos,
  coalesce(v.libras, 0) as libras_vendidas,
  l.precio_compra_total as costo_pollos,
  coalesce(a.costo_inicio, 0) as costo_alimento_inicio,
  coalesce(a.costo_engorde, 0) as costo_alimento_engorde,
  coalesce(a.costo_inicio, 0) + coalesce(a.costo_engorde, 0) as costo_alimento,
  coalesce(md.costo, 0) as costo_medicina,
  l.precio_compra_total + coalesce(a.costo_inicio, 0) + coalesce(a.costo_engorde, 0)
    + coalesce(md.costo, 0) as inversion,
  coalesce(v.total, 0) as ventas,
  coalesce(v.total, 0)
    - (l.precio_compra_total + coalesce(a.costo_inicio, 0) + coalesce(a.costo_engorde, 0)
       + coalesce(md.costo, 0)) as ganancia
from public.lotes l
join public.galpones g on g.id = l.galpon_id
left join (
  select lote_id, sum(cantidad) as muertos from public.mortalidad group by lote_id
) m on m.lote_id = l.id
left join (
  select lote_id, sum(pollos) as vendidos, sum(libras) as libras, sum(total)::bigint as total
  from public.ventas group by lote_id
) v on v.lote_id = l.id
left join (
  select lote_id,
    sum(bultos * precio_por_bulto) filter (where tipo = 'inicio')::bigint as costo_inicio,
    sum(bultos * precio_por_bulto) filter (where tipo = 'engorde')::bigint as costo_engorde
  from public.compras_alimento group by lote_id
) a on a.lote_id = l.id
left join (
  select lote_id, sum(costo)::bigint as costo from public.medicamentos group by lote_id
) md on md.lote_id = l.id;

create view public.saldo_clientes with (security_invoker = true) as
select
  c.id,
  c.granja_id,
  c.nombre,
  c.detalle,
  c.telefono,
  coalesce(f.fiado, 0) as total_fiado,
  coalesce(ab.abonado, 0) as total_abonado,
  coalesce(f.fiado, 0) - coalesce(ab.abonado, 0) as saldo,
  coalesce(u.precio_libra, c.precio_libra_sugerido) as precio_libra_sugerido
from public.clientes c
left join (
  select cliente_id, sum(total)::bigint as fiado from public.ventas where fiado group by cliente_id
) f on f.cliente_id = c.id
left join (
  select cliente_id, sum(valor)::bigint as abonado from public.abonos group by cliente_id
) ab on ab.cliente_id = c.id
left join lateral (
  select precio_libra from public.ventas
  where cliente_id = c.id
  order by fecha desc, creado_en desc
  limit 1
) u on true;

-- 7. Permisos de las funciones
-- Supabase deja que cualquiera llame funciones públicas por la API; solo se
-- abren las que la app usa y las que necesitan las políticas.

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.mis_granjas() to authenticated;
grant execute on function public.granjas_que_administro() to authenticated;
grant execute on function public.es_dueno(uuid) to authenticated;
grant execute on function public.crear_granja(text) to authenticated;
grant execute on function public.crear_invitacion(uuid, text) to authenticated;
grant execute on function public.unirse_con_codigo(text) to authenticated;
