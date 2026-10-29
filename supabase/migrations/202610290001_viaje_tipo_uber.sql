-- RideMove: viaje tipo Uber (coordenadas, tarifa por distancia y tiempo, "conductor llegó",
-- cancelaciones, conductores cercanos y calificación promedio).
-- Ejecutar UNA vez, después de 202610280001_cedula_wompi.sql.
begin;

-- 1. Tarifa (una sola fila, editable por SQL) ------------------------------------------------
create table if not exists public.tariff (
 id boolean primary key default true check (id),
 base_cents bigint not null default 350000 check (base_cents >= 0),       -- banderazo $3.500
 per_km_cents bigint not null default 110000 check (per_km_cents >= 0),   -- $1.100 por km
 per_min_cents bigint not null default 25000 check (per_min_cents >= 0),  -- $250 por minuto
 minimum_cents bigint not null default 600000 check (minimum_cents > 0),  -- mínima $6.000
 updated_at timestamptz not null default now()
);
insert into public.tariff(id) values (true) on conflict do nothing;
alter table public.tariff enable row level security;
create policy tariff_read on public.tariff for select to authenticated using (true);
revoke all on public.tariff from anon,authenticated;
grant select on public.tariff to authenticated;

-- Precio redondeado a la centena de pesos (10.000 centavos), nunca menor a la mínima.
create or replace function public.fare_for(p_distance_m integer, p_duration_s integer) returns bigint
language sql stable security definer set search_path = '' as $$
 select greatest(t.minimum_cents,
   round((t.base_cents + t.per_km_cents * greatest(coalesce(p_distance_m,0),0) / 1000.0
          + t.per_min_cents * greatest(coalesce(p_duration_s,0),0) / 60.0) / 10000.0) * 10000)::bigint
 from public.tariff t where t.id;
$$;

-- 2. Datos del viaje ---------------------------------------------------------------------------
alter table public.trips
  add column if not exists origin_lat double precision check (origin_lat between -90 and 90),
  add column if not exists origin_lng double precision check (origin_lng between -180 and 180),
  add column if not exists destination_lat double precision check (destination_lat between -90 and 90),
  add column if not exists destination_lng double precision check (destination_lng between -180 and 180),
  add column if not exists distance_m integer check (distance_m between 0 and 500000),
  add column if not exists duration_s integer check (duration_s between 0 and 86400),
  add column if not exists fare_cents bigint check (fare_cents > 0),
  add column if not exists payment_method text not null default 'cash' check (payment_method in ('cash','wompi')),
  add column if not exists accepted_at timestamptz,
  add column if not exists arrived_at timestamptz,
  add column if not exists started_at timestamptz,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancelled_by text check (cancelled_by in ('passenger','driver','system'));

alter table public.trips drop constraint if exists trips_status_check;
alter table public.trips add constraint trips_status_check
  check (status in ('pending','accepted','arrived','in_progress','completed','cancelled'));
drop index if exists public.one_active_passenger_trip;
create unique index one_active_passenger_trip on public.trips(passenger_id) where status in ('pending','accepted','arrived','in_progress');
drop index if exists public.one_active_driver_trip;
create unique index one_active_driver_trip on public.trips(driver_id) where status in ('accepted','arrived','in_progress');

alter table public.profiles
  add column if not exists rating_avg numeric(3,2),
  add column if not exists rating_count integer not null default 0;

-- 3. Solicitar viaje con coordenadas: la tarifa la calcula la base de datos -----------------
create or replace function public.request_trip(
  p_origin text, p_destination text,
  p_origin_lat double precision default null, p_origin_lng double precision default null,
  p_destination_lat double precision default null, p_destination_lng double precision default null,
  p_distance_m integer default null, p_duration_s integer default null,
  p_payment_method text default 'cash') returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_distance integer := p_distance_m; v_straight double precision;
begin
 if public.my_role() is distinct from 'passenger' then raise exception 'Solo pasajeros'; end if;
 if coalesce(p_payment_method,'cash') not in ('cash','wompi') then raise exception 'Medio de pago inválido'; end if;
 if p_origin_lat is not null and p_destination_lat is not null then
  -- Distancia en línea recta (haversine): la ruta informada nunca puede ser menor.
  v_straight := 6371000 * 2 * asin(sqrt(power(sin(radians(p_destination_lat - p_origin_lat) / 2), 2)
     + cos(radians(p_origin_lat)) * cos(radians(p_destination_lat)) * power(sin(radians(p_destination_lng - p_origin_lng) / 2), 2)));
  if v_straight < 80 then raise exception 'El origen y el destino están demasiado cerca'; end if;
  v_distance := greatest(coalesce(v_distance, 0), ceil(v_straight)::integer);
 end if;
 insert into public.trips(passenger_id,origin,destination,origin_lat,origin_lng,destination_lat,destination_lng,
                          distance_m,duration_s,fare_cents,payment_method)
 values(auth.uid(),trim(p_origin),trim(p_destination),p_origin_lat,p_origin_lng,p_destination_lat,p_destination_lng,
        v_distance,p_duration_s,public.fare_for(v_distance,p_duration_s),coalesce(p_payment_method,'cash'))
 returning id into v_id;
 return v_id;
exception when unique_violation then raise exception 'Ya tienes un viaje activo';
end; $$;

-- Compatibilidad: la solicitud sin coordenadas cobra la tarifa mínima.
create or replace function public.create_trip(p_origin text,p_destination text) returns void
language plpgsql security definer set search_path = '' as $$
begin perform public.request_trip(p_origin,p_destination); end; $$;

