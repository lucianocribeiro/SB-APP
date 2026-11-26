-- MyIVA · parche auditoría SUP-01 / SUP-02 / SUP-07
-- Fecha: 2026-11-26
--
-- QUÉ HACE:
--   SUP-01  Quita el EXECUTE de asegurar_usuario a anon/authenticated/public
--           (ya no se puede crear admins ni cambiar claves vía /rest/v1/rpc).
--   SUP-02  El trigger de alta IGNORA rol/nombre del metadata del signup:
--           siempre rol=empleado y nombre desde el mail. El admin asigna
--           nombre/rol/activo reales desde la app (update a perfiles).
--   SUP-07  Revoca EXECUTE a anon en las demás funciones (siguen para authenticated).
--
-- QUÉ NO HACE (a propósito):
--   ✗ No cambia ni rota ninguna contraseña existente.
--   ✗ No modifica usuarios, mails ni perfiles activos del equipo.
--   ✗ No toca buckets ni políticas de storage (SUP-03 = otro paso).
--
-- CÓMO APLICAR: Supabase → SQL Editor → pegar todo → Run.
-- Después NO hace falta avisar al equipo que cambien su clave.


-- ========== SUP-01 ==========
revoke execute on function public.asegurar_usuario(text, text, text, text)
  from public, anon, authenticated;
-- Solo el rol postgres (SQL Editor / service role) puede seguir usándola a mano.
grant execute on function public.asegurar_usuario(text, text, text, text) to postgres;


-- ========== SUP-02 ==========
create or replace function public.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, email, nombre, rol, activo, debe_cambiar_pw)
  values (
    new.id,
    new.email,
    split_part(new.email, '@', 1),
    'empleado',
    false,
    true
  )
  on conflict (id) do nothing;
  return new;
end $$;

revoke all on function public.nuevo_usuario() from public, anon, authenticated;


-- ========== SUP-07 ==========
revoke execute on function public.admin_set_password(text, text, boolean) from public, anon;
grant execute on function public.admin_set_password(text, text, boolean) to authenticated;

revoke execute on function public.marcar_pw_ok() from public, anon;
grant execute on function public.marcar_pw_ok() to authenticated;

revoke execute on function public.es_admin() from public, anon;
grant execute on function public.es_admin() to authenticated;

revoke execute on function public.mi_nombre() from public, anon;
grant execute on function public.mi_nombre() to authenticated;

revoke execute on function public.cliente_mio(text) from public, anon;
grant execute on function public.cliente_mio(text) to authenticated;


-- Verificación rápida (debe mostrar 0 filas con grantee anon sobre asegurar_usuario):
-- select grantee, privilege_type
-- from information_schema.routine_privileges
-- where routine_schema = 'public' and routine_name = 'asegurar_usuario';
