-- Hasta cuánto se le fía a cada cliente. La app avisa cuando una venta fiada
-- lo pasa, pero no la frena: quien decide es el dueño. Vacío es sin tope.
alter table public.clientes add column cupo_fiado bigint check (cupo_fiado > 0);
