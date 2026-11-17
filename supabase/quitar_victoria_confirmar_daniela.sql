-- MyIVA · Victoria NO es usuaria del estudio → desactivar
-- Daniela = Administradora
-- Supabase → SQL Editor → Run completo.

-- 1) Daniela admin
select public.asegurar_usuario(
  'daniela@blasco.com.ar',
  'MyIVA-Daniela-2026!',
  'Daniela',
  'admin'
);

update public.perfiles
set nombre = 'Daniela', rol = 'admin', activo = true, debe_cambiar_pw = false
where lower(email) = 'daniela@blasco.com.ar';

update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    encrypted_password = crypt('MyIVA-Daniela-2026!', gen_salt('bf')),
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('must_change_pw', false, 'nombre', 'Daniela', 'rol', 'admin'),
    updated_at = now()
where lower(email) = 'daniela@blasco.com.ar';

-- 2) Victoria no existe como persona del estudio → desactivar si quedó creada
update public.perfiles
set activo = false
where lower(email) = 'victoria@blasco.com.ar'
   or lower(nombre) = 'victoria';

-- 3) Admin genérico viejo sigue apagado
update public.perfiles set activo = false where lower(email) = 'admin.myiva@blasco.com.ar';

-- 4) Verificación
select nombre, email, rol, activo
from public.perfiles
where lower(email) in ('daniela@blasco.com.ar', 'victoria@blasco.com.ar', 'admin.myiva@blasco.com.ar')
   or lower(nombre) in ('daniela', 'victoria')
order by email;
