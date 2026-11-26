# Supabase · MyIVA

Scripts de esquema, RLS y utilidades. **No commitear contraseñas ni service role keys.**

- Altas / reset de login: usar `public.asegurar_usuario(mail, password, nombre, rol)` solo desde el SQL Editor o un canal seguro (1Password, etc.), nunca con la clave hardcodeada en un `.sql` del repo.
- Rotación: Authentication → Users en el dashboard de Supabase, o `admin_set_password` desde la app (admin).
- `SUPABASE_SERVICE_ROLE_KEY` y URLs van en variables de entorno (Vercel / local), no en git.
