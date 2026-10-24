import React from 'react';
import {createRoot} from 'react-dom/client';
import {Combobox,ComboboxTrigger,ComboboxInput,ComboboxContent,ComboboxList,ComboboxEmpty,ComboboxGroup,ComboboxItem} from '@/components/motion/combobox';
const events:any[]=[]; (globalThis as any).__events=events;
function event(type:string,value:any){events.push({type,value,time:performance.now()});}
createRoot(document.getElementById('root')!).render(<div style={{width:260}}><Combobox onOpenChange={v=>event('open',v)} onQueryChange={v=>event('query',v)} onValueChange={v=>event('value',v)}><ComboboxTrigger><ComboboxInput aria-label="Search fruits"/></ComboboxTrigger><ComboboxContent><ComboboxList><ComboboxEmpty>Nothing found</ComboboxEmpty><ComboboxGroup label="Fresh"><ComboboxItem value="apple" textValue="Apple">Apple</ComboboxItem><ComboboxItem value="banana" textValue="Banana">Banana</ComboboxItem><ComboboxItem value="cherry" textValue="Cherry" disabled>Cherry</ComboboxItem></ComboboxGroup></ComboboxList></ComboboxContent></Combobox></div>);
