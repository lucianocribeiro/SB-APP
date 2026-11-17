-- MyIVA · seguridad producción (Kairos)
-- Supabase → SQL Editor → Run completo.
-- Después: Authentication → Multi-Factor → habilitar TOTP.
--
-- Credenciales que crea/activa este script:
--   Daniela    daniela@blasco.com.ar        / MyIVA-Daniela-2026!   (Administradora)
--   Demo       usuario.myiva@blasco.com.ar  / MyIVA-User-2026!
--   Julieta    julietad@blasco.com.ar       / MyIVA-Julieta-2026!
--   Victoria   victoria@blasco.com.ar       / MyIVA-Victoria-2026!
--   Agustín    agustin@blasco.com.ar        / MyIVA-Agustin-2026!
--   Candelaria candelaria@blasco.com.ar     / MyIVA-Candelaria-2026!
--   Ivanna     ivanna@blasco.com.ar         / MyIVA-Ivanna-2026!
--   Rubén      ruben@blasco.com.ar          / MyIVA-Ruben-2026!
--   Sistemas   sistemas.myiva@blasco.com.ar / MyIVA-Sistemas-2026!  (rol sistemas = poder admin)
--   (legacy)   admin.myiva@blasco.com.ar    → queda desactivado; admin real = Daniela

create extension if not exists pgcrypto with schema extensions;

-- 1) Cerrar modo pruebas (anon ya no lee/escribe todo)
do $$
declare t text;
begin
  foreach t in array array['clientes','liquidaciones','cruces','compensaciones','ddjj_pdf','apocrifos','config','auditoria','perfiles'] loop
    execute format('drop policy if exists "pruebas" on public.%I', t);
  end loop;
end $$;
drop policy if exists "ddjj pruebas" on storage.objects;
drop policy if exists "crudos pruebas" on storage.objects;

-- 2) Nombre del usuario logueado (para filtrar por cartera)
create or replace function public.mi_nombre() returns text
language sql stable security definer set search_path = public as $$
  select nombre from public.perfiles where id = auth.uid() and activo limit 1;
$$;

create or replace function public.cliente_mio(cli text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.es_admin()
    or exists (
      select 1 from public.clientes c
      where c.nombre = cli and c.usuario = public.mi_nombre()
    );
$$;

-- 3) Liquidaciones / cruces / compensaciones: admin todo; empleado sólo su cartera
do $$
declare t text;
begin
  foreach t in array array['liquidaciones', 'cruces', 'compensaciones'] loop
    execute format('drop policy if exists "equipo" on public.%I', t);
    execute format('drop policy if exists "cartera" on public.%I', t);
    execute format(
      'create policy "cartera" on public.%I for all to authenticated using (public.cliente_mio(cliente)) with check (public.cliente_mio(cliente))',
      t
    );
  end loop;
end $$;

-- ddjj_pdf no tiene columna cliente: el cliente va en liquidacion_id (cliente|per|seq|fecha)
drop policy if exists "equipo" on public.ddjj_pdf;
drop policy if exists "cartera" on public.ddjj_pdf;
create policy "cartera" on public.ddjj_pdf for all to authenticated
  using (public.cliente_mio(split_part(liquidacion_id, '|', 1)))
  with check (public.cliente_mio(split_part(liquidacion_id, '|', 1)));

-- 4) Flag de cambio de contraseña obligatorio en perfiles
alter table public.perfiles add column if not exists debe_cambiar_pw boolean not null default false;

create or replace function public.marcar_pw_ok() returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.perfiles set debe_cambiar_pw = false where id = auth.uid();
end $$;
revoke all on function public.marcar_pw_ok() from public;
grant execute on function public.marcar_pw_ok() to authenticated;

-- 5) Alta / confirmación de usuarios del estudio
create or replace function public.asegurar_usuario(
  p_email text,
  p_password text,
  p_nombre text,
  p_rol text default 'empleado'
) returns uuid
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  uid uuid;
  meta jsonb;
