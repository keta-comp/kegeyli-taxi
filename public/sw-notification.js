/* Imported by the generated PWA service worker: open the order list when a notification is tapped. */
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  event.waitUntil((async()=>{
    const all=await self.clients.matchAll({type:'window',includeUncontrolled:true});
    for(const client of all){
      if(new URL(client.url).origin===self.location.origin){
        await client.focus();
        client.postMessage({type:'JAYHUN_OPEN_ORDERS'});
        return;
      }
    }
    await self.clients.openWindow('/?open=orders');
  })());
});
