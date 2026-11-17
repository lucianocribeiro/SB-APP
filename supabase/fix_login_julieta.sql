-- MyIVA · Julieta no entra → reset fuerte de mail/clave
-- Supabase → SQL Editor → Run completo.
-- Mail: julietad@blasco.com.ar
-- Clave: MyIVA-Julieta-2026!

select public.asegurar_usuario(
  'julietad@blasco.com.ar',
  'MyIVA-Julieta-2026!',
  'Julieta',
  'empleado'
);

update public.perfiles
set email = 'julietad@blasco.com.ar',
    nombre = 'Julieta',
    rol = 'empleado',
    activo = true,
    debe_cambiar_pw = false
where id = (select id from auth.users where lower(email) = 'julietad@blasco.com.ar' limit 1)
   or lower(email) = 'julietad@blasco.com.ar';

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = extensions.crypt('MyIVA-Julieta-2026!', extensions.gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Julieta', 'rol', 'empleado'),
    updated_at = now(),
    banned_until = null
where lower(email) = 'julietad@blasco.com.ar';

insert into auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', u.id::text, now(), now(), now()
from auth.users u
where lower(u.email) = 'julietad@blasco.com.ar'
  and not exists (
    select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email'
  );

-- Limpiar MFA colgado si hubiera
delete from auth.mfa_challenges
where factor_id in (
  select id from auth.mfa_factors
  where user_id = (select id from auth.users where lower(email) = 'julietad@blasco.com.ar')
);
delete from auth.mfa_factors
where user_id = (select id from auth.users where lower(email) = 'julietad@blasco.com.ar');

-- Verificación
select
  p.nombre, p.email, p.rol, p.activo, p.debe_cambiar_pw,
  (u.email_confirmed_at is not null) as mail_confirmado,
  exists (select 1 from auth.identities i where i.user_id = u.id and i.provider = 'email') as identity_ok,
  length(u.encrypted_password) as pw_len
from public.perfiles p
join auth.users u on u.id = p.id
where lower(p.email) = 'julietad@blasco.com.ar';
