#!/usr/bin/env bash
# Confirma los usuarios demo y deja perfiles listos. Requiere SUPABASE_SERVICE_ROLE_KEY.
set -euo pipefail
URL="${SUPABASE_URL:-https://ilazlcianywbzyisinlh.supabase.co}"
KEY="${SUPABASE_SERVICE_ROLE_KEY:?Falta SUPABASE_SERVICE_ROLE_KEY}"
for id_email in \
  "9e0d7a70-b13b-458e-885d-071c9d56125e|admin.myiva@blasco.com.ar|Administrador|admin" \
  "031da66d-a83e-4f72-86b7-3e3df87ac566|usuario.myiva@blasco.com.ar|UsuarioDemo|empleado"
do
  IFS='|' read -r id email nombre rol <<<"$id_email"
  curl -sS -X PUT "$URL/auth/v1/admin/users/$id" \
    -H "apikey: $KEY" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
    -d "{\"email_confirm\":true,\"user_metadata\":{\"nombre\":\"$nombre\",\"rol\":\"$rol\",\"must_change_pw\":true}}"
  echo
done
echo "Listo. Corré también supabase/seguridad_prod.sql en el SQL Editor."
