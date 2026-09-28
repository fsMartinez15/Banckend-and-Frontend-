-- RideMove: execute once in a new Supabase project, via migrations or SQL Editor.
begin;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 name text not null check (char_length(name) between 2 and 80),
 phone text not null default '' check (char_length(phone) <= 25),
 role text not null default 'passenger' check (role in ('passenger','driver','admin')),
 active boolean not null default true,
 available boolean not null default false
);
create table public.vehicles (
 driver_id uuid primary key references public.profiles(id),
 plate text not null unique check (char_length(plate) between 3 and 10),
 brand text not null check (char_length(brand) between 1 and 40),
 model text not null check (char_length(model) between 1 and 20),
 color text not null check (char_length(color) between 1 and 30),
 license text not null check (char_length(license) between 1 and 40)
);
create table public.trips (
 id uuid primary key default gen_random_uuid(),
 passenger_id uuid not null references public.profiles(id),
 driver_id uuid references public.profiles(id),
 origin text not null check (char_length(origin) between 3 and 150),
 destination text not null check (char_length(destination) between 3 and 150),
 status text not null default 'pending' check (status in ('pending','accepted','in_progress','completed','cancelled')),
 created_at timestamptz not null default now(),
 completed_at timestamptz,
 rating integer check (rating between 1 and 5),
 comment text check (char_length(comment) <= 255),
 check (lower(origin) <> lower(destination)),
 check (rating is null or status = 'completed')
);
create unique index one_active_passenger_trip on public.trips(passenger_id) where status in ('pending','accepted','in_progress');
create unique index one_active_driver_trip on public.trips(driver_id) where status in ('accepted','in_progress');
create index trips_status_date on public.trips(status, created_at desc);
create table public.rejections (
 trip_id uuid references public.trips(id) on delete cascade,
 driver_id uuid references public.profiles(id),
 primary key (trip_id, driver_id)
);
create table public.locations (
 driver_id uuid primary key references public.profiles(id),
 latitude double precision not null check(latitude between -90 and 90),
 longitude double precision not null check(longitude between -180 and 180),
 updated_at timestamptz not null default now()
);

create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.profiles(id,name,role) values(new.id, left(coalesce(nullif(trim(new.raw_user_meta_data->>'name'),''),'Usuario'),80), case when new.raw_user_meta_data->>'role' = 'driver' then 'driver' else 'passenger' end);
 return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
create function public.my_role() returns text language sql stable security definer set search_path = '' as $$
 select role from public.profiles where id = auth.uid() and active;
$$;
create function public.can_read_profile(p_id uuid) returns boolean language sql stable security definer set search_path = '' as $$
 select p_id = auth.uid() or public.my_role() = 'admin' or exists (
 select 1 from public.trips t where (t.passenger_id = auth.uid() and t.driver_id = p_id) or (t.driver_id = auth.uid() and t.passenger_id = p_id));
$$;
alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.trips enable row level security;
alter table public.rejections enable row level security;
alter table public.locations enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (public.can_read_profile(id));
create policy vehicles_read on public.vehicles for select to authenticated using (public.can_read_profile(driver_id));
create policy rejections_read on public.rejections for select to authenticated using (driver_id = auth.uid());
create policy trips_read on public.trips for select to authenticated using (
 public.my_role() is not null and (public.my_role() = 'admin' or passenger_id = auth.uid() or driver_id = auth.uid() or
 (public.my_role() = 'driver' and status = 'pending' and not exists(select 1 from public.rejections r where r.trip_id = id and r.driver_id = auth.uid())))
);
create policy locations_read on public.locations for select to authenticated using (
 public.my_role() is not null and (driver_id = auth.uid() or public.my_role() = 'admin' or exists(select 1 from public.trips t where t.driver_id = locations.driver_id and t.passenger_id = auth.uid() and t.status in ('accepted','in_progress')))
);
-- All writes go through narrowly scoped RPCs, never unrestricted client updates.
revoke all on public.profiles,public.vehicles,public.trips,public.rejections,public.locations from anon,authenticated;
grant select on public.profiles,public.vehicles,public.trips,public.rejections,public.locations to authenticated;

create function public.save_profile(p_name text, p_phone text) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() is null then raise exception 'Cuenta no disponible'; end if;
 update public.profiles set name=trim(p_name),phone=trim(p_phone) where id=auth.uid();
