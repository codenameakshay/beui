import {mkdir,readFile,writeFile} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
const [source,candidate,output]=process.argv.slice(2);
await mkdir(output);
const roi={x:256,y:266,width:768,height:320};
function pixels(path){
  const p=spawnSync('ffmpeg',['-v','error','-i',path,'-vf',`crop=${roi.width}:${roi.height}:${roi.x}:${roi.y}`,'-f','rawvideo','-pix_fmt','rgb24','-'],{maxBuffer:10000000});
  if(p.status!==0)throw Error(p.stderr.toString());return p.stdout;
}
const a=pixels(source),b=pixels(candidate),diff=Buffer.alloc(a.length);
let sum=0,squared=0,changed=0,over8=0,over24=0;
for(let i=0;i<a.length;i+=3){
  let max=0;
  for(let c=0;c<3;c++){const d=Math.abs(a[i+c]-b[i+c]);diff[i+c]=d;sum+=d;squared+=d*d;max=Math.max(max,d);}
  if(max>0)changed++;if(max>8)over8++;if(max>24)over24++;
}
const metrics={roi,pixels:a.length/3,changed,over8,over24,meanAbsoluteChannelDelta:sum/a.length,rootMeanSquareChannelDelta:Math.sqrt(squared/a.length),source:{path:source,sha256:createHash('sha256').update(await readFile(source)).digest('hex')},candidate:{path:candidate,sha256:createHash('sha256').update(await readFile(candidate)).digest('hex')},verdict:changed===0?'pixel-identical':'nonzero raster delta; not pixel-zero certified'};
const encoded=spawnSync('ffmpeg',['-v','error','-f','rawvideo','-pixel_format','rgb24','-video_size',`${roi.width}x${roi.height}`,'-i','-','-frames:v','1',`${output}/absolute-diff.png`],{input:diff});
if(encoded.status!==0)throw Error(encoded.stderr.toString());
await writeFile(`${output}/metrics.json`,JSON.stringify(metrics,null,2));
console.log(JSON.stringify(metrics,null,2));
