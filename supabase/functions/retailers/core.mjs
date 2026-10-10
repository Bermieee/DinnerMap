export class RetailerError extends Error {
  constructor(message,status=503){super(message);this.status=status;}
}
const zipPattern=/^[0-9]{5}$/;
const validNumber=n=>typeof n==='number' && Number.isFinite(n) && n>=0;
const sizePattern=/^([0-9]+(?:\.[0-9]+)?)\s*(fl\.?\s*oz\.?|lbs?\.?|oz\.?|kg|g|gal|qt|pt|ml|l|ct|count)$/i;
function parseSize(size){
 const match=sizePattern.exec(size.trim());
 if(!match || Number(match[1])<=0)return {amount:null,unit:null};
 const raw=match[2].toLowerCase().replaceAll('.','').replace(/\s+/g,' ');
 return {amount:Number(match[1]),unit:raw==='lbs'?'lb':raw==='ct'?'count':raw};
}
export function normalizeProducts(products,storeId,now=new Date()) {
 return products.flatMap(p=>{
  if(!p || typeof p.productId!=='string')return [];
  const items=Array.isArray(p.items) && p.items.length?p.items.filter(i=>i && typeof i==='object' && !Array.isArray(i)):[{}];
  return items.map((item,index)=>{
   const promo=item.price?.promo,regular=item.price?.regular;
   // Kroger commonly uses promo=0 to mean no promotion; regular=0 remains a known price.
   const price=validNumber(promo)&&promo>0?promo:validNumber(regular)?regular:null;
   const size=typeof item.size==='string'?item.size:'';
   const stock=item.inventory?.stockLevel;
   return {id:`${p.productId}:${typeof item.itemId==='string'?item.itemId:index}`,name:typeof p.description==='string'?p.description:p.productId,
    price,size,...parseSize(size),store_id:storeId,retailer:'kroger',
    availability:typeof stock==='string'?stock:'Unknown',retrieved_at:now.toISOString()};
  });
 });
}
export function createRetailerService({fetch:request=globalThis.fetch,clientId='',clientSecret='',clock=()=>Date.now()}={}) {
 let token=null,expires=0,tokenPending=null;
 async function timed(url,options={}) {
  try{return await request(url,{...options,signal:AbortSignal.timeout(12000),redirect:'error'});}
  catch{throw new RetailerError('Retailer service is unavailable. Try again.');}
 }
 async function body(response) {
  try{return await response.json();}catch{throw new RetailerError('Retailer returned an unreadable response.');}
 }
 async function accessToken(){
  if(!clientId || !clientSecret)throw new RetailerError('Kroger is not configured yet.');
  if(token && expires>clock())return token;
  if(tokenPending)return tokenPending;
  tokenPending=(async()=>{
   const response=await timed('https://api.kroger.com/v1/connect/oauth2/token',{method:'POST',headers:{Authorization:'Basic '+btoa(clientId+':'+clientSecret),'Content-Type':'application/x-www-form-urlencoded'},body:'grant_type=client_credentials&scope=product.compact'});
   if(!response.ok)throw new RetailerError('Kroger authorization is unavailable.');
   const payload=await body(response);
   if(typeof payload.access_token!=='string' || !payload.access_token)throw new RetailerError('Kroger authorization is unavailable.');
   token=payload.access_token;
   expires=clock()+Math.max(0,Math.min(Number(payload.expires_in)||0,86400)-60)*1000;
   return token;
  })();
  try{return await tokenPending;}finally{tokenPending=null;}
 }
 async function kroger(url){
  let response=await timed(url,{headers:{Authorization:'Bearer '+await accessToken(),Accept:'application/json'}});
  if(response.status===401){token=null;expires=0;response=await timed(url,{headers:{Authorization:'Bearer '+await accessToken(),Accept:'application/json'}});}
  if(!response.ok)throw new RetailerError(response.status===429?'Kroger request limit reached. Try again shortly.':'Kroger is temporarily unavailable.',response.status===429?429:503);
  const payload=await body(response);
  if(!Array.isArray(payload.data))throw new RetailerError('Kroger returned an unreadable response.');
  return payload.data;
 }
 return {async dispatch(action,args={}) {
  if(action==='region' || action==='stores'){
   if(typeof args.zip!=='string' || !zipPattern.test(args.zip))throw new RetailerError('Enter a five-digit US ZIP code.',400);
  }
  if(action==='region'){
   const response=await timed('https://api.zippopotam.us/us/'+args.zip);
   if(response.status===404)throw new RetailerError('ZIP code was not found.',404);
   if(!response.ok)throw new RetailerError('ZIP lookup is unavailable. Try again.');
   const payload=await body(response),place=payload.places?.[0];
   if(payload['post code']!==args.zip || typeof place?.['place name']!=='string' || !/^[A-Z]{2}$/.test(place?.['state abbreviation']))throw new RetailerError('ZIP lookup returned an unreadable response.');
   return {zip:args.zip,city:place['place name'],state:place['state abbreviation']};
  }
  if(action==='stores'){
   const radius=args.radius??25;
   if(!Number.isInteger(radius)||radius<5||radius>100)throw new RetailerError('Choose a radius from 5 to 100 miles.',400);
   const url=new URL('https://api.kroger.com/v1/locations');
   url.search=new URLSearchParams({'filter.zipCode.near':args.zip,'filter.radiusInMiles':String(radius),'filter.limit':'50'}).toString();
   const locations=await kroger(url.toString());
   return locations.filter(p=>typeof p?.locationId==='string' && /^[0-9]{1,30}$/.test(p.locationId)).map(p=>({retailer:'kroger',id:p.locationId,name:typeof p.name==='string' && p.name?p.name:'Kroger',address:[p.address?.addressLine1,p.address?.city,p.address?.state,p.address?.zipCode].filter(v=>typeof v==='string' && v).join(', '),state:typeof p.address?.state==='string'?p.address.state:''}));
  }
  if(action==='products'){
   if(typeof args.storeId!=='string'|| !/^[0-9]{1,30}$/.test(args.storeId))throw new RetailerError('Select a valid Kroger location.',400);
   const query=typeof args.query==='string'?args.query.trim():'';
   if(query.length<2 || query.length>100)throw new RetailerError('Search must contain 2–100 characters.',400);
   const url=new URL('https://api.kroger.com/v1/products');
   url.search=new URLSearchParams({'filter.locationId':args.storeId,'filter.term':query,'filter.limit':'50'}).toString();
   return normalizeProducts(await kroger(url.toString()),args.storeId,new Date(clock()));
  }
  throw new RetailerError('This retailer operation is not available yet.',400);
 }};
}
