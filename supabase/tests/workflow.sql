-- Non-destructive integration checks. Every fixture is rolled back.
\set ON_ERROR_STOP on
begin;
select gen_random_uuid() as passenger,gen_random_uuid() as driver,gen_random_uuid() as outsider \gset
insert into auth.users(id,raw_user_meta_data) values
 (:'passenger','{"name":"Test Pasajero","role":"passenger"}'),
 (:'driver','{"name":"Test Conductor","role":"driver"}'),
 (:'outsider','{"name":"Test Ajeno","role":"passenger"}');
set local role authenticated;
select set_config('request.jwt.claim.sub',:'passenger',true);
select public.create_trip('Centro de prueba','Terminal de prueba');
select id as trip from public.trips where passenger_id=:'passenger' \gset
do $$ begin
 begin
  perform public.create_trip('Otro origen','Otro destino');
  raise exception 'ASSERT duplicate request was allowed';
 exception when raise_exception then
  if SQLERRM like 'ASSERT%' then raise; end if;
 end;
end $$;
select set_config('request.jwt.claim.sub',:'driver',true);
select public.save_vehicle('TST999','Prueba','2026','Gris','TEST-LICENSE');
select public.set_availability(true);
select public.transition_trip(:'trip','accepted');
select public.save_location(4.343,-74.363);
select public.transition_trip(:'trip','in_progress');
select set_config('request.jwt.claim.sub',:'outsider',true);
do $$ begin
 if exists(select 1 from public.trips where origin='Centro de prueba') then raise exception 'ASSERT unrelated passenger sees ride'; end if;
 if exists(select 1 from public.locations where latitude=4.343 and longitude=-74.363) then raise exception 'ASSERT unrelated passenger sees location'; end if;
end $$;
select set_config('request.jwt.claim.sub',:'driver',true);
select public.transition_trip(:'trip','completed');
select set_config('request.jwt.claim.sub',:'passenger',true);
select public.rate_trip(:'trip',5,'Prueba transaccional');
do $$ begin
 if not exists(select 1 from public.trips where origin='Centro de prueba' and rating=5 and completed_at is not null) then raise exception 'ASSERT completion not saved'; end if;
 if exists(select 1 from public.locations where latitude=4.343 and longitude=-74.363) then raise exception 'ASSERT completed ride still shares location'; end if;
end $$;
rollback;
\echo Integration checks passed; fixtures rolled back.
