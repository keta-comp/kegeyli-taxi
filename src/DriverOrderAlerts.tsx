import {useCallback,useEffect,useRef,useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {Bell, BellRing, CheckCheck, Volume2, VolumeX, X} from 'lucide-react';
import './driver-alerts.css';

type Announcement={order_id:string;order_number:number;pickup_address:string;destination:string;passengers_count:number;price:number;status:string};
type Props={db:SupabaseClient;driverId:string;online:boolean;showSettings:boolean;onClaim:(orderId:string)=>Promise<void>;onShowOrders:()=>void};

/** Realtime alerts work when the PWA is running; background/closed push needs a push backend. */
export default function DriverOrderAlerts({db,driverId,online,showSettings,onClaim,onShowOrders}:Props){
 const [enabled,setEnabled]=useState(false),[muted,setMuted]=useState(false),[incoming,setIncoming]=useState<Announcement|null>(null),[claiming,setClaiming]=useState(false),[permission,setPermission]=useState(typeof Notification==='undefined'?'unsupported':Notification.permission);
 const audio=useRef<AudioContext|null>(null),bellTimer=useRef<number|undefined>(undefined),announced=useRef<Set<string>>(new Set());
 const stopBell=useCallback(()=>{window.clearInterval(bellTimer.current);bellTimer.current=undefined;},[]);
 const bell=useCallback(()=>{
  const ctx=audio.current;if(!ctx||ctx.state!=='running')return;
  const now=ctx.currentTime;
  for(let i=0;i<3;i++){
   const oscillator=ctx.createOscillator(),gain=ctx.createGain();
   oscillator.type='sine';oscillator.frequency.value=i===1?780:960;
   const begin=now+i*.22;gain.gain.setValueAtTime(.0001,begin);gain.gain.exponentialRampToValueAtTime(.14,begin+.016);gain.gain.exponentialRampToValueAtTime(.0001,begin+.19);
   oscillator.connect(gain);gain.connect(ctx.destination);oscillator.start(begin);oscillator.stop(begin+.2);
  }
 },[]);
 useEffect(()=>{
  if(!incoming||!enabled||muted||!online){stopBell();return}
  bell();bellTimer.current=window.setInterval(bell,2600);return stopBell;
 },[incoming?.order_id,enabled,muted,online,bell,stopBell]);
 useEffect(()=>{
  if(!online){setIncoming(null);stopBell();return}
  const channel=db.channel('jayhun-alerts-'+driverId).on('postgres_changes',{event:'INSERT',schema:'public',table:'order_announcements'},payload=>{
   const order=payload.new as Announcement;
   if(order.status!=='NEW'||announced.current.has(order.order_id))return;
   announced.current.add(order.order_id);setIncoming(order);
   if('Notification' in window&&Notification.permission==='granted'&&'serviceWorker' in navigator){
    void navigator.serviceWorker.ready.then(reg=>reg.showNotification('Yangi JAYHUN TAXI buyurtmasi',{
     body:order.pickup_address+' → '+order.destination,
     icon:'/icons/icon-192.png',badge:'/icons/favicon-32.png',tag:'jayhun-order-'+order.order_id,
     data:{url:'/?open=orders'},
    })).catch(()=>{});
   }
  }).subscribe();
  return()=>{void db.removeChannel(channel)};
 },[db,driverId,online,stopBell]);
 useEffect(()=>()=>{stopBell();void audio.current?.close()},[stopBell]);
 async function enable(){
  try{
   if(!audio.current)audio.current=new AudioContext();
   await audio.current.resume();
   let result:NotificationPermission|'unsupported'='unsupported';
   if('Notification' in window)result=await Notification.requestPermission();
   setPermission(result);setEnabled(true);
  }catch{setEnabled(true)}
 }
 function dismiss(){setIncoming(null);stopBell()}
 async function accept(){if(!incoming)return;setClaiming(true);try{await onClaim(incoming.order_id);dismiss();onShowOrders()}finally{setClaiming(false)}}
 return <>
  {showSettings&&<section className="alerts-settings"><div className="alerts-settings-copy"><Bell size={19}/><div><strong>Buyurtma xabarnomalari</strong><small>{enabled?'Yangi buyurtma kelganda ovozli signal ishlaydi':'Signal eshitish uchun xabarnomani yoqing'}</small></div></div><div className="alerts-settings-actions">{enabled&&<button type="button" aria-label={muted?'Ovozni yoqish':'Ovozni o‘chirish'} onClick={()=>setMuted(v=>!v)}>{muted?<VolumeX size={19}/>:<Volume2 size={19}/>}</button>}<button type="button" className={enabled?'enabled':'primary'} onClick={()=>void enable()}>{enabled?<><CheckCheck size={15}/> Yoqilgan</>:'Yoqish'}</button></div></section>}
  {enabled&&permission==='denied'&&<p className="alerts-permission">Telefon bildirishnomalari bloklangan. Chrome sayt sozlamalaridan Notifications ruxsatini berish mumkin; ilova ochiq turganda ovozli signal ishlaydi.</p>}
  {incoming&&online&&<div className="order-alert-backdrop" role="alertdialog" aria-modal="true" aria-labelledby="order-alert-title"><div className="order-alert-sheet"><div className="order-alert-top"><span><BellRing size={19}/> YANGI BUYURTMA #{incoming.order_number}</span><button type="button" onClick={dismiss} aria-label="Ogohlantirishni yopish"><X size={21}/></button></div><h2 id="order-alert-title">Yangi zakaz keldi!</h2><div className="order-alert-route"><strong>{incoming.pickup_address}</strong><span>↓</span><strong>{incoming.destination}</strong></div><p>{incoming.passengers_count} yo‘lovchi · {incoming.price.toLocaleString('uz-UZ')} so‘m</p><div className="order-alert-buttons"><button type="button" onClick={dismiss}>Keyinroq</button><button type="button" className="primary" onClick={()=>void accept()} disabled={claiming}>{claiming?'Yuborilmoqda…':'OLAMAN'}</button></div><small>Signal ilova ochiq turganda tasdiqlamaguningizcha takrorlanadi. Telefon qulfda bo‘lsa ovoz tizim tomonidan cheklanishi mumkin.</small></div></div>}
 </>;
}