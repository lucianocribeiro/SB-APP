-- MyIVA · seguridad producción (Kairos)
-- Supabase → SQL Editor → Run. Después: Authentication → Providers → Email → desactivar "Confirm email"
-- (o confirmar a mano los usuarios de prueba) y Auth → Multi-Factor → habilitar TOTP.

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

-- 3) Liquidaciones / cruces / compensaciones / ddjj: admin todo; empleado sólo su cartera
do $$
declare t text;
begin
  foreach t in array array['liquidaciones', 'cruces', 'compensaciones', 'ddjj_pdf'] loop
    execute format('drop policy if exists "equipo" on public.%I', t);
    execute format('drop policy if exists "cartera" on public.%I', t);
    execute format(
      'create policy "cartera" on public.%I for all to authenticated using (public.cliente_mio(cliente)) with check (public.cliente_mio(cliente))',
      t
    );
  end loop;
end $$;

-- 4) Flag de cambio de contraseña obligatorio en perfiles
alter table public.perfiles add column if not exists debe_cambiar_pw boolean not null default false;

-- El usuario autenticado puede limpiar su propio flag (no puede tocar rol/nombre por acá).
create or replace function public.marcar_pw_ok() returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.perfiles set debe_cambiar_pw = false where id = auth.uid();
end $$;
revoke all on function public.marcar_pw_ok() from public;
grant execute on function public.marcar_pw_ok() to authenticated;

-- 5) Confirmar usuarios de acceso (si ya existen por signUp)
update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || '{"must_change_pw":true}'::jsonb
where email in ('admin.myiva@blasco.com.ar', 'usuario.myiva@blasco.com.ar');

update public.perfiles set
  nombre = case email
    when 'admin.myiva@blasco.com.ar' then 'Administrador'
    when 'usuario.myiva@blasco.com.ar' then 'UsuarioDemo'
    else nombre end,
  rol = case email
    when 'admin.myiva@blasco.com.ar' then 'admin'
    else coalesce(rol, 'empleado') end,
  activo = true,
  debe_cambiar_pw = true
where email in ('admin.myiva@blasco.com.ar', 'usuario.myiva@blasco.com.ar');

-- Asignar algunos clientes al usuario demo (si existen)
update public.clientes set usuario = 'UsuarioDemo'
where nombre in ('CAZATUR SA', 'DACKET SA', 'SIOMAA S.A.')
  and (usuario is null or usuario in ('Julieta', 'Ivanna', 'UsuarioDemo'));
