-- MyIVA · reset login de usuarios del estudio
-- NO commitear contraseñas. Pasarlas al ejecutar en Supabase SQL Editor.
-- Ejemplo (reemplazar :pw_* por valores que NO queden en git):
--   select public.asegurar_usuario('danielac@blasco.com.ar', :'pw_daniela', 'Daniela', 'admin');

-- Usuarios esperados (solo mails/roles; la clave se define fuera del repo):
--   danielac@blasco.com.ar       admin
--   julietad@blasco.com.ar       empleado
--   agustinm@blasco.com.ar       empleado
--   candelariam@blasco.com.ar    empleado
--   ivannav@blasco.com.ar        empleado
--   ruben@blasco.com.ar          empleado
--   sistemas.myiva@blasco.com.ar sistemas

-- Ejecutar desde un canal seguro (1Password / Vercel env / SQL Editor local), p.ej.:
-- select public.asegurar_usuario('<mail>', '<password_rotada>', '<nombre>', '<rol>');
