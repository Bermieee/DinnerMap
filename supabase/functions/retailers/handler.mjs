import {RetailerError} from './core.mjs';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
async function boundedBody(request){
 if(Number(request.headers.get('Content-Length'))>2048)throw new RetailerError('Request is too large.',413);
 const reader=request.body?.getReader();if(!reader)throw new RetailerError('Invalid request.',400);
 const chunks=[];let size=0;
 try{
  while(true){const {value,done}=await reader.read();if(done)break;size+=value.length;if(size>2048){await reader.cancel();throw new RetailerError('Request is too large.',413);}chunks.push(value);}
 }finally{reader.releaseLock();}
 const bytes=new Uint8Array(size);let offset=0;for(const c of chunks){bytes.set(c,offset);offset+=c.length;}
 try {const data=JSON.parse(new TextDecoder().decode(bytes));if(!data || typeof data!=='object' || Array.isArray(data))throw Error();return data;}
 catch{throw new RetailerError('Invalid request.',400);}
}
export function createHandler({verify,consume,cacheRead,cacheWrite,dispatch,clock=()=>Date.now()}){
 return async(request)=>{
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
  if(request.method!=='POST')return reply({error:'Use POST.'},405);
  try{
   const authorization=request.headers.get('Authorization')??'';
   if(!authorization.startsWith('Bearer ') || authorization.length>8192)return reply({error:'Sign in to discover stores.'},401);
   const user=await verify(authorization.slice(7));
   if(!user?.id || !user.email_confirmed_at)return reply({error:'Verify your account to discover stores.'},401);
   if(await consume(authorization)!==true)return reply({error:'Request limit reached. Wait a minute and retry.'},429);
   const input=await boundedBody(request);
   if(input.action==='region' && typeof input.zip==='string' && /^[0-9]{5}$/.test(input.zip)){
    try{
     const cached=await cacheRead(input.zip,authorization);
     if(cached?.zip===input.zip && /^[A-Z]{2}$/.test(cached.state) && typeof cached.city==='string' && Date.parse(cached.retrieved_at)>clock()-30*86400000){
      return reply({data:{zip:cached.zip,city:cached.city,state:cached.state}});
     }
    }catch{/* Optional cache failure does not block the resolver. */}
   }
   const data=await dispatch(input.action,input);
   if(input.action==='region'){
    try{await cacheWrite({...data,retrieved_at:new Date(clock()).toISOString()});}catch{/* Positive result remains usable if caching fails. */}
   }
   return reply({data});
  }catch(error){
   if(error instanceof RetailerError)return reply({error:error.message},error.status);
   return reply({error:'Store service is temporarily unavailable. Try again.'},503);
  }
 };
}