end; $$;
create function public.set_availability(p_available boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'driver' or public.my_role() is null then raise exception 'Solo conductores'; end if;
 if p_available and not exists(select 1 from public.vehicles where driver_id=auth.uid()) then raise exception 'Registra tu vehículo antes de conectarte'; end if;
 update public.profiles set available=p_available where id=auth.uid();
end; $$;
create function public.create_trip(p_origin text,p_destination text) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'passenger' or public.my_role() is null then raise exception 'Solo pasajeros'; end if;
 insert into public.trips(passenger_id,origin,destination) values(auth.uid(),trim(p_origin),trim(p_destination));
exception when unique_violation then raise exception 'Ya tienes un viaje activo';
end; $$;
create function public.reject_trip(p_id uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'driver' or public.my_role() is null then raise exception 'Solo conductores'; end if;
 if not exists(select 1 from public.trips where id=p_id and status='pending') then raise exception 'Solicitud no disponible'; end if;
 insert into public.rejections values(p_id,auth.uid()) on conflict do nothing;
end; $$;
create function public.transition_trip(p_id uuid,p_status text) returns void language plpgsql security definer set search_path = '' as $$
declare t public.trips; r text;
begin
 r := public.my_role();
 if r is null then raise exception 'Cuenta no disponible'; end if;
 select * into t from public.trips where id=p_id for update;
 if not found then raise exception 'Solicitud no encontrada'; end if;
 if p_status='cancelled' and t.status='pending' and t.passenger_id=auth.uid() and r='passenger' then
  update public.trips set status='cancelled' where id=p_id;
 elsif p_status='accepted' and t.status='pending' and r='driver' then
  perform 1 from public.profiles where id=auth.uid() and available and active for update;
  if not found then raise exception 'Activa tu disponibilidad'; end if;
  if not exists(select 1 from public.vehicles where driver_id=auth.uid()) then raise exception 'Registra tu vehículo'; end if;
  if exists(select 1 from public.rejections where trip_id=p_id and driver_id=auth.uid()) then raise exception 'Ya rechazaste esta solicitud'; end if;
  update public.trips set status='accepted',driver_id=auth.uid() where id=p_id;
 elsif t.driver_id=auth.uid() and r='driver' and ((t.status='accepted' and p_status='in_progress') or (t.status='in_progress' and p_status='completed')) then
  update public.trips set status=p_status,completed_at=case when p_status='completed' then now() else null end where id=p_id;
 else raise exception 'Transición no permitida o solicitud ya atendida'; end if;
exception when unique_violation then raise exception 'Ya tienes un viaje en curso';
end; $$;
create function public.rate_trip(p_id uuid,p_rating integer,p_comment text) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'passenger' or public.my_role() is null then raise exception 'Solo pasajeros'; end if;
 update public.trips set rating=p_rating,comment=p_comment where id=p_id and passenger_id=auth.uid() and status='completed' and rating is null;
 if not found then raise exception 'No puedes calificar este viaje'; end if;
end; $$;
create function public.save_vehicle(p_plate text,p_brand text,p_model text,p_color text,p_license text) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'driver' or public.my_role() is null then raise exception 'Solo conductores'; end if;
 insert into public.vehicles values(auth.uid(),upper(trim(p_plate)),trim(p_brand),trim(p_model),trim(p_color),trim(p_license))
 on conflict(driver_id) do update set plate=excluded.plate,brand=excluded.brand,model=excluded.model,color=excluded.color,license=excluded.license;
end; $$;
create function public.save_location(p_latitude double precision,p_longitude double precision) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'driver' or public.my_role() is null then raise exception 'Solo conductores'; end if;
 insert into public.locations values(auth.uid(),p_latitude,p_longitude,now()) on conflict(driver_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,updated_at=now();
end; $$;
create function public.admin_set_active(p_id uuid,p_active boolean) returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() <> 'admin' or public.my_role() is null then raise exception 'Solo administradores'; end if;
 if exists(select 1 from public.trips where (driver_id=p_id or passenger_id=p_id) and status in ('pending','accepted','in_progress')) then raise exception 'El usuario tiene un viaje activo'; end if;
 update public.profiles set active=p_active,available=false where id=p_id and role <> 'admin';
 if not found then raise exception 'Usuario no modificable'; end if;
end; $$;
revoke execute on function public.handle_new_user() from public,anon,authenticated;
revoke execute on function public.my_role(),public.can_read_profile(uuid),public.save_profile(text,text),public.set_availability(boolean),public.create_trip(text,text),public.reject_trip(uuid),public.transition_trip(uuid,text),public.rate_trip(uuid,integer,text),public.save_vehicle(text,text,text,text,text),public.save_location(double precision,double precision),public.admin_set_active(uuid,boolean) from public,anon;
grant execute on function public.my_role(),public.can_read_profile(uuid),public.save_profile(text,text),public.set_availability(boolean),public.create_trip(text,text),public.reject_trip(uuid),public.transition_trip(uuid,text),public.rate_trip(uuid,integer,text),public.save_vehicle(text,text,text,text,text),public.save_location(double precision,double precision),public.admin_set_active(uuid,boolean) to authenticated;
commit;
