create table public.recipes (
 household_id uuid not null references public.households(id), id text not null,
 value jsonb not null, revision bigint not null default 0,
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 primary key(household_id,id)
);
create table public.calendar_entries (
 household_id uuid not null references public.households(id), id text not null,
 day date not null, recipe_id text,
 value jsonb not null, revision bigint not null default 0,
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 primary key(household_id,id),unique(household_id,day),
 foreign key(household_id,recipe_id) references public.recipes(household_id,id)
);
create table public.household_preferences (
 household_id uuid not null references public.households(id),id text not null,
 value jsonb not null,revision bigint not null default 0,
 updated_by uuid references auth.users(id) on delete set null,updated_at timestamptz not null default now(),
 primary key(household_id,id),check(id in ('favorites','avoided','pieceWeights'))
);
create table public.shopping_lists (
 household_id uuid primary key references public.households(id),
 start_day date not null,weeks int not null check(weeks between 1 and 4),source_revision bigint not null,
 warnings jsonb not null default '[]',updated_by uuid references auth.users(id) on delete set null,updated_at timestamptz not null default now()
);
create table public.shopping_items (
 household_id uuid not null references public.shopping_lists(household_id),id text not null,
 manual boolean not null,value jsonb not null,checked boolean not null default false,
 updated_by uuid references auth.users(id) on delete set null,updated_at timestamptz not null default now(),
 primary key(household_id,id)
);
create table private.accepted_requests (
 household_id uuid not null references public.households(id),user_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,payload jsonb not null,created_at timestamptz not null default now(),
 primary key(household_id,user_id,request_id)
);
-- All clients read member-scoped records; mutations go through validated RPCs.
do $$declare t text;begin
 foreach t in array array['recipes','calendar_entries','household_preferences','shopping_lists','shopping_items'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 execute format('create policy member_read on public.%I for select to authenticated using(household_id=(select private.current_household()))',t);
 end loop;
end $$;

create function private.assert_keys(v jsonb, keys text[]) returns void language plpgsql set search_path='' as $$
begin
 if v is null or jsonb_typeof(v)<>'object' or exists(select 1 from jsonb_object_keys(v) k where not k=any(keys)) then
 raise exception 'Invalid fields' using errcode='22023';end if;
end $$;
create function private.valid_day(v text) returns date language plpgsql set search_path='' as $$
declare d date;
begin
 if v is null or v !~ '^\d{4}-\d{2}-\d{2}$' then raise exception 'Invalid date' using errcode='22023';end if;
 d:=v::date;
 if d<date '2020-01-01' or d>date '2100-12-31' or to_char(d,'YYYY-MM-DD')<>v then raise exception 'Invalid date' using errcode='22023';end if;
 return d;
end $$;
create function private.validate_value(kind text,v jsonb) returns void language plpgsql set search_path='' as $$
declare i jsonb;n numeric;
begin
 if octet_length(v::text)>262144 then raise exception 'Record too large' using errcode='22023';end if;
 if kind='recipe' then
 perform private.assert_keys(v,array['id','title','baseServings','ingredients','instructions','sourceUrl','category','region','incomplete']);
 if coalesce(length(btrim(v->>'title')),0) not between 1 and 300 or jsonb_typeof(v->'ingredients') is distinct from 'array' then raise exception 'Invalid recipe' using errcode='22023';end if;
 if v->>'baseServings' is not null and (jsonb_typeof(v->'baseServings')<>'number' or (v->>'baseServings')::numeric not between 1 and 100 or (v->>'baseServings')::numeric<>trunc((v->>'baseServings')::numeric)) then raise exception 'Invalid servings' using errcode='22023';end if;
 if jsonb_array_length(v->'ingredients')>200 then raise exception 'Too many ingredients' using errcode='22023';end if;
 for i in select value from jsonb_array_elements(v->'ingredients') loop
 perform private.assert_keys(i,array['name','quantity','unit','preparation','originalText']);
 if coalesce(length(btrim(i->>'name')),0) not between 1 and 300 then raise exception 'Invalid ingredient' using errcode='22023';end if;
 if i->>'quantity' is not null and (jsonb_typeof(i->'quantity')<>'number' or (i->>'quantity')::numeric<=0 or (i->>'quantity')::numeric>1000000) then raise exception 'Invalid quantity' using errcode='22023';end if;
 end loop;
 elsif kind='entry' then
 perform private.assert_keys(v,array['id','date','recipeId','targetServings','kind','cooked','notes']);
 perform private.valid_day(v->>'date');
 n:=(v->>'targetServings')::numeric;
 if n is null or n not between 1 and 100 or n<>trunc(n) or jsonb_typeof(v->'targetServings')<>'number' or coalesce(v->>'kind','') not in ('recipe','takeout','leftovers') or jsonb_typeof(v->'cooked') is distinct from 'boolean' then raise exception 'Invalid meal' using errcode='22023';end if;
 elsif kind='manual' then
 perform private.assert_keys(v,array['id','name','amount']);
 if coalesce(length(btrim(v->>'name')),0) not between 1 and 300 or coalesce(length(v->>'amount'),0)>300 then raise exception 'Invalid manual item' using errcode='22023';end if;
 elsif kind='row' then
 perform private.assert_keys(v,array['key','name','quantity','unit','preparation','sourceText']);
 if coalesce(length(v->>'key'),0) not between 1 and 1000 or coalesce(length(v->>'name'),0) not between 1 and 300 or jsonb_typeof(v->'sourceText') is distinct from 'array' then raise exception 'Invalid grocery row' using errcode='22023';end if;
 if v->>'quantity' is not null and (jsonb_typeof(v->'quantity')<>'number' or (v->>'quantity')::numeric<=0 or (v->>'quantity')::numeric>1000000) then raise exception 'Invalid quantity' using errcode='22023';end if;
 elsif kind='weights' then
 if jsonb_typeof(v)<>'object' then raise exception 'Invalid weights' using errcode='22023';end if;
 for i in select value from jsonb_each(v) loop
 if jsonb_typeof(i)<>'number' or i::text::numeric<=0 or i::text::numeric>48 then raise exception 'Invalid piece weight' using errcode='22023';end if;
 end loop;
 elsif kind in ('favorites','avoided') then
 if jsonb_typeof(v)<>'array' then raise exception 'Invalid preference' using errcode='22023';end if;
 for i in select value from jsonb_array_elements(v) loop
 if jsonb_typeof(i)<>'string' then raise exception 'Invalid recipe preference' using errcode='22023';end if;
 end loop;
 else raise exception 'Unknown record kind' using errcode='22023';end if;
end $$;

create function public.read_shared_plan() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=private.verified_user();h uuid:=private.current_household();s jsonb;l jsonb;rev bigint;
begin
 if h is null then raise exception 'Household membership required' using errcode='42501';end if;
 select calendar_revision into rev from public.households where id=h;
 select jsonb_build_object('start',to_char(start_day,'YYYY-MM-DD'),'weeks',weeks,'sourceRevision',source_revision,'warnings',warnings,
 'rows',coalesce((select jsonb_agg(value order by id) from public.shopping_items where household_id=h and not manual),'[]'),
 'manualItems',coalesce((select jsonb_agg(value order by id) from public.shopping_items where household_id=h and manual),'[]'),
 'checked',coalesce((select jsonb_agg(id order by id) from public.shopping_items where household_id=h and checked),'[]')) into l from public.shopping_lists where household_id=h;
 s:=jsonb_build_object('version',1,'revision',rev,'entries',coalesce((select jsonb_agg(value order by day) from public.calendar_entries where household_id=h),'[]'),
 'recipes',coalesce((select jsonb_agg(value order by id) from public.recipes where household_id=h),'[]'),'list',l,
 'favorites',coalesce((select value from public.household_preferences where household_id=h and id='favorites'),'[]'),
 'avoided',coalesce((select value from public.household_preferences where household_id=h and id='avoided'),'[]'),
 'pieceWeights',coalesce((select value from public.household_preferences where household_id=h and id='pieceWeights'),'{}'));
 return jsonb_build_object('snapshot',s,'recordRevisions',coalesce((select jsonb_object_agg(k,r) from (
 select 'entry:'||id k,revision r from public.calendar_entries where household_id=h union all
 select 'recipe:'||id,revision from public.recipes where household_id=h union all
 select 'preference:'||id,revision from public.household_preferences where household_id=h) x),'{}'));
end $$;

create function private.apply_one(h uuid,u uuid,c jsonb) returns void language plpgsql set search_path='' as $$
declare op text:=c->>'op';ident text:=c->>'id';v jsonb:=c->'value';expected bigint:=(c->>'expectedRevision')::bigint;r bigint;tbl text;kind text;
begin
 perform private.assert_keys(c,array['op','id','value','expectedRevision']);
 if ident is null or length(ident) not between 1 and 1000 then raise exception 'Invalid record ID' using errcode='22023';end if;
 if op in ('entry','recipe','favorites','avoided','weights') then
 kind:=case when op='weights' then 'weights' else op end;
 perform private.validate_value(kind,v);
 if op in ('entry','recipe') and v->>'id' is distinct from ident then raise exception 'Record ID mismatch' using errcode='22023';end if;
 tbl:=case op when 'entry' then 'calendar_entries' when 'recipe' then 'recipes' else 'household_preferences' end;
 if op not in ('entry','recipe') and ident<>(case op when 'weights' then 'pieceWeights' else op end) then raise exception 'Preference ID mismatch' using errcode='22023';end if;
 execute format('select revision from public.%I where household_id=$1 and id=$2',tbl) into r using h,ident;
 if expected is null or (r is null and expected<>-1) or (r is not null and expected<>r) then
 raise exception 'Record changed; reload and review your edit' using errcode='P0002',detail=ident;end if;
 if op='entry' then
 if v->>'recipeId' is not null and not exists(select 1 from public.recipes where household_id=h and id=v->>'recipeId') then raise exception 'Recipe not in household' using errcode='22023';end if;
 insert into public.calendar_entries(household_id,id,day,recipe_id,value,revision,created_by,updated_by)
 values(h,ident,private.valid_day(v->>'date'),v->>'recipeId',v,coalesce(r+1,0),u,u)
 on conflict(household_id,id) do update set day=excluded.day,recipe_id=excluded.recipe_id,value=excluded.value,revision=excluded.revision,updated_by=u,updated_at=now();
 elsif op='recipe' then
 insert into public.recipes(household_id,id,value,revision,created_by,updated_by) values(h,ident,v,coalesce(r+1,0),u,u)
 on conflict(household_id,id) do update set value=excluded.value,revision=excluded.revision,updated_by=u,updated_at=now();
 else
 insert into public.household_preferences(household_id,id,value,revision,updated_by) values(h,ident,v,coalesce(r+1,0),u)
 on conflict(household_id,id) do update set value=excluded.value,revision=excluded.revision,updated_by=u,updated_at=now();
 end if;
 if op in ('entry','recipe') then update public.households set calendar_revision=calendar_revision+1 where id=h;end if;
 elsif op='check' then
 if jsonb_typeof(v)<>'boolean' then raise exception 'Invalid checkoff' using errcode='22023';end if;
 update public.shopping_items set checked=v::text::boolean,updated_by=u,updated_at=now() where household_id=h and id=ident;
 if not found then raise exception 'Shopping item no longer exists' using errcode='P0002';end if;
 elsif op='manual' then
 perform private.validate_value('manual',v);
 if v->>'id' is distinct from ident then raise exception 'Record ID mismatch' using errcode='22023';end if;
 insert into public.shopping_items(household_id,id,manual,value,updated_by) values(h,ident,true,v,u);
 elsif op='removeManual' then
 delete from public.shopping_items where household_id=h and id=ident and manual;
 else raise exception 'Unknown edit' using errcode='22023';end if;
end $$;
create function public.apply_shared_change(p_request_id uuid,p_change jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=private.verified_user();h uuid:=private.current_household();prev jsonb;c jsonb;
begin
 if h is null or p_request_id is null then raise exception 'Household and request ID required' using errcode='42501';end if;
 perform 1 from public.households where id=h for update;
 -- Recheck membership after waiting for the lock.
 if private.current_household() is distinct from h then raise exception 'Membership changed' using errcode='42501';end if;
 select payload into prev from private.accepted_requests where household_id=h and user_id=u and request_id=p_request_id;
 if found then
 if prev<>p_change then raise exception 'Request ID already used' using errcode='22023';end if;
 return public.read_shared_plan();end if;
 if jsonb_typeof(p_change)='array' then
 if jsonb_array_length(p_change)>200 then raise exception 'Too many edits' using errcode='22023';end if;
 for c in select value from jsonb_array_elements(p_change) loop perform private.apply_one(h,u,c);end loop;
 else perform private.apply_one(h,u,p_change);end if;
 insert into private.accepted_requests(household_id,user_id,request_id,payload) values(h,u,p_request_id,p_change);
 return public.read_shared_plan();
end $$;

create function public.regenerate_shared_list(p_request_id uuid,p_calendar_revision bigint,p_start date,p_weeks int,p_rows jsonb,p_warnings jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=private.verified_user();h uuid:=private.current_household();rev bigint;r jsonb;payload jsonb;prev jsonb;
begin
 if h is null or p_request_id is null then raise exception 'Household and request ID required' using errcode='42501';end if;
 select calendar_revision into rev from public.households where id=h for update;
 if private.current_household() is distinct from h then raise exception 'Membership changed' using errcode='42501';end if;
 payload:=jsonb_build_object('regenerate',true,'revision',p_calendar_revision,'start',p_start,'weeks',p_weeks,'rows',p_rows,'warnings',p_warnings);
 select accepted_requests.payload into prev from private.accepted_requests where household_id=h and user_id=u and request_id=p_request_id;
 if found then
 if prev<>payload then raise exception 'Request ID already used' using errcode='22023';end if;
 return public.read_shared_plan();end if;
 if rev<>p_calendar_revision then raise exception 'Calendar changed; regenerate after reload' using errcode='P0002';end if;
 perform private.valid_day(p_start::text);
 if p_weeks is null or p_weeks not between 1 and 4 or jsonb_typeof(p_rows) is distinct from 'array' or jsonb_typeof(p_warnings) is distinct from 'array' or jsonb_array_length(p_rows)>2000 then raise exception 'Invalid list' using errcode='22023';end if;
 for r in select value from jsonb_array_elements(p_rows) loop perform private.validate_value('row',r);end loop;
 if (select count(*) from jsonb_array_elements(p_rows))<>(select count(distinct value->>'key') from jsonb_array_elements(p_rows)) then raise exception 'Duplicate grocery rows' using errcode='22023';end if;
 insert into public.shopping_lists(household_id,start_day,weeks,source_revision,warnings,updated_by) values(h,p_start,p_weeks,rev,p_warnings,u)
 on conflict(household_id) do update set start_day=p_start,weeks=p_weeks,source_revision=rev,warnings=p_warnings,updated_by=u,updated_at=now();
 delete from public.shopping_items where household_id=h and not manual and id not in(select value->>'key' from jsonb_array_elements(p_rows));
 for r in select value from jsonb_array_elements(p_rows) loop
 if exists(select 1 from public.shopping_items where household_id=h and id=r->>'key' and manual) then raise exception 'Grocery key conflicts with manual item' using errcode='22023';end if;
 insert into public.shopping_items(household_id,id,manual,value,updated_by) values(h,r->>'key',false,r,u)
 on conflict(household_id,id) do update set value=excluded.value,updated_by=u,updated_at=now();
 end loop;
 insert into private.accepted_requests(household_id,user_id,request_id,payload) values(h,u,p_request_id,payload);
 return public.read_shared_plan();
end $$;

create function public.import_local_plan(p_snapshot jsonb) returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=private.verified_user();h uuid:=private.current_household();v jsonb;k text;list jsonb;
begin
 if h is null then raise exception 'Household membership required' using errcode='42501';end if;
 perform 1 from public.households where id=h for update;
 if private.current_household() is distinct from h then raise exception 'Membership changed' using errcode='42501';end if;
 if exists(select 1 from public.recipes where household_id=h) or exists(select 1 from public.calendar_entries where household_id=h) or exists(select 1 from public.shopping_lists where household_id=h) then raise exception 'Only an empty household can import local data' using errcode='22023';end if;
 perform private.assert_keys(p_snapshot,array['version','revision','entries','recipes','list','favorites','avoided','pieceWeights']);
 if p_snapshot->>'version'<>'1' or jsonb_typeof(p_snapshot->'recipes') is distinct from 'array' or jsonb_typeof(p_snapshot->'entries') is distinct from 'array' or octet_length(p_snapshot::text)>5000000 then raise exception 'Invalid backup' using errcode='22023';end if;
 for v in select value from jsonb_array_elements(p_snapshot->'recipes') loop perform private.apply_one(h,u,jsonb_build_object('op','recipe','id',v->>'id','value',v,'expectedRevision',-1));end loop;
 for v in select value from jsonb_array_elements(p_snapshot->'entries') loop perform private.apply_one(h,u,jsonb_build_object('op','entry','id',v->>'id','value',v,'expectedRevision',-1));end loop;
 for k in select unnest(array['favorites','avoided','pieceWeights']) loop
 perform private.apply_one(h,u,jsonb_build_object('op',case k when 'pieceWeights' then 'weights' else k end,'id',k,'value',coalesce(p_snapshot->k,case k when 'pieceWeights' then '{}'::jsonb else '[]'::jsonb end),'expectedRevision',-1));end loop;
 -- Imported lists remain stale: their source revision is not the new server calendar revision.
 list:=p_snapshot->'list';
 if list is not null and list<>'null'::jsonb then
 perform public.regenerate_shared_list(gen_random_uuid(),(select calendar_revision from public.households where id=h),private.valid_day(list->>'start'),(list->>'weeks')::int,list->'rows',coalesce(list->'warnings','[]'));
 for v in select value from jsonb_array_elements(list->'manualItems') loop perform private.apply_one(h,u,jsonb_build_object('op','manual','id',v->>'id','value',v));end loop;
 for k in select jsonb_array_elements_text(list->'checked') loop
 if exists(select 1 from public.shopping_items where household_id=h and id=k) then perform private.apply_one(h,u,jsonb_build_object('op','check','id',k,'value',true));end if;
 end loop;
 update public.shopping_lists set source_revision=-1 where household_id=h;
 end if;
 -- Import represents a new server baseline; individual record revisions start at zero.
 update public.households set calendar_revision=0 where id=h;
end $$;
revoke all on function private.assert_keys(jsonb,text[]),private.valid_day(text),private.validate_value(text,jsonb),private.apply_one(uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.read_shared_plan(),public.apply_shared_change(uuid,jsonb),public.regenerate_shared_list(uuid,bigint,date,int,jsonb,jsonb),public.import_local_plan(jsonb) from public,anon,authenticated;
grant execute on function public.read_shared_plan(),public.apply_shared_change(uuid,jsonb),public.regenerate_shared_list(uuid,bigint,date,int,jsonb,jsonb),public.import_local_plan(jsonb) to authenticated;
