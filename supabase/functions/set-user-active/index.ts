import {serve} from 'https://deno.land/std@0.224.0/http/server.ts';
import {createClient} from 'npm:@supabase/supabase-js@2';
import {RoomServiceClient} from 'npm:livekit-server-sdk@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return Response.json({error:'Method not allowed'},{status:405,headers:cors});
 try{
  const auth=req.headers.get('Authorization')||'';
  if(!auth.startsWith('Bearer '))return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await client.auth.getUser();
  if(!user)return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const {data:profile}=await client.from('profiles').select('role,active').eq('id',user.id).single();
  if(profile?.role!=='admin'||!profile.active)return Response.json({error:'Admin only'},{status:403,headers:cors});
  const {targetId,active}=await req.json();
  if(typeof targetId!=='string'||typeof active!=='boolean'||targetId===user.id)
   return Response.json({error:'Invalid target'},{status:400,headers:cors});
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const {data:target,error:tError}=await admin.from('profiles').select('id,role').eq('id',targetId).single();
  if(tError||!target)return Response.json({error:'User not found'},{status:404,headers:cors});
  const {error:upError}=await admin.from('profiles').update({active}).eq('id',targetId);
  if(upError)throw upError;
  if(!active){
    await admin.from('drivers').update({is_online:false,last_seen_at:null}).eq('user_id',targetId);
    const serverUrl=Deno.env.get('LIVEKIT_URL');
    const apiKey=Deno.env.get('LIVEKIT_API_KEY');
    const secret=Deno.env.get('LIVEKIT_API_SECRET');
    if(serverUrl&&apiKey&&secret){
      const host=serverUrl.replace(/^wss:/,'https:').replace(/^ws:/,'http:');
      try{await new RoomServiceClient(host,apiKey,secret).removeParticipant('JAYHUN_TAXI_MAIN_ROOM',targetId)}
      catch(e){console.warn('User not connected or removal failed:',e)}
    }
  }
  return Response.json({ok:true},{headers:cors});
 }catch(e){return Response.json({error:e instanceof Error?e.message:'Server error'},{status:500,headers:cors})}
});
