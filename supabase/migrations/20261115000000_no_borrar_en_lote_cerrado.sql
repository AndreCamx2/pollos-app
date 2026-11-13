-- Un lote cerrado tampoco deja borrar lo que se anotó en él: hasta ahora la
-- base frenaba anotar y corregir, pero no borrar. Para borrar se reabre.
-- Cuando se borra la granja completa no se frena nada.
create function public.validar_borrado_de_registro()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from public.granjas where id = old.granja_id)
     and exists (
       select 1 from public.lotes where id = old.lote_id and cerrado_en is not null
     ) then
    raise exception 'Este lote ya está cerrado. Reábrelo para registrar cambios.';
  end if;
  return old;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array['compras_alimento', 'mortalidad', 'medicamentos', 'ventas'] loop
    execute format(
      'create trigger validar_borrado_de_registro before delete on public.%I
         for each row execute function public.validar_borrado_de_registro()', tabla);
  end loop;
end;
$$;

revoke execute on function public.validar_borrado_de_registro() from public, anon, authenticated;
