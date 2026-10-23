import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve, extname} from 'node:path';

const [before, source, after = before] = process.argv.slice(2).map(p => resolve(p));
const roots = {before, source, after};
const types = {'.html':'text/html','.js':'text/javascript','.css':'text/css','.wasm':'application/wasm','.json':'application/json','.ttf':'font/ttf','.woff2':'font/woff2','.png':'image/png'};
createServer(async (request,response) => {
  const [prefix,...parts] = new URL(request.url,'http://localhost').pathname.split('/').filter(Boolean);
  const root = roots[prefix];
  const path = root && resolve(root,parts.join('/') || 'index.html');
  if (!path || !path.startsWith(`${root}/`)) {response.writeHead(404).end();return;}
  try {
    let bytes = await readFile(path);
    if (extname(path) === '.html') bytes = Buffer.from(bytes.toString().replace('<base href="/">',`<base href="/${prefix}/">`));
    response.writeHead(200,{'Content-Type':types[extname(path)] ?? 'application/octet-stream','Cache-Control':'no-store'}).end(bytes);
  } catch {response.writeHead(404).end();}
}).listen(18139,'127.0.0.1');
