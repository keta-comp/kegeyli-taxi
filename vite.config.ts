import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';
export default defineConfig({ plugins: [react(), VitePWA({registerType:'prompt', manifest:{name:'JAYHUN TAXI',short_name:'JAYHUN',description:'Kegeyli taksi operator va haydovchilar tizimi',theme_color:'#f5bb12',background_color:'#ffffff',display:'standalone',start_url:'/',icons:[{src:'/icon.svg',sizes:'any',type:'image/svg+xml',purpose:'any maskable'}]}})] });