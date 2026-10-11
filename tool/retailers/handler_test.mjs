import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../../supabase/functions/retailers/handler.mjs';
const request=(body,token='good')=>new Request('https://backend.invalid/retailers',{method:'POST',headers:{Authorization:'Bearer '+token},body:JSON.stringify(body)});
function make(overrides={}){
 return createHandler({verify:async()=>({id:'owner',email_confirmed_at:'now'}),consume:async()=>true,cacheRead:async()=>null,cacheWrite:async()=>{},dispatch:async()=>({zip:'40165',city:'Shepherdsville',state:'KY'}),...overrides});
}
test('reject unauthorized and unverified accounts before provider call',async()=>{
 const a=make({verify:async()=>null,dispatch:async()=>{throw Error('must not run');}});
 assert.equal((await a(request({action:'region',zip:'40165'}))).status,401);
 const b=make({verify:async()=>({id:'u',email_confirmed_at:null})});assert.equal((await b(request({}))).status,401);
});
test('rate limit and oversized requests stop provider calls',async()=>{
 assert.equal((await make({consume:async()=>false})(request({}))).status,429);
 assert.equal((await make()(request({query:'a'.repeat(3000)}))).status,413);
});
test('cache failures preserve successful region response',async()=>{
 const h=make({cacheRead:async()=>{throw Error('cache unavailable');},cacheWrite:async()=>{throw Error('cache unavailable');}});
 const r=await h(request({action:'region',zip:'40165'}));assert.equal(r.status,200);assert.equal((await r.json()).data.state,'KY');
});
test('fresh matching cached region bypasses provider, expired entries do not',async()=>{
 const h=make({cacheRead:async()=>({zip:'40165',city:'Shepherdsville',state:'KY',retrieved_at:new Date().toISOString()}),dispatch:async()=>{throw Error('must not call');}});
 assert.equal((await h(request({action:'region',zip:'40165'}))).status,200);
 const expired=make({cacheRead:async()=>({zip:'40165',city:'Old',state:'KY',retrieved_at:'2000-01-01'})});
 assert.equal((await (await expired(request({action:'region',zip:'40165'}))).json()).data.city,'Shepherdsville');
});
test('unexpected infrastructure error is sanitized and preflight is anonymous',async()=>{
 const h=make({verify:async()=>{throw Error('secret token');}});
 const r=await h(request({}));assert.equal(r.status,503);assert.ok(!(await r.text()).includes('secret'));
 assert.equal((await h(new Request('https://backend.invalid',{method:'OPTIONS'}))).status,204);
});
