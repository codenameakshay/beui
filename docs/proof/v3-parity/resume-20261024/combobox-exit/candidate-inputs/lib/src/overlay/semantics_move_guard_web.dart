import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('undefined')
external JSAny? get _undefined;

@JS('globalThis')
external JSObject get _global;
@JS('Node.prototype.insertBefore')
external JSFunction get _insertBefore;
@JS('Node.prototype.insertBefore')
external set _insertBefore(JSFunction value);
@JS('Element.prototype.append')
external JSFunction get _append;
@JS('Element.prototype.append')
external set _append(JSFunction value);
@JS('Reflect.apply')
external JSAny? _apply(
  JSFunction target,
  JSAny? receiver,
  JSArray<JSAny?> args,
);

@JS('Proxy')
extension type _FunctionProxy._(JSFunction _) implements JSFunction {
  external factory _FunctionProxy(JSFunction target, _Handler handler);
}
@JS()
extension type _Handler._(JSObject _) implements JSObject {
  external factory _Handler({JSFunction apply});
}
@JS('Element')
extension type _Element._(JSObject _) implements JSObject {
  external String get tagName;
  external bool get isConnected;
  external _Element? get parentElement;
  external JSObject? get nextSibling;
  external _NodeList get childNodes;
  external _Document getRootNode();
  external bool contains(JSObject? other);
  external _Element? closest(String selector);
  external String? getAttribute(String name);
  external JSArray<JSString> getAttributeNames();
}
extension type _NodeList._(JSObject _) implements JSObject {
  external int get length;
  external JSObject? item(int index);
}
extension type _Document._(JSObject _) implements JSObject {
  external _Element? get activeElement;
}

bool _same(JSAny? a, JSAny? b) => a == b;

bool _ownedTooltip(JSAny? node) {
  if (node == null || !node.isA<_Element>()) return false;
  final element = node as _Element;
  if (element.tagName != 'FLT-SEMANTICS') return false;
  final id = element.getAttribute('flt-semantics-identifier');
  if (id != null && id.startsWith('beui-tooltip-')) return true;
  // Only transparent, single-child semantics wrappers may own the marker.
  // An app subtree containing a tooltip alongside other content is not owned.
  return element.getAttributeNames().toDart.every(
        (name) => name.toDart == 'id' || name.toDart == 'style',
      ) &&
      element.childNodes.length == 1 &&
      _ownedTooltip(element.childNodes.item(0));
}

bool _rotate(
  JSFunction insert,
  JSAny? receiver,
  JSAny? moving,
  JSAny? reference,
) {
  if (receiver == null ||
      moving == null ||
      !receiver.isA<_Element>() ||
      !moving.isA<_Element>()) {
    return false;
  }
  final parent = receiver as _Element;
  final node = moving as _Element;
  if (parent.tagName != 'FLT-SEMANTICS' ||
      node.tagName != 'FLT-SEMANTICS' ||
      !parent.isConnected ||
      !node.isConnected ||
      !_same(node.parentElement, parent) ||
      parent.closest('flutter-view') == null) {
    return false;
  }
  final active = parent.getRootNode().activeElement;
  if (active == null || !node.contains(active)) return false;
  final children = <JSObject>[];
  for (var i = 0; i < parent.childNodes.length; i++) {
    children.add(parent.childNodes.item(i)!);
  }
  final from = children.indexWhere((child) => _same(child, node));
  final to = reference == null
      ? children.length
      : children.indexWhere((child) => _same(child, reference));
  if (from < 0 || to < 0) return false;
  if (from == to || to == from + 1) return false;
  final siblings = to < from
      ? children.sublist(to, from)
      : children.sublist(from + 1, to);
  if (!siblings.every(_ownedTooltip)) return false;
  final anchor = to < from ? node.nextSibling : node;
  for (final sibling in siblings) {
    _apply(insert, parent, <JSAny?>[sibling, anchor].toJS);
  }
  return true;
}

/// Flutter may reorder the focused app semantics ancestor around exiting
/// tooltips. Move only owned tooltip siblings to obtain the same order without
/// detaching native focus. No focus restoration or asynchronous work is used.
void installTooltipSemanticsMoveGuard() {
  const key = '__beuiTooltipSemanticsMoveGuardV1';
  if (_global.getProperty<JSAny?>(key.toJS) != null) return;
  final insert = _insertBefore;
  final append = _append;
  _insertBefore = _FunctionProxy(
    insert,
    _Handler(
      apply: (JSFunction target, JSAny? receiver, JSArray<JSAny?> arguments) {
        final args = arguments.toDart;
        if (args.length >= 2 && _rotate(insert, receiver, args[0], args[1])) {
          return args[0];
        }
        return _apply(target, receiver, arguments);
      }.toJS,
    ),
  );
  _append = _FunctionProxy(
    append,
    _Handler(
      apply: (JSFunction target, JSAny? receiver, JSArray<JSAny?> arguments) {
        final args = arguments.toDart;
        if (args.length == 1 && _rotate(insert, receiver, args[0], null)) {
          return _undefined;
        }
        return _apply(target, receiver, arguments);
      }.toJS,
    ),
  );
  // Keep the narrowly gated wrapper through final portal disposal. Restoring
  // prototypes here could overwrite another library's later wrapper.
  _global.setProperty(key.toJS, true.toJS);
}
