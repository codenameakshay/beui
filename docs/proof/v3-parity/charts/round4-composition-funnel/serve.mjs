import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
const candidate=resolve(process.argv[2]);
const source=resolve(process.argv[3]);
createServer(async(req,res)=>{
  try {
    const pathname=new URL(req.url,'http://localhost').pathname;
    const prefix=['/empty-source/','/empty-candidate/','/source/'].find(prefix=>pathname.startsWith(prefix));
    const root=prefix==='/empty-source/'?resolve(process.argv[4]):prefix==='/empty-candidate/'?resolve(process.argv[5]):prefix==='/source/'?source:candidate;
    let file=resolve(root,'.'+(prefix?pathname.slice(prefix.length-1):pathname));
    if(!file.startsWith(root+'/')&&file!==root)throw Error('path');
    if((await stat(file)).isDirectory())file+='/index.html';
    res.setHeader('Content-Type',({'.html':'text/html','.js':'text/javascript','.css':'text/css','.json':'application/json','.wasm':'application/wasm','.ttf':'font/ttf','.woff2':'font/woff2','.png':'image/png'})[extname(file)]||'application/octet-stream');
    res.setHeader('Cache-Control','no-store');
    res.end(await readFile(file));
  }catch {res.writeHead(404);res.end('Not found');}
}).listen(18116,'127.0.0.1',()=>console.log('Owned parity server on 18116'));
