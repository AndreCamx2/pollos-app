-- Cambiar a alguien de rol solo cambia el rol: la política deja actualizar
-- la fila entera, y así el dueño podría pasar a una persona a otra granja
-- suya o cambiarle la cuenta.
revoke update on public.miembros from anon, authenticated;
grant update (rol) on public.miembros to authenticated;
