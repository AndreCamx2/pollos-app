-- Los clientes que compraron una vez y no se espera que vuelvan se marcan
-- como no recurrentes: la app los manda al final de la lista en vez de
-- borrarlos, así no se pierden sus ventas.
alter table public.clientes add column recurrente boolean not null default true;
