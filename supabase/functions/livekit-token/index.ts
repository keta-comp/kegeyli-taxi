import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';
import { AccessToken } from 'npm:livekit-server-sdk@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return new Response('Method not allowed',{status:405,headers:cors});
  try{
    const auth=req.headers.get('Authorization')||'';
    if(!auth.startsWith('Bearer '))return Response.json({error:'Missing auth'},{status:401,headers:cors});
    const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
    const {data:{user},error}=await client.auth.getUser();
    if(error||!user)return Response.json({error:'Unauthorized'},{status:401,headers:cors});
    const {data:profile}=await client.from('profiles').select('name,role,active').eq('id',user.id).single();
    if(!profile?.active||!['driver','operator','admin'].includes(profile.role))return Response.json({error:'Forbidden'},{status:403,headers:cors});
    if(profile.role==='driver'){
      const {data:driver,error:driverError}=await client.from('drivers').select('is_online').eq('user_id',user.id).single();
      if(driverError||!driver?.is_online)return Response.json({error:'Avval bosh sahifada ONLINE holatini yoqing.'},{status:403,headers:cors});
      // Background browsers pause intervals; renew presence now instead of rejecting a legitimately online driver.
      const {error:presenceError}=await client.from('drivers')
        .update({last_seen_at:new Date().toISOString()}).eq('user_id',user.id);
      if(presenceError)return Response.json({error:'Faollikni yangilab bo‘lmadi. Internetni tekshiring.'},{status:409,headers:cors});
    }
    const {room}=await req.json().catch(()=>({room:'JAYHUN_TAXI_MAIN_ROOM'}));
    if(room!=='JAYHUN_TAXI_MAIN_ROOM')return Response.json({error:'Invalid room'},{status:403,headers:cors});
    const key=Deno.env.get('LIVEKIT_API_KEY'),secret=Deno.env.get('LIVEKIT_API_SECRET'),serverUrl=Deno.env.get('LIVEKIT_URL');
    if(!key||!secret||!serverUrl)throw new Error('Voice server configuration missing');
    const at=new AccessToken(key,secret,{identity:user.id,name:profile.name,ttl:'2h'});
    at.addGrant({roomJoin:true,room:'JAYHUN_TAXI_MAIN_ROOM',canPublish:true,canSubscribe:true,canPublishData:true});
    return Response.json({token:await at.toJwt(),serverUrl},{headers:cors});
  }catch(e){return Response.json({error:e instanceof Error?e.message:'Server error'},{status:500,headers:cors})}
});
