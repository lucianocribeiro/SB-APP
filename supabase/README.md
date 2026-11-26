# Supabase · MyIVA

Scripts de esquema, RLS y utilidades. **No commitear contraseñas ni service role keys.**

- Altas / reset de login: usar `public.asegurar_usuario(mail, password, nombre, rol)` solo desde el SQL Editor o un canal seguro (1Password, etc.), nunca con la clave hardcodeada en un `.sql` del repo.
- Rotación: Authentication → Users en el dashboard de Supabase, o `admin_set_password` desde la app (admin).
- `SUPABASE_SERVICE_ROLE_KEY` y URLs van en variables de entorno (Vercel / local), no en git.

## Parche auditoría 2026-11-26 (SUP-01 / SUP-02 / SUP-07)

Correr **`parche_auditoria_sup01_02_07.sql`** en el SQL Editor.

- Cierra el agujero de `asegurar_usuario` (crear admins / cambiar claves sin login).
- El trigger de alta ya no toma rol/nombre del signup.
- **No rota ni cambia contraseñas de nadie.** Los usuarios de prod siguen igual.
- No hace falta pedirles que cambien clave ni mail.

Después (opcional, dashboard): Authentication → Attack Protection → habilitar *Leaked password protection* (SUP-06).
