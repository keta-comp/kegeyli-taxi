import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const source=path.join(root,'public','jayhun-mark.svg');
const out=path.join(root,'public','icons');
await mkdir(out,{recursive:true});
for(const [name,size] of [['icon-192.png',192],['icon-512.png',512],['apple-touch-icon.png',180],['favicon-32.png',32]]){
  await sharp(source).resize(size,size,{fit:'contain',background:'#00000000',kernel:'lanczos3'}).png().toFile(path.join(out,name));
}
console.info('JAYHUN TAXI logo icons generated');
