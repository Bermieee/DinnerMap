import {database} from './database_fixture.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db = await database();
await db.exec(`do $$begin create role anon;exception when duplicate_object then null;end$$; do $$begin create role authenticated;exception when duplicate_object then null;end$$;
create schema auth; create schema extensions;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
insert into auth.users values
('00000000-0000-0000-0000-000000000001','owner@test.invalid',now()),
('00000000-0000-0000-0000-000000000002','member@test.invalid',now()),
('00000000-0000-0000-0000-000000000003','outsider@test.invalid',now()),
('00000000-0000-0000-0000-000000000004','unverified@test.invalid',null);`);
let migration='';
try { migration=await readFile(new URL('../../supabase/migrations/202610090001_household.sql',import.meta.url),'utf8'); } catch {}
if(migration) await db.exec(migration);
const uid=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
async function as(n,role='authenticated') {await db.exec(`reset role; set role ${role}; select set_config('request.jwt.claim.sub','${n?uid(n):''}',false)`);}
let checks=0;
async function denied(sql,params=[]) {await assert.rejects(db.query(sql,params));checks++;}
async function value(sql,params=[]) {return (await db.query(sql,params)).rows[0];}
await as(1);
const h=(await value('select public.create_household($1) as id',['Family'])).id;
assert.ok(h);checks++;
assert.equal((await value('select count(*)::int as n from public.memberships')).n,1);checks++;
await denied("insert into public.memberships(household_id,user_id) values ($1,$2)",[h,uid(3)]);
await denied('select * from private.invitations');
await denied('select public.create_household($1)',['Second']);
const token=(await value('select public.create_invitation() as token')).token;
assert.match(token,/^[a-f0-9]{64}$/);checks++;
await as(3);
assert.equal((await value('select count(*)::int as n from public.households')).n,0);checks++;
assert.equal((await value('select count(*)::int as n from public.memberships')).n,0);checks++;
await denied('select public.create_invitation()');
await as(4);
await denied('select public.create_household($1)',['Bad']);
await denied('select public.redeem_invitation($1)',[token]);
await as(0,'anon');
await denied('select public.create_household($1)',['Anonymous']);
await as(2);
assert.equal((await value('select public.redeem_invitation($1) as id',[token])).id,h);checks++;
assert.equal((await value('select count(*)::int as n from public.household_members()')).n,2);checks++;
const memberToken=(await value('select public.create_invitation() as token')).token;
await as(3);
await denied('select public.redeem_invitation($1)',[token]);
await db.exec('reset role');
assert.equal((await value("select (expires_at-created_at = interval '24 hours') as correct from private.invitations limit 1")).correct,true);checks++;
await db.exec("update private.invitations set expires_at=now()-interval '1 second'");
await as(3);
await denied('select public.redeem_invitation($1)',[memberToken]);
await as(2);
await db.query('select public.leave_household()');
assert.equal((await value('select count(*)::int as n from public.households')).n,0);checks++;
await as(1);
assert.equal((await value('select count(*)::int as n from public.households')).n,1);checks++;
await denied('update public.households set name=$1 where id=$2',['Forged',h]);
await denied('delete from public.memberships');
const invite=(await value('select public.create_invitation() as token')).token;
await db.query('select public.leave_household()');
await as(3);
await denied('select public.redeem_invitation($1)',[invite]);
if(db.connect){
 // Separate PostgreSQL sessions race the same token; row locking permits one redemption.
 await as(1);await qCreate();
 const t=(await value('select public.create_invitation() as token')).token;
 const clients=await Promise.all([db.connect(),db.connect()]);
 await Promise.all(clients.map((c,i)=>c.query(`set role authenticated;select set_config('request.jwt.claim.sub','${uid(i+2)}',false)`)));
 const results=await Promise.allSettled(clients.map(c=>c.query('select public.redeem_invitation($1)',[t])));
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);checks++;
 await Promise.all(clients.map(c=>c.end()));
}
async function qCreate(){await db.query('select public.create_household($1)',['Concurrent']);}
console.log(`${checks} household security checks passed`);
await db.close();
