import 'dart:convert';
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import '../../common/test_initialization.dart';
import 'text_field_test.dart' as existing;

const MethodCodec codec = JSONMethodCodec();
void main() => internalBootstrapBrowserTest(() => testMain);

void testMain() {
  setUpImplicitView();
  for (final initial in <String>['', 'Design studio']) {
    for (final emptyUpdate in <bool>[false, true]) {
      for (final characterize in <bool>[false, true]) {
        test(
          '${characterize ? "old-behavior" : "retention-contract"} initial="$initial" emptyUpdate=$emptyUpdate',
          () {
            runBoundary(initial, emptyUpdate, characterize: characterize);
          },
        );
      }
    }
  }
  test('activated-before-input control retains P then Pr', () {
    runBoundary('', false, activateFirst: true);
  });
}

void runBoundary(
  String initial,
  bool emptyUpdate, {
  bool characterize = false,
  bool activateFirst = false,
}) {
  EngineSemantics.debugResetSemantics();
  initialEditTrace.clear();
  initialEditClock.reset();
  final editing = HybridTextEditing();
  final strategy = SemanticsTextEditingStrategy.ensureInitialized(editing);
  editing.debugTextEditingStrategyOverride = strategy;
  EngineSemantics.instance.semanticsEnabled = true;
  final dispatcher = EnginePlatformDispatcher.instance;
  final saved = dispatcher.onPlatformMessage;
  final updates = <Map<String, dynamic>>[];
  dispatcher.onPlatformMessage =
      (
        String channel,
        ByteData? data,
        ui.PlatformMessageResponseCallback? reply,
      ) {
        if (channel == 'flutter/textinput' && data != null) {
          final call = codec.decodeMethodCall(data);
          traceInitialEdit('client.receive', {
            'method': call.method,
            'args': call.arguments,
          });
          if (call.method == 'TextInputClient.updateEditingState') {
            final args = call.arguments as List<dynamic>;
            expect(args[0], 42);
            updates.add(Map<String, dynamic>.from(args[1] as Map));
          }
        }
        reply?.call(null);
      };
  addTearDown(() {
    if (editing.isEditing) editing.stopEditing();
    dispatcher.onPlatformMessage = saved;
    EngineSemantics.instance.semanticsEnabled = false;
    domDocument.activeElement?.blur();
    print(
      'INITIAL_EDIT_TRACE ${jsonEncode({'initial': initial, 'emptyUpdate': emptyUpdate, 'characterize': characterize, 'activateFirst': activateFirst, 'trace': initialEditTrace})}',
    );
  });
  void send(String method, [dynamic args]) {
    traceInitialEdit('framework.send', {'method': method, 'args': args});
    existing.sendFrameworkMessage(
      codec.encodeMethodCall(MethodCall(method, args)),
      editing,
    );
  }

  Map<String, dynamic> state(String text) => <String, dynamic>{
    'text': text,
    'selectionBase': text.length,
    'selectionExtent': text.length,
    'composingBase': -1,
    'composingExtent': -1,
  };
  final node = existing.createTextFieldSemantics(value: initial);
  final role = node.semanticRole! as SemanticTextField;
  final input = role.editableElement as DomHTMLInputElement;
  expect(input.disabled, isFalse);
  input.focusWithoutScroll();
  expect(domDocument.activeElement, input);
  expect(strategy.isEnabled, isFalse);
  send('TextInput.setClient', <dynamic>[
    42,
    <String, dynamic>{
      'viewId': kImplicitViewId,
      'inputType': <String, dynamic>{'name': 'TextInputType.text'},
      'inputAction': 'TextInputAction.done',
      'textCapitalization': 'TextCapitalization.none',
    },
  ]);
  send('TextInput.setEditingState', state(initial));
  send('TextInput.show');
  void activate() {
    traceInitialEdit('test.releaseFocusedSemantics');
    final updated = existing.createTextFieldSemantics(
      value: emptyUpdate ? '' : initial,
      isFocused: true,
    );
    expect(
      (updated.semanticRole! as SemanticTextField).editableElement,
      same(input),
    );
  }

  if (activateFirst) activate();
  // Replace the selected label, as select-all followed by P would do.
  input.value = 'P';
  input.setSelectionRange(1, 1);
  traceInitialEdit('test.DOM.input', {
    'node': 0,
    'text': input.value,
    'enabled': strategy.isEnabled,
    'listeners': strategy.subscriptions.length,
  });
  input.dispatchEvent(createDomEvent('Event', 'input'));
  final before = updates.map((e) => e['text']).toList();
  traceInitialEdit('test.beforeActivation', {'delivered': before});
  if (characterize) expect(before, isEmpty);
  if (emptyUpdate) send('TextInput.setEditingState', state(''));
  if (!activateFirst) activate();
  final atActivation = input.value!;
  final selection = <int?>[
    input.selectionStart?.toInt(),
    input.selectionEnd?.toInt(),
  ];
  final pCount = updates.where((e) => e['text'] == 'P').length;
  final insertion = input.selectionStart!.toInt();
  input.value =
      atActivation.substring(0, insertion) +
      'r' +
      atActivation.substring(input.selectionEnd!.toInt());
  input.setSelectionRange(insertion + 1, insertion + 1);
  input.dispatchEvent(createDomEvent('Event', 'input'));
  // A repeated focused update and selection notification must not deliver twice.
  activate();
  domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
  expect(domDocument.activeElement, input);
  final actual = <String, dynamic>{
    'atActivation': atActivation,
    'selection': selection,
    'pCount': pCount,
    'afterR': input.value,
    'delivered': updates.map((e) => e['text']).toList(),
    'finalSelection': <int?>[
      input.selectionStart?.toInt(),
      input.selectionEnd?.toInt(),
    ],
  };
  traceInitialEdit('test.result', actual);
  final stale = emptyUpdate ? '' : initial;
  expect(
    actual,
    characterize
        ? <String, dynamic>{
            'atActivation': stale,
            'selection': <int>[stale.length, stale.length],
            'pCount': 0,
            'afterR': '${stale}r',
            'delivered': <String>['${stale}r'],
            'finalSelection': <int>[stale.length + 1, stale.length + 1],
          }
        : <String, dynamic>{
            'atActivation': 'P',
            'selection': <int>[1, 1],
            'pCount': 1,
            'afterR': 'Pr',
            'delivered': <String>['P', 'Pr'],
            'finalSelection': <int>[2, 2],
          },
  );
}
