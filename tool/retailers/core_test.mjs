import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createRetailerService, normalizeProducts} from '../../supabase/functions/retailers/core.mjs';
const json=(body,status=200)=>new Response(JSON.stringify(body),{status});
test('ZIP query preserves leading zeroes and validates before network',async()=>{
 let calls=0;
 const service=createRetailerService({fetch:async(url)=>{calls++;assert.equal(url,'https://api.zippopotam.us/us/00501');return json({'post code':'00501',places:[{'place name':'Holtsville','state abbreviation':'NY'}]});}});
 assert.deepEqual(await service.dispatch('region',{zip:'00501'}),{zip:'00501',city:'Holtsville',state:'NY'});
 await assert.rejects(service.dispatch('region',{zip:'1234'}),/five-digit/);assert.equal(calls,1);
});
test('unresolved ZIP and provider failures have safe errors',async()=>{
 const a=createRetailerService({fetch:async()=>json({},404)});await assert.rejects(a.dispatch('region',{zip:'00000'}),/not found/);
 const b=createRetailerService({fetch:async()=>json({secret:'private'},500)});await assert.rejects(b.dispatch('region',{zip:'40165'}),e=>!e.message.includes('private') && /unavailable/.test(e.message));
});
test('missing Kroger credentials does not fabricate stores',async()=>{
 const s=createRetailerService({fetch:async()=>{throw Error('should not request');}});
 await assert.rejects(s.dispatch('stores',{zip:'40165',radius:25}),/not configured/);
});
test('Kroger token cached, stores use ZIP radius and products use selected location',async()=>{
 let tokenRequests=0,productRequests=0;
 const s=createRetailerService({clientId:'client',clientSecret:'secret',fetch:async(url,options)=>{
  if(url.includes('/oauth2/token')){tokenRequests++;assert.match(options.body,/client_credentials/);return json({access_token:'token',expires_in:1800});}
  assert.equal(options.headers.Authorization,'Bearer token');
  const u=new URL(url);
  if(u.pathname.endsWith('/locations')) {assert.equal(u.searchParams.get('filter.zipCode.near'),'40165');assert.equal(u.searchParams.get('filter.radiusInMiles'),'25');return json({data:[{locationId:'123',name:'Local Kroger',address:{addressLine1:'1 Main',city:'Shepherdsville',state:'KY',zipCode:'40165'}}]});}
  productRequests++;assert.equal(u.searchParams.get('filter.locationId'),'123');assert.equal(u.searchParams.get('filter.term'),'milk');return json({data:[{productId:'p',description:'Milk',items:[{itemId:'i',size:'1 gal',price:{regular:4,promo:3},inventory:{stockLevel:'HIGH'}}]}]});
 }});
 const stores=await s.dispatch('stores',{zip:'40165',radius:25});assert.equal(stores[0].state,'KY');
 const offers=await s.dispatch('products',{storeId:'123',query:'milk'});assert.equal(offers[0].price,3);assert.equal(offers[0].unit,'gal');assert.equal(offers[0].store_id,'123');assert.ok(offers[0].retrieved_at);assert.equal(tokenRequests,1);assert.equal(productRequests,1);
});
test('normalization keeps item variants, unknown price, zero and ambiguous sizes',()=>{
 const a=normalizeProducts([{productId:'p',description:'Rice',items:[{itemId:'a',size:'16 oz',price:{regular:4}},{itemId:'b',size:'2 x 16 oz',price:{regular:7}},{itemId:'c',size:'1 lb',price:{regular:0}},{itemId:'d',size:'1 lb'}]}],'123');
 assert.equal(a.length,4);assert.equal(a[0].amount,16);assert.equal(a[1].amount,null);assert.equal(a[2].price,0);assert.equal(a[3].price,null);assert.equal(new Set(a.map(o=>o.id)).size,4);
});
test('bounds reject malformed input and unavailable providers',async()=>{
 const s=createRetailerService({});
 for(const args of [{zip:'40165',radius:101},{zip:'40165',radius:0},{zip:'40165',radius:25.5}])await assert.rejects(s.dispatch('stores',args));
 await assert.rejects(s.dispatch('products',{storeId:'https://attacker.invalid',query:'milk'}));
 await assert.rejects(s.dispatch('products',{storeId:'123',query:'a'}));
 await assert.rejects(s.dispatch('walmart',{}),/not available/);
});
test('401 token is renewed once; secret upstream errors never reach clients',async()=>{
 let tokens=0,products=0;
 const s=createRetailerService({clientId:'id',clientSecret:'secret',fetch:async(url)=>{
  if(url.includes('/token'))return json({access_token:'t'+(++tokens),expires_in:1800});
  products++;return products===1?json({secret:'secret'},401):json({data:[]});
 }});
 assert.deepEqual(await s.dispatch('products',{storeId:'123',query:'milk'}),[]);assert.equal(tokens,2);
});
test('malformed product items do not hide valid package variants',()=>{
 const offers=normalizeProducts([{productId:'p',description:'Rice',items:[null,'bad',{itemId:'good',size:'1 lb',price:{regular:4}}]}],'123');
 assert.equal(offers.length,1);assert.equal(offers[0].price,4);
});
test('malformed optional location strings retain a usable typed store',async()=>{
 const s=createRetailerService({clientId:'id',clientSecret:'secret',fetch:async(url)=>url.includes('/token')?json({access_token:'t',expires_in:1000}):json({data:[{locationId:'123',name:{bad:1},address:{state:55,addressLine1:{bad:2},city:'Town'}}]})});
 const stores=await s.dispatch('stores',{zip:'40165',radius:25});
 assert.equal(stores[0].name,'Kroger');assert.equal(stores[0].state,'');assert.equal(stores[0].address,'Town');
});
