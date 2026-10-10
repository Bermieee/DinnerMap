create table public.zip_regions (
 zip text primary key check (zip ~ '^[0-9]{5}$'),
 city text not null check (length(city) between 1 and 150),
 state text not null check (state ~ '^[A-Z]{2}$'),
 retrieved_at timestamptz not null default now()
);
alter table public.zip_regions enable row level security;
create policy zip_read on public.zip_regions for select to authenticated using (true);
grant select on public.zip_regions to authenticated;
create table public.region_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 zip text not null check (zip ~ '^[0-9]{5}$'),
 radius_miles integer not null default 25 check(radius_miles between 5 and 100),
 selected_store_id text check(selected_store_id ~ '^[0-9]{1,30}$'),
 updated_at timestamptz not null default now()
);
alter table public.region_profiles enable row level security;
create policy profile_own on public.region_profiles for all to authenticated
 using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.region_profiles to authenticated;
create function public.region_profile_changed() returns trigger language plpgsql set search_path='' as $$
begin
 if new.zip is distinct from old.zip or new.radius_miles is distinct from old.radius_miles then new.selected_store_id=null;end if;
 new.updated_at=now(); return new;
end$$;
create trigger region_profile_changed before update on public.region_profiles for each row execute function public.region_profile_changed();
create schema if not exists private;
create table private.retailer_limits(user_id uuid primary key references auth.users(id) on delete cascade, window_started timestamptz not null, requests int not null);
create function public.consume_retailer_request() returns boolean language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 insert into private.retailer_limits values(auth.uid(),now(),1)
 on conflict(user_id) do update set
 requests=case when private.retailer_limits.window_started < now()-interval '1 minute' then 1 else private.retailer_limits.requests+1 end,
 window_started=case when private.retailer_limits.window_started < now()-interval '1 minute' then now() else private.retailer_limits.window_started end
 returning requests into n;
 return n<=30;
end$$;
revoke all on function public.consume_retailer_request() from public,anon;
grant execute on function public.consume_retailer_request() to authenticated;
