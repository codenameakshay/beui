import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const data=JSON.parse(await readFile(new URL('./baseline/results.json',import.meta.url)));
const failures=data.results.flatMap(r=>r.states.filter(s=>s.name==='click'||s.name==='tap2').filter(s=>s.text!=='').map(s=>`${r.mode}/${r.reducedMotion}/${s.name}: ${s.text}`));
console.log(JSON.stringify({cases:data.results.length,failures},null,2));
assert.equal(failures.length,0,'Native dismissal must remove the readout');
