import {serve} from 'https://deno.land/std@0.224.0/http/server.ts';
import {createClient} from 'npm:@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return new Response('Method not allowed',{status:405,headers:cors});
 try{
  const auth=req.headers.get('Authorization')||'';
  if(!auth.startsWith('Bearer '))return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
  const {data:{user}}=await client.auth.getUser();
  if(!user)return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const {data:who}=await client.from('profiles').select('role,active').eq('id',user.id).single();
  if(who?.role!=='admin'||!who.active)return Response.json({error:'Admin access required'},{status:403,headers:cors});
  const input=await req.json();
  const {name,login,password,role,car_model,car_number}=input;
  if(typeof name!=='string'||name.trim().length<2||!['driver','operator','admin'].includes(role)||typeof login!=='string'||!/^[a-zA-Z0-9_-]{3,32}$/.test(login)||typeof password!=='string'||password.length<8)
    return Response.json({error:'Invalid user input'},{status:400,headers:cors});
  if(role==='driver'&&(!car_model||!car_number))return Response.json({error:'Car data required'},{status:400,headers:cors});
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const email=login.toLowerCase()+'@jayhun.local';
  const {data:created,error:authError}=await admin.auth.admin.createUser({email,password,email_confirm:true});
  if(authError||!created.user)return Response.json({error:authError?.message||'Cannot create user'},{status:400,headers:cors});
  const id=created.user.id;
  try{
   const {error:pError}=await admin.from('profiles').insert({id,name:name.trim(),role,active:true});
   if(pError)throw pError;
   if(role==='driver'){const {error:dError}=await admin.from('drivers').insert({user_id:id,car_model,car_number});if(dError)throw dError}
  }catch(err){await admin.auth.admin.deleteUser(id);throw err}
  return Response.json({ok:true,id},{headers:cors});
 }catch(e){return Response.json({error:e instanceof Error?e.message:'Server error'},{status:500,headers:cors})}
});
