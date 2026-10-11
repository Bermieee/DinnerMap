-- Clear only the current verified household list through the existing locked/idempotent edit path.
create or replace function private.apply_one(h uuid,u uuid,c jsonb) returns void language plpgsql set search_path='' as $$
declare op text:=c->>'op';ident text:=c->>'id';v jsonb:=c->'value';expected bigint:=(c->>'expectedRevision')::bigint;r bigint;tbl text;kind text;
begin
 perform private.assert_keys(c,array['op','id','value','expectedRevision']);
 perform private.string_fields(c,array['op','id']);
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
 elsif op='clearList' then
 if ident <> 'list' or v is null or jsonb_typeof(v) <> 'object' then
   raise exception 'Invalid clear-list request' using errcode='22023';
 end if;
 -- The caller holds the household mutation lock. Reject a changed list,
 -- including a new generation, manual item or checkoff from another device.
 if v is distinct from (public.read_shared_plan()->'snapshot'->'list') then
   raise exception 'Grocery list changed. Reload and review before clearing.' using errcode='P0002';
 end if;
 delete from public.shopping_items where household_id=h;
 delete from public.shopping_lists where household_id=h;
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
