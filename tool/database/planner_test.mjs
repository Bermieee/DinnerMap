import {database} from './database_fixture.mjs';
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=await database();
await db.exec(`do $$begin create role anon;exception when duplicate_object then null;end$$;do $$begin create role authenticated;exception when duplicate_object then null;end$$;create schema auth;create schema extensions;
create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema public,auth to authenticated,anon;
insert into auth.users values ('00000000-0000-0000-0000-000000000001','a@test.invalid',now()),('00000000-0000-0000-0000-000000000002','b@test.invalid',now());`);
await db.exec(await readFile(new URL('../../supabase/migrations/202610090001_household.sql',import.meta.url),'utf8'));
try{await db.exec(await readFile(new URL('../../supabase/migrations/202610090002_planner.sql',import.meta.url),'utf8'));}catch(e){if(e.code!=='ENOENT')throw e;}
let checks=0;
async function q(sql,p=[]){return(await db.query(sql,p)).rows[0];}
async function denied(sql,p=[]){await assert.rejects(db.query(sql,p));checks++;}
async function as(n){await db.exec(`reset role;set role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-${String(n).padStart(12,'0')}',false)`);}
await as(1);await q('select public.create_household($1)',['Family']);
const snapshot={version:1,entries:[{id:'day-1',date:'2026-10-09',recipeId:'r1',targetServings:4,kind:'recipe',cooked:false,notes:''}],recipes:[{id:'r1',title:'Soup',ingredients:[{name:'carrot',quantity:2,unit:'count',preparation:'',originalText:'2'}],baseServings:4}],revision:0,list:null,favorites:[],avoided:[],pieceWeights:{}};
await q('select public.import_local_plan($1)',[snapshot]);checks++;
let view=(await q('select public.read_shared_plan() as v')).v;
assert.equal(view.snapshot.entries[0].id,'day-1');checks++;
await denied('select public.import_local_plan($1)',[snapshot]);
const change=async(c,id=crypto.randomUUID())=>q('select public.apply_shared_change($1,$2) as v',[id,c]);
const entry={...snapshot.entries[0],cooked:true};
const id=crypto.randomUUID();
await change({op:'entry',id:'day-1',expectedRevision:0,value:entry},id);
await change({op:'entry',id:'day-1',expectedRevision:0,value:entry},id);checks++;
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:0,value:entry}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:{...entry,targetServings:0}}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:{...entry,date:'2026-02-30'}}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:{...entry,recipeId:'other'}}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:{...entry,household_id:'forged'}}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'recipe',id:'r1',expectedRevision:0,value:{...snapshot.recipes[0],instructions:42}}]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:{...entry,notes:42}}]);
const row={key:'carrot|count|',name:'carrot',quantity:2,unit:'count',preparation:'',sourceText:[]};
await q('select public.regenerate_shared_list($1,$2,$3,$4,$5,$6)',[crypto.randomUUID(),1,'2026-10-09',2,[row],[]]);
await change({op:'check',id:row.key,value:true});
await change({op:'manual',id:'m1',value:{id:'m1',name:'Milk',amount:'1 gallon'}});
await q('select public.regenerate_shared_list($1,$2,$3,$4,$5,$6)',[crypto.randomUUID(),1,'2026-10-09',2,[{...row,quantity:4}],[]]);
view=(await q('select public.read_shared_plan() as v')).v;
assert.equal(view.snapshot.list.manualItems[0].name,'Milk');checks++;
assert.ok(view.snapshot.list.checked.includes(row.key));checks++;
assert.equal(view.snapshot.list.rows[0].quantity,4);checks++;
await denied('select public.regenerate_shared_list($1,$2,$3,$4,$5,$6)',[crypto.randomUUID(),0,'2026-10-09',2,[row],[]]);
await denied('select public.regenerate_shared_list($1,$2,$3,$4,$5,$6)',[crypto.randomUUID(),1,'2026-10-09',5,[row],[]]);
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'weights',id:'pieceWeights',expectedRevision:0,value:{chicken:49}}]);
await as(2);await q('select public.create_household($1)',['Other']);
view=(await q('select public.read_shared_plan() as v')).v;
assert.equal(view.snapshot.entries.length,0);checks++;
await denied('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),{op:'entry',id:'day-1',expectedRevision:1,value:entry}]);
if(db.connect){
 await as(1);const writer=await db.connect();const reader=await db.connect();
 const login=`set role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false)`;
 await writer.query(login);await reader.query(login);await writer.query('begin');
 await writer.query('select public.apply_shared_change($1,$2)',[crypto.randomUUID(),JSON.stringify({op:'entry',id:'day-1',expectedRevision:1,value:{...entry,cooked:false}})]);
 let done=false;const read=reader.query('select public.read_shared_plan() as v').then(r=>{done=true;return r;});
 await new Promise(r=>setTimeout(r,100));const blocked=!done;
 await writer.query('commit');const result=(await read).rows[0].v;
 await writer.end();await reader.end();
 assert.ok(blocked,'shared read waits for in-flight mutation lock');checks++;
 assert.equal(result.snapshot.entries[0].cooked,false);assert.equal(result.recordRevisions['entry:day-1'],2);assert.equal(result.snapshot.revision,2);checks++;
}
console.log(`${checks} shared storage checks passed`);await db.close();
