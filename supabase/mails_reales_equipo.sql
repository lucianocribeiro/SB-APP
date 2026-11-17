-- MyIVA · mails correctos del equipo (Agustín, Candelaria, Ivanna)
-- Supabase → SQL Editor → Run completo.
--
-- Correctos:
--   agustinm@blasco.com.ar      / MyIVA-Agustin-2026!
--   candelariam@blasco.com.ar   / MyIVA-Candelaria-2026!
--   ivannav@blasco.com.ar       / MyIVA-Ivanna-2026!

-- 1) Crear / asegurar con mails reales
select public.asegurar_usuario('agustinm@blasco.com.ar', 'MyIVA-Agustin-2026!', 'Agustín', 'empleado');
select public.asegurar_usuario('candelariam@blasco.com.ar', 'MyIVA-Candelaria-2026!', 'Candelaria', 'empleado');
select public.asegurar_usuario('ivannav@blasco.com.ar', 'MyIVA-Ivanna-2026!', 'Ivanna', 'empleado');

update public.perfiles
set debe_cambiar_pw = false, activo = true, rol = 'empleado'
where lower(email) in (
  'agustinm@blasco.com.ar',
  'candelariam@blasco.com.ar',
  'ivannav@blasco.com.ar'
);

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = extensions.crypt('MyIVA-Agustin-2026!', extensions.gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Agustín', 'rol', 'empleado'),
    updated_at = now()
where lower(email) = 'agustinm@blasco.com.ar';

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = extensions.crypt('MyIVA-Candelaria-2026!', extensions.gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Candelaria', 'rol', 'empleado'),
    updated_at = now()
where lower(email) = 'candelariam@blasco.com.ar';

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = extensions.crypt('MyIVA-Ivanna-2026!', extensions.gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Ivanna', 'rol', 'empleado'),
    updated_at = now()
where lower(email) = 'ivannav@blasco.com.ar';

-- Identities email
insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', u.id::text, now(), now(), now()
from auth.users u
where lower(u.email) in (
  'agustinm@blasco.com.ar',
  'candelariam@blasco.com.ar',
  'ivannav@blasco.com.ar'
)
and not exists (
  select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email'
);

-- 2) Apagar mails viejos / incorrectos
update public.perfiles
set activo = false
where lower(email) in (
  'agustin@blasco.com.ar',
  'candelaria@blasco.com.ar',
  'ivanna@blasco.com.ar'
);

-- 3) Verificación
select nombre, email, rol, activo
from public.perfiles
where lower(nombre) in ('agustín', 'agustin', 'candelaria', 'ivanna')
   or lower(email) like 'agustin%'
   or lower(email) like 'candelaria%'
   or lower(email) like 'ivanna%'
order by nombre, email;
