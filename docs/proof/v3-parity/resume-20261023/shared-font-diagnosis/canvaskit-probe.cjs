const fs=require('fs'); global.fetch=async url=>new Response(fs.readFileSync(new URL(url)),{headers:{'Content-Type':'application/wasm'}});
const base='/tmp/beui-bump-r4-after-20261023-v12';

(async()=>{const init=(await import(base+'/canvaskit/chromium/canvaskit.js')).default;const ck=await init({wasmBinary:fs.readFileSync(base+'/canvaskit/chromium/canvaskit.wasm')});
 const manifest=JSON.parse(fs.readFileSync(base+'/assets/FontManifest.json'));const rows=[];
 for(const mode of ['manifest','mono-only','reverse','regular-only','medium-only']) {
 const p=ck.TypefaceFontProvider.Make();let fams=manifest.filter(x=>['Geist','Geist Mono','monospace'].includes(x.family)); if(mode==='mono-only')fams=fams.filter(x=>x.family==='monospace');if(mode==='reverse')fams.reverse();
 for(const f of fams)for(const asset of f.fonts.filter(a=>mode==='regular-only'?a.weight===400:mode==='medium-only'?a.weight===500:true))p.registerFont(fs.readFileSync(base+'/assets/'+asset.asset),f.family);
 for(const family of ['Geist','Geist Mono','monospace'])for(const weight of [400,500])for(const text of ['0000000000','iiiiiiiiii','WWWWWWWWWW','123.45']){
 const builder=ck.ParagraphBuilder.MakeFromFontProvider(ck.ParagraphStyle({disableHinting:false,textStyle:{fontFamilies:[family],fontSize:12,fontStyle:{weight:weight===400?ck.FontWeight.Normal:ck.FontWeight.Medium}}}),p);builder.addText(text);const para=builder.build();para.layout(1000);rows.push({mode,family,weight,text,width:para.getMaxIntrinsicWidth(),height:para.getHeight()});para.delete();builder.delete();}p.delete();}
 fs.writeFileSync('/tmp/beui-shared-font-diagnosis-20261023/canvaskit-probe.json',JSON.stringify(rows,null,2));console.log(rows);
})();
