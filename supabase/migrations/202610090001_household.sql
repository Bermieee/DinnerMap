create schema if not exists private;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
revoke all on schema private from public, anon, authenticated;

create table public.households (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(btrim(name)) between 1 and 100),
 created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(),
 calendar_revision bigint not null default 0
);
create table public.memberships (
 user_id uuid primary key references auth.users(id) on delete cascade,
 household_id uuid not null references public.households(id),
 joined_at timestamptz not null default now()
);
create index memberships_household on public.memberships(household_id);
create table private.invitations (
 token_hash bytea primary key,
 household_id uuid not null references public.households(id),
 created_by uuid references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now() + interval '24 hours',
 redeemed_at timestamptz,
 redeemed_by uuid references auth.users(id) on delete set null
);

create function private.verified_user() returns uuid
language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid();
begin
 if u is null or not exists(select 1 from auth.users where id=u and email_confirmed_at is not null) then
  raise exception 'Verified account required' using errcode='42501';
 end if;
 return u;
end $$;
create function private.current_household() returns uuid
language sql stable security definer set search_path = '' as $$
 select m.household_id from public.memberships m join auth.users u on u.id=m.user_id
 where m.user_id=auth.uid() and u.email_confirmed_at is not null
$$;
revoke all on function private.verified_user(), private.current_household() from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.current_household() to authenticated;

alter table public.households enable row level security;
alter table public.memberships enable row level security;
alter table private.invitations enable row level security;
revoke all on public.households, public.memberships from public, anon, authenticated;
grant select on public.households, public.memberships to authenticated;
create policy household_read on public.households for select to authenticated using(id=(select private.current_household()));
create policy membership_read on public.memberships for select to authenticated using(household_id=(select private.current_household()));

create function public.create_household(p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare u uuid := private.verified_user(); h uuid;
begin
 perform 1 from auth.users where id=u for update;
 if exists(select 1 from public.memberships where user_id=u) then raise exception 'Already in a household' using errcode='22023'; end if;
 if p_name is null or length(btrim(p_name)) not between 1 and 100 then raise exception 'Household name must have 1–100 characters' using errcode='22023'; end if;
 insert into public.households(name,created_by) values(btrim(p_name),u) returning id into h;
 insert into public.memberships(user_id,household_id) values(u,h);
 return h;
end $$;
create function public.create_invitation() returns text
language plpgsql security definer set search_path = '' as $$
declare u uuid := private.verified_user(); h uuid; token text;
begin
 select household_id into h from public.memberships where user_id=u for update;
 if h is null then raise exception 'Household membership required' using errcode='42501'; end if;
 if (select count(*) from private.invitations where created_by=u and created_at>now()-interval '1 hour')>=20 then raise exception 'Invitation limit reached; try later' using errcode='22023'; end if;
 token:=encode(extensions.gen_random_bytes(32),'hex');
 insert into private.invitations(token_hash,household_id,created_by) values(extensions.digest(token,'sha256'),h,u);
 return token;
end $$;
create function public.redeem_invitation(p_token text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare u uuid := private.verified_user(); invitation private.invitations%rowtype;
begin
 perform 1 from auth.users where id=u for update;
 if exists(select 1 from public.memberships where user_id=u) then raise exception 'Leave your current household before joining another' using errcode='22023'; end if;
 if p_token is null or p_token !~ '^[a-f0-9]{64}$' then raise exception 'Invalid invitation' using errcode='22023'; end if;
 select * into invitation from private.invitations where token_hash=extensions.digest(p_token,'sha256') for update;
 if not found or invitation.redeemed_at is not null or invitation.expires_at<=now()
  or not exists(select 1 from public.memberships where user_id=invitation.created_by and household_id=invitation.household_id) then
  raise exception 'Invitation is expired or unavailable' using errcode='22023';
 end if;
 insert into public.memberships(user_id,household_id) values(u,invitation.household_id);
 update private.invitations set redeemed_at=now(),redeemed_by=u where token_hash=invitation.token_hash;
 return invitation.household_id;
end $$;
create function public.leave_household() returns void
language plpgsql security definer set search_path = '' as $$
declare u uuid := private.verified_user();
begin
 perform 1 from auth.users where id=u for update;
 delete from private.invitations where created_by=u and redeemed_at is null;
 delete from public.memberships where user_id=u;
end $$;
create function public.household_members() returns table(user_id uuid,email text)
language sql stable security definer set search_path = '' as $$
 select m.user_id,u.email from public.memberships m join auth.users u on m.user_id=u.id
 where m.household_id=private.current_household() order by m.joined_at
$$;
revoke all on function public.create_household(text), public.create_invitation(), public.redeem_invitation(text), public.leave_household(), public.household_members() from public,anon,authenticated;
grant execute on function public.create_household(text), public.create_invitation(), public.redeem_invitation(text), public.leave_household(), public.household_members() to authenticated;
