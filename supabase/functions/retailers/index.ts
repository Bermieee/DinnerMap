import { createClient } from 'npm:@supabase/supabase-js@2.99.1';
import { createRetailerService, RetailerError } from './core.mjs';
import { createHandler } from './handler.mjs';

const url=Deno.env.get('SUPABASE_URL')!;
const key=Deno.env.get('SUPABASE_ANON_KEY')!;
function accountClient(authorization:string){
 return createClient(url,key,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
}
const service=createRetailerService({clientId:Deno.env.get('KROGER_CLIENT_ID')??'',clientSecret:Deno.env.get('KROGER_CLIENT_SECRET')??''});
Deno.serve(createHandler({
 verify:async(token:string)=>{
  const {data:{user},error}=await accountClient('Bearer '+token).auth.getUser(token);
  return error?null:user;
 },
 consume:async(authorization:string)=>{
  const {data,error}=await accountClient(authorization).rpc('consume_retailer_request');
  if(error)throw new RetailerError('Store service is not configured yet.');
  return data;
 },
 cacheRead:async(zip:string,authorization:string)=>{
  const {data,error}=await accountClient(authorization).from('zip_regions').select('zip,city,state,retrieved_at').eq('zip',zip).maybeSingle();
  if(error)throw error;return data;
 },
 cacheWrite:async(data:Record<string,unknown>)=>{
  const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {error}=await admin.from('zip_regions').upsert(data);if(error)throw error;
 },
 dispatch:service.dispatch,
}));
