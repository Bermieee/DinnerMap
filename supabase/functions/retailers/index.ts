import { createClient } from 'npm:@supabase/supabase-js@2.99.1';
import { createRetailerService, RetailerError } from './core.mjs';

const service = createRetailerService({
  clientId: Deno.env.get('KROGER_CLIENT_ID') ?? '',
  clientSecret: Deno.env.get('KROGER_CLIENT_SECRET') ?? '',
});
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}
Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, {status:204, headers:cors});
  if (request.method !== 'POST') return reply({error:'Use POST.'},405);
  const authorization=request.headers.get('Authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) return reply({error:'Sign in to discover stores.'},401);
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{
    global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false},
  });
  const {data:{user},error:authError}=await client.auth.getUser(authorization.slice(7));
  if(authError || !user || !user.email_confirmed_at)return reply({error:'Verify your account to discover stores.'},401);
  const {data:allowed,error:rateError}=await client.rpc('consume_retailer_request');
  if(rateError)return reply({error:'Store service is not configured yet.'},503);
  if(allowed!==true)return reply({error:'Request limit reached. Wait a minute and retry.'},429);
  let input;
  try {
    const text=await request.text();
    if(text.length>2048)return reply({error:'Request is too large.'},413);
    input=JSON.parse(text);
    if(!input || typeof input!=='object' || Array.isArray(input))return reply({error:'Invalid request.'},400);
  }catch{return reply({error:'Invalid request.'},400);}
  try {
    if(input.action==='region' && typeof input.zip==='string' && /^[0-9]{5}$/.test(input.zip)) {
      const {data}=await client.from('zip_regions').select('zip,city,state,retrieved_at').eq('zip',input.zip).maybeSingle();
      if(data && Date.parse(data.retrieved_at)>Date.now()-30*86400000)return reply({data:{zip:data.zip,city:data.city,state:data.state}});
    }
    const data=await service.dispatch(input.action,input);
    if(input.action==='region') {
      const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
      await admin.from('zip_regions').upsert({...data,retrieved_at:new Date().toISOString()});
    }
    return reply({data});
  }catch(error) {
    if(error instanceof RetailerError)return reply({error:error.message},error.status);
    return reply({error:'Store service is temporarily unavailable. Try again.'},503);
  }
});
