import {useEffect,useState} from 'react';
import {registerSW} from 'virtual:pwa-register';
import {RefreshCw} from 'lucide-react';
import './pwa-update.css';

// The update is deliberately user-triggered: forcing a reload could interrupt a live voice call.
export default function PWAUpdateNotice(){
  const [available,setAvailable]=useState(false);
  const [updating,setUpdating]=useState(false);
  const [checkUpdate,setCheckUpdate]=useState<(()=>void)|null>(null);
  const [applyUpdate,setApplyUpdate]=useState<(()=>Promise<void>)|null>(null);
  useEffect(()=>{
    if(!('serviceWorker' in navigator))return;
    const updateSW=registerSW({
      immediate:true,
      onNeedRefresh(){setAvailable(true)},
      onRegisteredSW(_swUrl,registration){
        if(!registration)return;
        const check=()=>{if(navigator.onLine)void registration.update().catch(()=>{})};
        setCheckUpdate(()=>check);
        check();
      }
    });
    setApplyUpdate(()=>(()=>updateSW(true)));
  },[]);
  useEffect(()=>{
    if(!checkUpdate)return;
    const timer=window.setInterval(checkUpdate,60_000);
    const onVisible=()=>{if(document.visibilityState==='visible')checkUpdate()};
    document.addEventListener('visibilitychange',onVisible);
    return()=>{window.clearInterval(timer);document.removeEventListener('visibilitychange',onVisible)};
  },[checkUpdate]);
  if(!available)return null;
  return <div role="status" aria-live="polite" className="jayhun-update">
    <div className="jayhun-update__copy"><strong>Yangi versiya tayyor</strong><span>JAYHUN TAXI yangilandi. Ovozli suhbat tugagach, ilovani yangilang.</span></div>
    <button type="button" disabled={updating} onClick={()=>{setUpdating(true);void applyUpdate?.().catch(()=>setUpdating(false))}}>
      <RefreshCw size={16}/>{updating?'Yangilanmoqda…':'Yangilash'}
    </button>
  </div>;
}
