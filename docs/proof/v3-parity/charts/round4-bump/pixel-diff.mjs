import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {spawnSync} from 'node:child_process';
const [reference,candidate,output] = process.argv.slice(2);
await mkdir(output);
const results=[];
const names=process.argv[5]==='interaction'?
  ['no-preference-keyboard-3.png','no-preference-keyboard-8.png','no-preference-keyboard-14.png','no-preference-touch-17.png','reduce-keyboard-22.png','reduce-keyboard-27.png','reduce-keyboard-33.png','reduce-touch-36.png']:
  ['dark','light'].flatMap(theme=>['default','composed','narrow','empty','missing','update'].map(variant=>`${theme}-${variant}.png`));
for (const name of names) {
  const variant=name.split('-')[1].replace('.png','');
  const header=await readFile(`${reference}/${name}`);
  const width=header.readUInt32BE(16),height=header.readUInt32BE(20);
  const decode=path=>{
    const r=spawnSync('ffmpeg',['-nostdin','-v','error','-i',path,'-f','rawvideo','-pix_fmt','rgba','-'],{maxBuffer:width*height*5});
    if(r.status!==0) throw Error(r.stderr.toString());
    return r.stdout;
  };
  const a=decode(`${reference}/${name}`),b=decode(`${candidate}/${name}`);
  if(a.length!==b.length) throw Error('Mismatched native dimensions');
  const diff=Buffer.alloc(a.length);
  let pixels=0,above8=0,absolute=0,squared=0,minX=width,minY=height,maxX=-1,maxY=-1;
  const regions={plot:0,legend:0};
  const plotBottom=variant==='empty'||variant==='missing'?228:variant==='narrow'?320:333.714;
  for(let i=0;i<a.length;i+=4){
    const x=(i/4)%width,y=Math.floor(i/4/width);
    let max=0;
    for(let channel=0;channel<3;channel++){
      const delta=Math.abs(a[i+channel]-b[i+channel]);
      absolute+=delta;squared+=delta*delta;max=Math.max(max,delta);
      diff[i+channel]=delta;
    }
    diff[i+3]=255;
    if(max){pixels++;regions[y<plotBottom?'plot':'legend']++;minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);}
    if(max>8)above8++;
  }
  const encode=spawnSync('ffmpeg',['-nostdin','-v','error','-f','rawvideo','-pixel_format','rgba','-video_size',`${width}x${height}`,'-i','-','-frames:v','1',`${output}/${name}`],{input:diff,maxBuffer:1000000});
  if(encode.status!==0)throw Error(encode.stderr.toString());
  results.push({name,width,height,exactMismatchedPixels:pixels,pixelsAbove8:above8,percent:100*pixels/(width*height),meanAbsoluteChannelError:absolute/(width*height*3),rootMeanSquareChannelError:Math.sqrt(squared/(width*height*3)),bounds:maxX<0?null:{minX,minY,maxX,maxY},regions,verdict:pixels===0?'exact pixel match':'not exact parity'});
}
await writeFile(`${output}/metrics.json`,JSON.stringify({reference,candidate,noResize:true,noRegistration:true,thresholdForPass:0,results},null,2),{flag:'wx'});
console.log(JSON.stringify(results.map(x=>({name:x.name,pixels:x.exactMismatchedPixels,regions:x.regions}))));
