import pathlib,shutil,json
r=pathlib.Path.cwd(); d=pathlib.Path('/tmp/beui-rapid-input-20261024/candidate');d.mkdir()
for f in ['lib','assets','shaders','example/lib','example/web']:
 if (r/f).exists(): shutil.copytree(r/f,d/f)
for f in ['pubspec.yaml','pubspec.lock','example/pubspec.yaml','example/pubspec.lock','.dart_tool/package_config.json','example/.dart_tool/package_config.json']:
 (d/f).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(r/f,d/f)
p=d/'lib/src/motion/combobox.dart';s=p.read_text();s="import 'dart:convert';\n"+s
s=s.replace('  void _setQuery(String next) {', '''  int _traceCount = 0;
  void _trace(String event, [Object? detail]) {
    if (_traceCount++ > 1200) return;
    print('COMBO_TRACE ' + jsonEncode({'event':event,'detail':detail,'frame':WidgetsBinding.instance.currentFrameTimeStamp.inMicroseconds,'phase':WidgetsBinding.instance.schedulerPhase.name,'open':_open,'query':_query,'value':_value,'text':_inputController.text,'selection':_inputController.selection.toString(),'items':_items.keys.toList(),'focus':_inputFocus.hasFocus,'primary':FocusManager.instance.primaryFocus?.debugLabel}));
  }
  void _setQuery(String next) {
    _trace('setQuery', next);''')
s=s.replace('    _openQuery = _query;','    _openQuery = _query;\n    _inputController.addListener(() => _trace("controller"));',1)
s=s.replace('    if (widget.disabled && next) return;', "    _trace('setOpen', {'next':next,'restore':restoreFocus});\n    if (widget.disabled && next) return;")
s=s.replace('    _registrants.putIfAbsent', "    _trace('register',item.value);\n    _registrants.putIfAbsent")
s=s.replace('    final owners = _registrants[value];',"    _trace('unregister',value);\n    final owners = _registrants[value];")
s=s.replace('    final key = event.logicalKey;',"    _trace('localKey',event.logicalKey.keyLabel);\n    final key = event.logicalKey;")
s=s.replace('    final colors = BeuiColors.resolve(context);',"    _trace('build');\n    final colors = BeuiColors.resolve(context);",1)
s=s.replace('onDismiss: () => _setOpen(false),',"onDismiss: () { _trace('overlayDismiss'); _setOpen(false); },")
s=s.replace('        onChanged: (query) {',"        onChanged: (query) {\n          state._trace('onChanged', {'capturedOpen':scope.open,'incoming':query});")
s=s.replace('    if (state._inputController.text != text) {',"    state._trace('inputBuild',{'capturedOpen':scope.open,'desired':text});\n    if (state._inputController.text != text) {")
p.write_text(s)
