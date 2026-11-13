-- Al cerrar un lote, los pollos que no aparecen (robados, perdidos o mal
-- contados) se anotan como faltantes, aparte de los que se murieron, para que
-- la mortalidad salga real.
alter table public.mortalidad drop constraint mortalidad_causa_check;
alter table public.mortalidad add constraint mortalidad_causa_check
  check (causa in ('calor', 'enfermedad', 'aplastamiento', 'otra', 'faltante'));