begin
  meta := jsonb_build_object('nombre', p_nombre, 'rol', p_rol, 'must_change_pw', true);

  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      lower(p_email), crypt(p_password, gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb, meta, now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), uid,
      jsonb_build_object('sub', uid::text, 'email', lower(p_email), 'email_verified', true),
      'email', uid::text, now(), now(), now()
    );
  else
    update auth.users set
      email_confirmed_at = coalesce(email_confirmed_at, now()),
      encrypted_password = crypt(p_password, gen_salt('bf')),
      raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || meta,
      updated_at = now()
    where id = uid;
    if not exists (select 1 from auth.identities where user_id = uid and provider = 'email') then
      insert into auth.identities (
        id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
      ) values (
        gen_random_uuid(), uid,
        jsonb_build_object('sub', uid::text, 'email', lower(p_email), 'email_verified', true),
        'email', uid::text, now(), now(), now()
      );
    end if;
  end if;

  insert into public.perfiles (id, email, nombre, rol, activo, debe_cambiar_pw)
  values (uid, lower(p_email), p_nombre, p_rol, true, true)
  on conflict (id) do update set
    email = excluded.email,
    nombre = excluded.nombre,
    rol = excluded.rol,
    activo = true,
    debe_cambiar_pw = true;

  return uid;
end $$;

select public.asegurar_usuario('daniela@blasco.com.ar', 'MyIVA-Daniela-2026!', 'Daniela', 'admin');
select public.asegurar_usuario('admin.myiva@blasco.com.ar', 'MyIVA-Admin-2026!', 'Administrador', 'admin');
select public.asegurar_usuario('usuario.myiva@blasco.com.ar', 'MyIVA-User-2026!', 'UsuarioDemo', 'empleado');
select public.asegurar_usuario('julietad@blasco.com.ar', 'MyIVA-Julieta-2026!', 'Julieta', 'empleado');
select public.asegurar_usuario('victoria@blasco.com.ar', 'MyIVA-Victoria-2026!', 'Victoria', 'empleado');
select public.asegurar_usuario('agustin@blasco.com.ar', 'MyIVA-Agustin-2026!', 'Agustín', 'empleado');
select public.asegurar_usuario('candelaria@blasco.com.ar', 'MyIVA-Candelaria-2026!', 'Candelaria', 'empleado');
select public.asegurar_usuario('ivanna@blasco.com.ar', 'MyIVA-Ivanna-2026!', 'Ivanna', 'empleado');
select public.asegurar_usuario('ruben@blasco.com.ar', 'MyIVA-Ruben-2026!', 'Rubén', 'empleado');
select public.asegurar_usuario('sistemas.myiva@blasco.com.ar', 'MyIVA-Sistemas-2026!', 'Sistemas', 'sistemas');
update public.perfiles set debe_cambiar_pw = false, activo = true where lower(email) in (
  'daniela@blasco.com.ar', 'victoria@blasco.com.ar', 'sistemas.myiva@blasco.com.ar'
);
update public.perfiles set activo = false where lower(email) = 'admin.myiva@blasco.com.ar';
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Daniela', 'rol', 'admin')
where lower(email) = 'daniela@blasco.com.ar';
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Victoria', 'rol', 'empleado')
where lower(email) = 'victoria@blasco.com.ar';
update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Sistemas', 'rol', 'sistemas')
where lower(email) = 'sistemas.myiva@blasco.com.ar';

-- 6) Admin puede resetear la contraseña de otro usuario desde la app
create or replace function public.admin_set_password(
  p_email text,
  p_password text,
  p_forzar boolean default true
) returns boolean
language plpgsql security definer set search_path = public, auth, extensions as $$
declare uid uuid;
begin
  if not public.es_admin() then
    raise exception 'Sólo un administrador puede cambiar contraseñas de otros usuarios';
  end if;
  if p_password is null or length(p_password) < 8 then
    raise exception 'La contraseña tiene que tener al menos 8 caracteres';
  end if;
  select id into uid from auth.users where lower(email) = lower(p_email);
  if uid is null then
    raise exception 'No hay usuario con el mail %', p_email;
  end if;
  update auth.users set
    encrypted_password = crypt(p_password, gen_salt('bf')),
    email_confirmed_at = coalesce(email_confirmed_at, now()),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', coalesce(p_forzar, true)),
    updated_at = now()
  where id = uid;
  update public.perfiles set debe_cambiar_pw = coalesce(p_forzar, true) where id = uid;
  return true;
end $$;
revoke all on function public.admin_set_password(text, text, boolean) from public;
grant execute on function public.admin_set_password(text, text, boolean) to authenticated;

-- Victoria entra a la cartera del estudio (sin clientes aún; se asignan en Clientes por usuario)
-- Los demás ya tienen clientes en public.clientes según schema.sql / CARTERA_DEF.
