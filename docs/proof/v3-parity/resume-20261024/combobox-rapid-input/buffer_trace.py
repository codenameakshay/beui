from pathlib import Path
p=Path('/tmp/beui-rapid-input-20261024/candidate/lib/src/motion/combobox.dart');s=Path('/tmp/beui-rapid-input-20261024/combobox-trace-baseline.dart').read_text();s="import 'dart:js_interop';\n"+s
idx=s.index('/// Search matcher');s=s[:idx]+"@JS('__readComboTrace')\nexternal set _traceReader(JSFunction value);\n\n"+s[idx:]
s=s.replace('  int _traceCount = 0;', '  final _traces = <Map<String, Object?>>[];\n  int _traceCount = 0;')
s=s.replace("print('COMBO_TRACE ' + jsonEncode(","_traces.add(").replace("?.debugLabel}));","?.debugLabel,'time':DateTime.now().microsecondsSinceEpoch});")
s=s.replace('    _openQuery = _query;','    _openQuery = _query;\n    _traceReader = (() => jsonEncode(_traces)).toJS;',1)
s=s.replace('          if (!scope.open) state._setOpen(true);','          state._setOpen(true);');p.write_text(s)
for name in ['capture','capture-initial']:
 p=Path('/tmp/beui-rapid-input-20261024')/(name+'-final.mjs');s=p.read_text().replace("const inputs=[...priorInputs", "trace.push(...await page.evaluate(()=>JSON.parse(globalThis.__readComboTrace?.()||'[]')));const inputs=[...priorInputs");Path('/tmp/beui-rapid-input-20261024/'+name+'-buffer.mjs').write_text(s)
