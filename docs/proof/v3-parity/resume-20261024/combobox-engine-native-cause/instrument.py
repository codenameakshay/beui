from pathlib import Path
import shutil
s=Path('/tmp/beui-gallery-engine-causal-r10'); e=s/'sdk/bin/cache/flutter_web_sdk/lib/_engine/engine'; out=Path.cwd()/'docs/proof/v3-parity/resume-20261024/combobox-engine-native-cause'
def edit(p,f):
 rel=p.relative_to(s); b=out/'baseline'/rel;b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,b);p.write_text(f(p.read_text()))
helper="""
@JS('__r10Trace')
external void r10Sink(JSString event, JSString detail, JSAny? node);
void r10Trace(String event, [Map<String, Object?> detail = const {}, JSAny? node]) {
  r10Sink(event.toJS, jsonEncode(detail).toJS, node);
}
"""
def textedit(t):
 t=t.replace('/// Text editing singleton.',helper+'\n/// Text editing singleton.')
 t=t.replace('void applyToDomElement(DomHTMLElement? domElement) {',"void applyToDomElement(DomHTMLElement? domElement) {\n r10Trace('DOM.apply', {'new':text,'base':baseOffset,'extent':extentOffset},domElement);")
 t=t.replace('void handleChange(DomEvent event) {',"void handleChange(DomEvent event) {\n r10Trace('engine.handleChange',{'type':event.type},activeDomElement);")
 t=t.replace('    command.run(this);',"    r10Trace('channel.command',{'type':command.runtimeType.toString(),'client':_clientId});\n    command.run(this);\n    r10Trace('channel.done',{'client':_clientId});")
 t=t.replace('void updateEditingState(int? clientId, EditingState? editingState) {',"void updateEditingState(int? clientId, EditingState? editingState) {\n r10Trace('channel.update',{'client':clientId,'state':editingState?.toFlutter()});")
 # toFlutter availability checked below
 t=t.replace("'state':editingState?.toFlutter()","'text':editingState?.text")
 t=t.replace('void setEditingState(EditingState? editingState) {',"void setEditingState(EditingState? editingState) {\n r10Trace('strategy.setState',{'text':editingState?.text,'enabled':isEnabled});")
 return t
edit(e/'text_editing/text_editing.dart',textedit)
def semantics(t):
 t=t.replace('    this.inputConfig = inputConfig;',"    r10Trace('semantics.enable',{'enabled':isEnabled,'listeners':subscriptions.length});\n    this.inputConfig = inputConfig;")
 t=t.replace('void activate(SemanticTextField textField) {',"void activate(SemanticTextField textField) {\n r10Trace('semantics.activate',{'semanticNode':textField.semanticsObject.id,'enabled':isEnabled,'listeners':subscriptions.length},textField.editableElement);")
 t=t.replace('void disable() {',"void disable() {\n r10Trace('semantics.disable',{'enabled':isEnabled,'listeners':subscriptions.length});")
 t=t.replace('void addEventHandlers() {',"void addEventHandlers() {\n r10Trace('semantics.addHandlers',{},activeDomElement);")
 return t
edit(e/'semantics/text_field.dart',semantics)
edit(e/'dom.dart',lambda t:t.replace('    target.addEventListener(type, listener);',"    r10Trace('listener.add',{'type':type},target);\n    target.addEventListener(type, listener);").replace('void cancel() => target.removeEventListener(type, listener);',"void cancel() { r10Trace('listener.remove',{'type':type},target); target.removeEventListener(type, listener); }"))
p=s/'sdk/packages/flutter/lib/src/widgets/editable_text.dart'
edit(p,lambda t:"import 'dart:js_interop';\nimport 'dart:convert';\n"+t.replace('/// Signature for the callback',helper+'\n/// Signature for the callback',1).replace('  set value(TextEditingValue newValue) {',"  set value(TextEditingValue newValue) {\n r10Trace('framework.controller',{'old':value.text,'new':newValue.text,'base':newValue.selection.baseOffset,'extent':newValue.selection.extentOffset});").replace('void updateEditingValue(TextEditingValue value) {',"void updateEditingValue(TextEditingValue value) {\n r10Trace('framework.updateEditingValue',{'text':value.text});"))
p=s/'gallery/lib/src/motion/combobox.dart'
edit(p,lambda t:"import 'dart:js_interop';\nimport 'dart:convert';\n"+t.replace('/// Search matcher',helper+'\n/// Search matcher',1).replace('  void _setQuery(String next) {',"  void _setQuery(String next) {\n r10Trace('combo.query',{'next':next,'open':_open});").replace('        onChanged: (query) {',"        onChanged: (query) {\n r10Trace('combo.onChanged',{'text':query});"))
for p in [e/'text_editing/text_editing.dart',e/'semantics/text_field.dart',e/'dom.dart',s/'sdk/packages/flutter/lib/src/widgets/editable_text.dart',s/'gallery/lib/src/motion/combobox.dart']:
 d=out/'instrumented'/p.relative_to(s);d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,d)
