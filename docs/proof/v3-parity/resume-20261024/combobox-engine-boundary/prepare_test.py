from pathlib import Path
r=Path('/tmp/beui-initial-edit-engine-r8/engine/src/flutter/lib/web_ui'); t=r/'lib/src/engine/text_editing/text_editing.dart'; s=t.read_text(); marker='/// Text editing singleton.'
s=s.replace(marker,'''final List<Map<String, Object?>> initialEditTrace = <Map<String, Object?>>[];
final Stopwatch initialEditClock = Stopwatch()..start();
void traceInitialEdit(String event, [Map<String, Object?> detail = const {}]) {
  if (initialEditTrace.length < 200) {
    initialEditTrace.add(<String, Object?>{'us': initialEditClock.elapsedMicroseconds, 'event': event, ...detail});
  }
}

'''+marker)
s=s.replace('void applyToDomElement(DomHTMLElement? domElement) {', '''void applyToDomElement(DomHTMLElement? domElement) {
    traceInitialEdit('DOM.apply', {'old': domElement is DomHTMLInputElement ? domElement.value : null, 'new': text, 'base': baseOffset, 'extent': extentOffset});''')
s=s.replace('void setEditingState(EditingState? editingState) {\n    lastEditingState', "void setEditingState(EditingState? editingState) {\n    traceInitialEdit('strategy.setEditingState', {'enabled': isEnabled, 'text': editingState?.text});\n    lastEditingState")
s=s.replace('void handleChange(DomEvent event) {', "void handleChange(DomEvent event) {\n    traceInitialEdit('handleChange.enter', {'type': event.type});")
s=s.replace('    if (newEditingState != lastEditingState) {', "    traceInitialEdit('handleChange.compare', {'equal': newEditingState == lastEditingState, 'text': newEditingState.text});\n    if (newEditingState != lastEditingState) {")
s=s.replace('    command.run(this);', "    traceInitialEdit('channel.command', {'type': command.runtimeType.toString(), 'clientBefore': _clientId});\n    command.run(this);\n    traceInitialEdit('channel.command.done', {'clientAfter': _clientId});")
t.write_text(s)
t=r/'lib/src/engine/semantics/text_field.dart'; s=t.read_text()
s=s.replace('    this.inputConfig = inputConfig;', "    traceInitialEdit('semantics.enable');\n    this.inputConfig = inputConfig;")
s=s.replace('  void activate(SemanticTextField textField) {', "  void activate(SemanticTextField textField) {\n    traceInitialEdit('semantics.activate', {'node': textField.semanticsObject.id});")
s=s.replace('  void disable() {', "  void disable() {\n    traceInitialEdit('semantics.disable', {'enabled': isEnabled, 'listeners': subscriptions.length});")
s=s.replace('  void addEventHandlers() {', "  void addEventHandlers() {\n    traceInitialEdit('listeners.add');")
s=s.replace('        EnginePlatformDispatcher.instance.invokeOnSemanticsAction(', "        traceInitialEdit('DOM.focus.action', {'node': semanticsObject.id});\n        EnginePlatformDispatcher.instance.invokeOnSemanticsAction(")
t.write_text(s)
