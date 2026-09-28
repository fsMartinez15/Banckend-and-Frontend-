begin;
-- Allow administrative correction without allowing public role escalation.
create or replace function public.admin_save_vehicle(p_driver_id uuid,p_plate text,p_brand text,p_model text,p_color text,p_license text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() is distinct from 'admin' then raise exception 'Solo administradores'; end if;
 if not exists(select 1 from public.profiles where id=p_driver_id and role='driver') then raise exception 'Conductor no encontrado'; end if;
 insert into public.vehicles values(p_driver_id,upper(trim(p_plate)),trim(p_brand),trim(p_model),trim(p_color),trim(p_license))
 on conflict(driver_id) do update set plate=excluded.plate,brand=excluded.brand,model=excluded.model,color=excluded.color,license=excluded.license;
end; $$;
revoke execute on function public.admin_save_vehicle(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.admin_save_vehicle(uuid,text,text,text,text,text) to authenticated;

-- Ratings and completed trips must remain coherent even outside the mobile client.
alter table public.trips add constraint completed_timestamp_matches_state
 check ((status='completed' and completed_at is not null) or (status<>'completed' and completed_at is null));
create or replace function public.rate_trip(p_id uuid,p_rating integer,p_comment text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() is distinct from 'passenger' then raise exception 'Solo pasajeros'; end if;
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Calificación fuera de rango'; end if;
 update public.trips set rating=p_rating,comment=coalesce(p_comment,'') where id=p_id and passenger_id=auth.uid() and status='completed' and rating is null;
 if not found then raise exception 'No puedes calificar este viaje'; end if;
end; $$;
create or replace function public.save_location(p_latitude double precision,p_longitude double precision)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if public.my_role() is distinct from 'driver' then raise exception 'Solo conductores'; end if;
 if not exists(select 1 from public.trips where driver_id=auth.uid() and status in ('accepted','in_progress')) then raise exception 'No tienes un viaje activo'; end if;
 insert into public.locations values(auth.uid(),p_latitude,p_longitude,now()) on conflict(driver_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,updated_at=now();
end; $$;
commit;
