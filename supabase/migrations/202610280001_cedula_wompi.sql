-- RideMove: registro con documento (cédula) y pagos con Wompi.
-- Ejecutar UNA vez, después de las dos migraciones anteriores (SQL Editor o supabase db push).
begin;

-- 1. Documento de identidad en el perfil -------------------------------------------------
alter table public.profiles
  add column if not exists document_type text not null default 'CC'
    check (document_type in ('CC','CE','PP','TI')),
  add column if not exists document_number text
    check (document_number is null or document_number ~ '^[A-Za-z0-9]{5,16}$');
create unique index if not exists profiles_document_unique on public.profiles(document_number) where document_number is not null;

-- El perfil se crea desde los metadatos del registro (web o móvil).
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
declare doc text; dtype text;
begin
 doc := nullif(upper(regexp_replace(coalesce(new.raw_user_meta_data->>'document_number',''),'[^A-Za-z0-9]','','g')),'');
 dtype := upper(coalesce(nullif(new.raw_user_meta_data->>'document_type',''),'CC'));
 if dtype not in ('CC','CE','PP','TI') then dtype := 'CC'; end if;
 insert into public.profiles(id,name,phone,role,document_type,document_number) values(
   new.id,
   left(coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),'Usuario'),80),
   left(coalesce(trim(new.raw_user_meta_data->>'phone'),''),25),
   case when new.raw_user_meta_data->>'role' = 'driver' then 'driver' else 'passenger' end,
   dtype, doc);
 return new;
end; $$;
revoke execute on function public.handle_new_user() from public,anon,authenticated;

-- 2. Funciones solo para el backend (clave secreta service_role) ---------------------------
-- Inicio de sesión con cédula: devuelve el correo asociado al documento.
create or replace function public.login_email(p_document text) returns text language sql stable security definer set search_path = '' as $$
 select u.email from public.profiles p join auth.users u on u.id = p.id
 where p.document_number = upper(regexp_replace(coalesce(p_document,''),'[^A-Za-z0-9]','','g')) and p.active limit 1;
$$;
create or replace function public.document_registered(p_document text) returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.profiles where document_number = upper(regexp_replace(coalesce(p_document,''),'[^A-Za-z0-9]','','g')));
$$;
revoke execute on function public.login_email(text), public.document_registered(text) from public,anon,authenticated;
grant execute on function public.login_email(text), public.document_registered(text) to service_role;

-- 3. Pagos Wompi ----------------------------------------------------------------------------
create table if not exists public.payments (
 id uuid primary key default gen_random_uuid(),
 trip_id uuid not null references public.trips(id) on delete restrict,
 passenger_id uuid not null references public.profiles(id),
 reference text not null unique check (char_length(reference) between 8 and 64),
 amount_in_cents bigint not null check (amount_in_cents > 0),
 currency text not null default 'COP' check (currency = 'COP'),
 status text not null default 'PENDING' check (status in ('PENDING','APPROVED','DECLINED','VOIDED','ERROR')),
 wompi_transaction_id text,
 payment_method text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists payments_trip on public.payments(trip_id);
create unique index if not exists one_approved_payment_per_trip on public.payments(trip_id) where status = 'APPROVED';
alter table public.payments enable row level security;
create policy payments_read on public.payments for select to authenticated using (
 public.my_role() is not null and (public.my_role() = 'admin' or passenger_id = auth.uid()
  or exists(select 1 from public.trips t where t.id = payments.trip_id and t.driver_id = auth.uid()))
);
-- Escritura exclusiva del backend (service_role omite RLS); los clientes solo leen.
revoke all on public.payments from anon,authenticated;
grant select on public.payments to authenticated;
grant all on public.payments to service_role;
commit;
