-- MyIVA · reset login de TODOS los usuarios reales del estudio
-- Por si vuelve a fallar otro: un solo Run arregla a todos.
-- Supabase → SQL Editor → Run completo.

-- Daniela (admin)
select public.asegurar_usuario('danielac@blasco.com.ar', 'MyIVA-Daniela-2026!', 'Daniela', 'admin');
-- Julieta
select public.asegurar_usuario('julietad@blasco.com.ar', 'MyIVA-Julieta-2026!', 'Julieta', 'empleado');
-- Agustín / Candelaria / Ivanna (mails correctos)
select public.asegurar_usuario('agustinm@blasco.com.ar', 'MyIVA-Agustin-2026!', 'Agustín', 'empleado');
select public.asegurar_usuario('candelariam@blasco.com.ar', 'MyIVA-Candelaria-2026!', 'Candelaria', 'empleado');
select public.asegurar_usuario('ivannav@blasco.com.ar', 'MyIVA-Ivanna-2026!', 'Ivanna', 'empleado');
-- Rubén
select public.asegurar_usuario('ruben@blasco.com.ar', 'MyIVA-Ruben-2026!', 'Rubén', 'empleado');
-- Sistemas Kairos
select public.asegurar_usuario('sistemas.myiva@blasco.com.ar', 'MyIVA-Sistemas-2026!', 'Sistemas', 'sistemas');

-- Activar + no forzar cambio de clave
update public.perfiles set activo = true, debe_cambiar_pw = false
where lower(email) in (
  'danielac@blasco.com.ar',
  'julietad@blasco.com.ar',
  'agustinm@blasco.com.ar',
  'candelariam@blasco.com.ar',
  'ivannav@blasco.com.ar',
  'ruben@blasco.com.ar',
  'sistemas.myiva@blasco.com.ar'
);

-- Claves + mail confirmado (hash explícito)
update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Daniela-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Daniela', 'rol', 'admin'),
  updated_at = now(), banned_until = null
where lower(email) = 'danielac@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Julieta-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Julieta', 'rol', 'empleado'),
  updated_at = now(), banned_until = null
where lower(email) = 'julietad@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Agustin-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Agustín', 'rol', 'empleado'),
  updated_at = now(), banned_until = null
where lower(email) = 'agustinm@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Candelaria-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Candelaria', 'rol', 'empleado'),
  updated_at = now(), banned_until = null
where lower(email) = 'candelariam@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Ivanna-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Ivanna', 'rol', 'empleado'),
  updated_at = now(), banned_until = null
where lower(email) = 'ivannav@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Ruben-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Rubén', 'rol', 'empleado'),
  updated_at = now(), banned_until = null
where lower(email) = 'ruben@blasco.com.ar';

update auth.users set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  encrypted_password = extensions.crypt('MyIVA-Sistemas-2026!', extensions.gen_salt('bf')),
  raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
    || jsonb_build_object('must_change_pw', false, 'nombre', 'Sistemas', 'rol', 'sistemas'),
  updated_at = now(), banned_until = null
where lower(email) = 'sistemas.myiva@blasco.com.ar';

-- Identities faltantes
insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', u.id::text, now(), now(), now()
from auth.users u
where lower(u.email) in (
  'danielac@blasco.com.ar','julietad@blasco.com.ar','agustinm@blasco.com.ar',
  'candelariam@blasco.com.ar','ivannav@blasco.com.ar','ruben@blasco.com.ar',
  'sistemas.myiva@blasco.com.ar'
)
and not exists (
  select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email'
);

-- Apagar mails incorrectos / viejos
update public.perfiles set activo = false
where lower(email) in (
  'daniela@blasco.com.ar','agustin@blasco.com.ar','candelaria@blasco.com.ar',
  'ivanna@blasco.com.ar','victoria@blasco.com.ar','admin.myiva@blasco.com.ar'
);

-- Verificación final
select p.nombre, p.email, p.rol, p.activo,
  (u.email_confirmed_at is not null) as mail_ok,
  exists (select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email') as identity_ok
from public.perfiles p
join auth.users u on u.id = p.id
where p.activo = true
order by p.nombre;
