-- MyIVA · Daniela no entra → recrear con su mail real
-- Mail correcto (Outlook): danielac@blasco.com.ar
-- Clave: MyIVA-Daniela-2026!
-- Rol: admin
-- Supabase → SQL Editor → Run completo.

-- 1) Alta / reset con el mail REAL
select public.asegurar_usuario(
  'danielac@blasco.com.ar',
  'MyIVA-Daniela-2026!',
  'Daniela',
  'admin'
);

update public.perfiles
set email = 'danielac@blasco.com.ar',
    nombre = 'Daniela',
    rol = 'admin',
    activo = true,
    debe_cambiar_pw = false
where id = (select id from auth.users where lower(email) = 'danielac@blasco.com.ar' limit 1)
   or lower(email) = 'danielac@blasco.com.ar';

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = extensions.crypt('MyIVA-Daniela-2026!', extensions.gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Daniela', 'rol', 'admin'),
    updated_at = now()
where lower(email) = 'danielac@blasco.com.ar';

-- Identity email (necesaria para login)
insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', u.id::text, now(), now(), now()
from auth.users u
where lower(u.email) = 'danielac@blasco.com.ar'
  and not exists (
    select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email'
  );

-- 2) Apagar el mail mal tipado daniela@ (sin c) si quedó
update public.perfiles
set activo = false
where lower(email) = 'daniela@blasco.com.ar';

-- 3) Verificación
select
  p.nombre, p.email, p.rol, p.activo,
  (u.email_confirmed_at is not null) as mail_confirmado,
  exists (select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email') as identity_ok,
  length(u.encrypted_password) as pw_len
from public.perfiles p
join auth.users u on u.id = p.id
where lower(p.email) in ('danielac@blasco.com.ar', 'daniela@blasco.com.ar')
order by p.email;
