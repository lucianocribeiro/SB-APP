-- MyIVA · corrección usuarios (pedido Santiago / Daniela · 17/11/2026)
-- Supabase → SQL Editor → Run completo.
--
-- 1) Admin real = Daniela  · daniela@blasco.com.ar / MyIVA-Daniela-2026!
-- 2) Victoria (faltaba)   · victoria@blasco.com.ar / MyIVA-Victoria-2026!
-- 3) El admin genérico admin.myiva@blasco.com.ar queda desactivado.

-- Daniela como Administradora
select public.asegurar_usuario(
  'daniela@blasco.com.ar',
  'MyIVA-Daniela-2026!',
  'Daniela',
  'admin'
);

update public.perfiles
set debe_cambiar_pw = false, activo = true, rol = 'admin', nombre = 'Daniela'
where lower(email) = 'daniela@blasco.com.ar';

update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Daniela', 'rol', 'admin')
where lower(email) = 'daniela@blasco.com.ar';

-- Victoria (usuario de cartera)
select public.asegurar_usuario(
  'victoria@blasco.com.ar',
  'MyIVA-Victoria-2026!',
  'Victoria',
  'empleado'
);

update public.perfiles
set debe_cambiar_pw = false, activo = true, rol = 'empleado', nombre = 'Victoria'
where lower(email) = 'victoria@blasco.com.ar';

update auth.users
set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
  || jsonb_build_object('must_change_pw', false, 'nombre', 'Victoria', 'rol', 'empleado')
where lower(email) = 'victoria@blasco.com.ar';

-- Desactivar el admin genérico de prueba (ya no es el acceso del estudio)
update public.perfiles
set activo = false
where lower(email) = 'admin.myiva@blasco.com.ar';
