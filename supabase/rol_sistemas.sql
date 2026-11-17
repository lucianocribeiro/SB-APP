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

-- 3) Alta desde Auth: respetar rol sistemas en el metadata
create or replace function public.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, email, nombre, rol)
  values (
    new.id,
    new.email,
    coalesce(nullif(new.raw_user_meta_data->>'nombre', ''), split_part(new.email, '@', 1)),
    case
      when new.raw_user_meta_data->>'rol' in ('admin', 'sistemas')
        then new.raw_user_meta_data->>'rol'
      else 'empleado'
    end
  )
  on conflict (id) do nothing;
  return new;
end $$;
