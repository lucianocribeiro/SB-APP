-- MyIVA · Estudio Blasco · base de datos
-- Supabase → SQL Editor → pegar todo → Run. Se puede volver a correr sin romper nada.

-- 1) Perfiles: uno por cada usuario creado en Authentication → Users
create table if not exists public.perfiles (
  id      uuid primary key references auth.users(id) on delete cascade,
  email   text not null unique,
  nombre  text not null,                       -- nombre corto que muestra la app: Julieta, Rubén...
  rol     text not null default 'empleado' check (rol in ('admin', 'empleado')),
  activo  boolean not null default true,
  creado  timestamptz not null default now()
);

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.perfiles where id = auth.uid() and rol = 'admin' and activo);
$$;

create or replace function public.nuevo_usuario() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.perfiles (id, email, nombre, rol)
  values (new.id, new.email,
          coalesce(nullif(new.raw_user_meta_data->>'nombre', ''), split_part(new.email, '@', 1)),
          case when new.raw_user_meta_data->>'rol' = 'admin' then 'admin' else 'empleado' end)
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.nuevo_usuario();

insert into public.perfiles (id, email, nombre)
select id, email, split_part(email, '@', 1) from auth.users
on conflict (id) do nothing;

-- 2) Clientes y a qué usuario están asignados (usuario vacío = pendiente de asignación)
create table if not exists public.clientes (
  id       bigint generated always as identity primary key,
  nombre   text not null unique,
  cuit     text,
  usuario  text,
  creado   timestamptz not null default now()
);

-- 3) Liquidaciones procesadas
create table if not exists public.liquidaciones (
  id              text primary key,             -- cliente|período|secuencia|fecha
  cliente         text not null,
  periodo         text not null,                -- MM/AAAA
  secuencia       int  not null default 0,
  usuario         text,
  procesada       timestamptz not null default now(),
  debito          numeric(16,2) not null default 0,
  credito         numeric(16,2) not null default 0,
  retenciones     numeric(16,2) not null default 0,
  saldo1          numeric(16,2) not null default 0,
  saldo2          numeric(16,2) not null default 0,
  registros       int not null default 0,
  estado          text not null default 'Borrador' check (estado in ('Borrador', 'Cerrada')),
  borrada         boolean not null default false,
  motivo_borrado  text,
  errores         jsonb not null default '[]'
);
create index if not exists liquidaciones_cli_per on public.liquidaciones (cliente, periodo);
-- Primera liquidación de un cliente: saldos a favor del período anterior ingresados a mano en el cruce 0
alter table public.liquidaciones add column if not exists saldo_ant1 numeric(16,2);
alter table public.liquidaciones add column if not exists saldo_ant2 numeric(16,2);
-- Débito por alícuota (21 / 10,5 / 27) para el dashboard
alter table public.liquidaciones add column if not exists alicuotas jsonb;

-- 4) Historial de cruces
create table if not exists public.cruces (
  id           text primary key default gen_random_uuid()::text,
  cliente      text not null,
  periodo      text not null,
  secuencia    int  not null default 0,
  usuario      text,
  fecha        timestamptz not null default now(),
  liquidacion  boolean not null default false,
  cruces       jsonb not null default '[]'      -- cada cruce con su estado y errores
);
create index if not exists cruces_cli_per on public.cruces (cliente, periodo);

-- 5) Compensaciones de saldos a favor
create table if not exists public.compensaciones (
  id         text primary key default gen_random_uuid()::text,
  cliente    text not null,
  periodo    text not null,
  secuencia  int  not null default 0,
  monto      numeric(16,2) not null,
  usuario    text,
  fecha      timestamptz not null default now()
);
alter table public.compensaciones add column if not exists saldo2 numeric(16,2);   -- saldo a favor 2do párrafo de la DJ al registrar
create index if not exists compensaciones_dj on public.compensaciones (cliente, periodo, secuencia);
alter table public.compensaciones drop constraint if exists compensaciones_monto_pos;
alter table public.compensaciones add constraint compensaciones_monto_pos check (monto > 0) not valid;

-- Lo compensado contra una DJ no puede superar su saldo a favor de 2do párrafo,
-- aunque dos usuarios registren a la vez (el lock serializa las altas de la misma DJ).
create or replace function public.compensacion_valida() returns trigger
language plpgsql set search_path = public as $$
declare usado numeric;
begin
  if new.saldo2 is null then return new; end if;
  perform pg_advisory_xact_lock(hashtext(new.cliente || '|' || new.periodo || '|' || new.secuencia));
  select coalesce(sum(monto), 0) into usado from public.compensaciones
   where cliente = new.cliente and periodo = new.periodo and secuencia = new.secuencia and id <> new.id;
  if usado + new.monto > new.saldo2 then
    raise exception 'El monto supera el saldo a favor de 2do párrafo disponible ($ %)', greatest(new.saldo2 - usado, 0);
  end if;
  return new;
end $$;

drop trigger if exists compensacion_valida on public.compensaciones;
create trigger compensacion_valida before insert or update on public.compensaciones
  for each row execute function public.compensacion_valida();

-- 6) DDJJ en PDF adjuntas (el archivo va al bucket "ddjj" de Storage)
create table if not exists public.ddjj_pdf (
  liquidacion_id  text primary key,
  nombre          text not null,
  kb              int  not null default 0,
  ruta            text not null,
  usuario         text,
  fecha           timestamptz not null default now()
);

-- 7) Base APOC (facturas apócrifas) y configuración general
create table if not exists public.apocrifos (
  cuit               text primary key,
  fecha_condicion    text,
  fecha_publicacion  text
);

