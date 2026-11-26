-- MyIVA · Victoria NO es usuaria del estudio → desactivar
-- NO commitear contraseñas.
update public.perfiles set activo = false
where lower(email) = 'victoria@blasco.com.ar' or lower(nombre) = 'victoria';

-- Confirmar Daniela admin (clave rotada, fuera de git):
-- select public.asegurar_usuario('danielac@blasco.com.ar', '<password_rotada>', 'Daniela', 'admin');
update public.perfiles set activo = true, rol = 'admin', debe_cambiar_pw = false
where lower(email) = 'danielac@blasco.com.ar';
