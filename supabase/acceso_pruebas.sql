-- Habilita los accesos rápidos del login (sin mail ni contraseña) para la etapa de pruebas.
-- Cualquiera con la dirección de la app puede leer y modificar los datos mientras esto esté activo.
-- Para desactivarlo, correr el bloque comentado del final.

do $$
declare t text;
begin
  foreach t in array array['clientes', 'liquidaciones', 'cruces', 'compensaciones', 'ddjj_pdf', 'apocrifos', 'config', 'auditoria'] loop
    execute format('drop policy if exists "pruebas" on public.%I', t);
    execute format('create policy "pruebas" on public.%I for all to anon using (true) with check (true)', t);
  end loop;
end $$;

drop policy if exists "pruebas" on public.perfiles;
create policy "pruebas" on public.perfiles for select to anon using (true);

drop policy if exists "ddjj pruebas" on storage.objects;
create policy "ddjj pruebas" on storage.objects for all to anon using (bucket_id = 'ddjj') with check (bucket_id = 'ddjj');

drop policy if exists "crudos pruebas" on storage.objects;
create policy "crudos pruebas" on storage.objects for all to anon using (bucket_id = 'crudos') with check (bucket_id = 'crudos');

-- Desactivar:
-- do $$ declare t text; begin
--   foreach t in array array['clientes','liquidaciones','cruces','compensaciones','ddjj_pdf','apocrifos','config','auditoria','perfiles'] loop
--     execute format('drop policy if exists "pruebas" on public.%I', t);
--   end loop;
-- end $$;
-- drop policy if exists "ddjj pruebas" on storage.objects;
-- drop policy if exists "crudos pruebas" on storage.objects;