-- 4. Estados: pending → accepted → arrived → in_progress → completed --------------------------
create or replace function public.transition_trip(p_id uuid,p_status text) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.trips; r text;
begin
 r := public.my_role();
 if r is null then raise exception 'Cuenta no disponible'; end if;
 select * into t from public.trips where id=p_id for update;
 if not found then raise exception 'Solicitud no encontrada'; end if;
 if p_status='cancelled' and t.status in ('pending','accepted','arrived') and t.passenger_id=auth.uid() and r='passenger' then
  update public.trips set status='cancelled',cancelled_at=now(),cancelled_by='passenger' where id=p_id;
 elsif p_status='accepted' and t.status='pending' and r='driver' then
  perform 1 from public.profiles where id=auth.uid() and available and active for update;
  if not found then raise exception 'Conéctate para aceptar viajes'; end if;
  if not exists(select 1 from public.vehicles where driver_id=auth.uid()) then raise exception 'Registra tu vehículo'; end if;
  if exists(select 1 from public.rejections where trip_id=p_id and driver_id=auth.uid()) then raise exception 'Ya rechazaste esta solicitud'; end if;
  update public.trips set status='accepted',driver_id=auth.uid(),accepted_at=now() where id=p_id;
 elsif t.driver_id=auth.uid() and r='driver' and p_status='pending' and t.status in ('accepted','arrived') then
  -- El conductor libera el viaje: vuelve a la cola para otros conductores.
  insert into public.rejections values(p_id,auth.uid()) on conflict do nothing;
  update public.trips set status='pending',driver_id=null,accepted_at=null,arrived_at=null where id=p_id;
 elsif t.driver_id=auth.uid() and r='driver' and t.status='accepted' and p_status='arrived' then
  update public.trips set status='arrived',arrived_at=now() where id=p_id;
 elsif t.driver_id=auth.uid() and r='driver' and t.status in ('accepted','arrived') and p_status='in_progress' then
  update public.trips set status='in_progress',started_at=now() where id=p_id;
 elsif t.driver_id=auth.uid() and r='driver' and t.status='in_progress' and p_status='completed' then
  update public.trips set status='completed',completed_at=now() where id=p_id;
 else raise exception 'Transición no permitida o solicitud ya atendida'; end if;
exception when unique_violation then raise exception 'Ya tienes un viaje en curso';
end; $$;

-- 5. Ubicación: el conductor conectado comparte su posición aunque no tenga viaje -------------
create or replace function public.save_location(p_latitude double precision,p_longitude double precision)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() is distinct from 'driver' then raise exception 'Solo conductores'; end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and available)
    and not exists(select 1 from public.trips where driver_id=auth.uid() and status in ('accepted','arrived','in_progress'))
 then raise exception 'Conéctate para compartir tu ubicación'; end if;
 insert into public.locations values(auth.uid(),p_latitude,p_longitude,now())
 on conflict(driver_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,updated_at=now();
end; $$;

drop policy if exists locations_read on public.locations;
create policy locations_read on public.locations for select to authenticated using (
 public.my_role() is not null and (driver_id = auth.uid() or public.my_role() = 'admin' or exists(
  select 1 from public.trips t where t.driver_id = locations.driver_id and t.passenger_id = auth.uid()
  and t.status in ('accepted','arrived','in_progress')))
);

-- Conductores conectados cerca (posición aproximada ~100 m, sin identidad).
create or replace function public.nearby_drivers(p_lat double precision,p_lng double precision)
returns table(latitude double precision, longitude double precision, distance_m integer)
language sql stable security definer set search_path = '' as $$
 select round(l.latitude::numeric,3)::double precision, round(l.longitude::numeric,3)::double precision,
        d.meters::integer
 from public.locations l
 join public.profiles p on p.id = l.driver_id and p.role='driver' and p.active and p.available
 cross join lateral (select 6371000 * 2 * asin(sqrt(power(sin(radians(l.latitude - p_lat) / 2), 2)
     + cos(radians(p_lat)) * cos(radians(l.latitude)) * power(sin(radians(l.longitude - p_lng) / 2), 2))) as meters) d
 where public.my_role() is not null and l.updated_at > now() - interval '5 minutes' and d.meters < 8000
   and not exists(select 1 from public.trips t where t.driver_id = l.driver_id and t.status in ('accepted','arrived','in_progress'))
 order by d.meters limit 15;
$$;

-- 6. Calificación promedio del conductor ----------------------------------------------------------
create or replace function public.rate_trip(p_id uuid,p_rating integer,p_comment text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_driver uuid;
begin
 if public.my_role() is distinct from 'passenger' then raise exception 'Solo pasajeros'; end if;
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Calificación fuera de rango'; end if;
 update public.trips set rating=p_rating,comment=coalesce(p_comment,'')
 where id=p_id and passenger_id=auth.uid() and status='completed' and rating is null returning driver_id into v_driver;
 if not found then raise exception 'No puedes calificar este viaje'; end if;
 update public.profiles p set rating_count = s.n, rating_avg = s.avg
 from (select count(*) n, round(avg(rating)::numeric,2) avg from public.trips where driver_id=v_driver and rating is not null) s
 where p.id = v_driver;
end; $$;

revoke execute on function public.fare_for(integer,integer),
  public.request_trip(text,text,double precision,double precision,double precision,double precision,integer,integer,text),
  public.nearby_drivers(double precision,double precision) from public,anon;
grant execute on function public.fare_for(integer,integer),
  public.request_trip(text,text,double precision,double precision,double precision,double precision,integer,integer,text),
  public.nearby_drivers(double precision,double precision) to authenticated;
commit;
