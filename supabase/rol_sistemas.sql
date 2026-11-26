-- MyIVA · rol Sistemas (Agencia Kairos)
-- Mismo poder que Administrador (es_admin = true), etiqueta distinta.
-- Supabase → SQL Editor → Run completo.

-- 1) Permitir el valor 'sistemas' en perfiles.rol
alter table public.perfiles drop constraint if exists perfiles_rol_check;
alter table public.perfiles
  add constraint perfiles_rol_check
  check (rol in ('admin', 'empleado', 'sistemas'));

-- 2) Admin + Sistemas pasan es_admin() (RLS, admin_set_password, cartera total…)
create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and activo and rol in ('admin', 'sistemas')
  );
$$;

-- 3) Alta desde Auth: IGNORAR metadata (SUP-02). Rol/nombre los pone el admin en perfiles.
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

-- 4) Usuario Sistemas / Agencia Kairos (mail: sistemas.myiva@blasco.com.ar, rol sistemas).
-- Crear/rotar clave FUERA de git:
--   select public.asegurar_usuario('sistemas.myiva@blasco.com.ar', '<password_rotada>', 'Sistemas', 'sistemas');


-- Primer ingreso sin forzar cambio de clave (acceso de agencia)
update public.perfiles
set debe_cambiar_pw = false
where lower(email) = 'sistemas.myiva@blasco.com.ar';

update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Sistemas', 'rol', 'sistemas')
where lower(email) = 'sistemas.myiva@blasco.com.ar';