create table if not exists public.config (
  clave        text primary key,
  valor        jsonb not null,
  actualizado  timestamptz not null default now()
);

-- 8) Auditoría
create table if not exists public.auditoria (
  id         bigint generated always as identity primary key,
  fecha      timestamptz not null default now(),
  usuario    text,
  accion     text not null,
  cliente    text,
  periodo    text,
  resultado  text,
  ip         text
);

-- Seguridad: sólo usuarios logueados ven datos; lo sensible lo cambia sólo el admin
alter table public.perfiles  enable row level security;
alter table public.clientes  enable row level security;
alter table public.apocrifos enable row level security;
alter table public.config    enable row level security;
alter table public.auditoria enable row level security;

drop policy if exists "leer" on public.perfiles;
drop policy if exists "admin" on public.perfiles;
create policy "leer"  on public.perfiles for select to authenticated using (true);
create policy "admin" on public.perfiles for all    to authenticated using (public.es_admin()) with check (public.es_admin());

do $$
declare t text;
begin
  foreach t in array array['clientes', 'apocrifos', 'config'] loop
    execute format('drop policy if exists "leer" on public.%I', t);
    execute format('drop policy if exists "admin" on public.%I', t);
    execute format('create policy "leer" on public.%I for select to authenticated using (true)', t);
    execute format('create policy "admin" on public.%I for all to authenticated using (public.es_admin()) with check (public.es_admin())', t);
  end loop;
  foreach t in array array['liquidaciones', 'cruces', 'compensaciones', 'ddjj_pdf'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "equipo" on public.%I', t);
    execute format('create policy "equipo" on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

drop policy if exists "registrar" on public.auditoria;
drop policy if exists "admin lee" on public.auditoria;
create policy "registrar" on public.auditoria for insert to authenticated with check (true);
create policy "admin lee" on public.auditoria for select to authenticated using (public.es_admin());

-- Storage: bucket privado para los PDF de DDJJ (máx. 10 MB, sólo PDF)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ddjj', 'ddjj', false, 10485760, array['application/pdf'])
on conflict (id) do nothing;

drop policy if exists "ddjj equipo" on storage.objects;
create policy "ddjj equipo" on storage.objects for all to authenticated
  using (bucket_id = 'ddjj') with check (bucket_id = 'ddjj');

-- Storage: bucket privado con los archivos crudos de cada liquidación (subdiarios, Mis Comprobantes, etc.)
-- Una carpeta por liquidación; se usan para armar las hojas de crudos del Excel exportable.
insert into storage.buckets (id, name, public, file_size_limit)
values ('crudos', 'crudos', false, 20971520)
on conflict (id) do nothing;

drop policy if exists "crudos equipo" on storage.objects;
create policy "crudos equipo" on storage.objects for all to authenticated
  using (bucket_id = 'crudos') with check (bucket_id = 'crudos');

-- Carga inicial: la cartera actual de la app
insert into public.clientes (nombre, usuario) values
  ('LANES SA', 'Agustín'), ('JUANA Y SUS HERMANAS SRL', 'Agustín'), ('LHS WORLDWIDE SA', 'Agustín'), ('SEOB SA', 'Agustín'),
  ('CLAMACO S.A.', 'Candelaria'), ('BOVENCO S.A.', 'Candelaria'), ('FASECO S.A.', 'Candelaria'), ('VMP SA', 'Candelaria'),
  ('CREARFULL SAS', 'Candelaria'), ('REINA MARIA DEL PLATA I. Y C. S.C.A.', 'Candelaria'), ('WAHREN SA', 'Candelaria'),
  ('INVERCOSUD S.A.', 'Candelaria'), ('ADVITA SA', 'Candelaria'), ('KOI SRL', 'Candelaria'), ('MEDA Y CIA SCA', 'Candelaria'),
  ('INVOINET SAU', 'Ivanna'), ('AFARTE', 'Ivanna'), ('INVOTRADE SA', 'Ivanna'), ('GLOBAL DUNNING S.A.', 'Ivanna'),
  ('FINVOI CAPITAL SA', 'Ivanna'), ('ANDALUX SA', 'Ivanna'), ('SIOMAA S.A.', 'Ivanna'), ('SANTA CLARA DE ZAVALIA SRL', 'Ivanna'),
  ('FABIALVA SRL', 'Ivanna'), ('ZAGAR SRL', 'Ivanna'),
  ('IDEA 2 SA', 'Julieta'), ('NOVALUX S.A.', 'Julieta'), ('FIDEICOMISO PAMPA PILAR', 'Julieta'), ('DASYC SRL', 'Julieta'),
  ('DACKET SA', 'Julieta'), ('CAZATUR SA', 'Julieta'), ('RODIALE SA', 'Julieta'),
  ('GLOBAL MARKETING BUREAU S.A.', 'Rubén'), ('BCBT S.A.U.', 'Rubén'), ('BBI SA', 'Rubén'), ('MEDICAL LOGISTIC S.A.', 'Rubén'),
  ('BLASCO_SERGIO', 'Rubén'), ('NALAPO SA', 'Rubén'),
  ('CONSULTORA DEL PLATA SRL', null), ('ESTANCIA LA MARGARITA SA', null), ('TECNOAGRO SAS', null)
on conflict (nombre) do nothing;

-- Después de crear los usuarios en Authentication → Users, ajustar nombre y rol. Ejemplo:
-- update public.perfiles set nombre = 'Julieta' where email = 'julieta@...';
-- update public.perfiles set nombre = 'Administrador', rol = 'admin' where email = 'admin@...';
