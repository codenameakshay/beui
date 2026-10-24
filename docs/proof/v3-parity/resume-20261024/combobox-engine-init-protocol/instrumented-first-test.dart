import 'dart:convert';
import 'dart:typed_data';

import 'package:test/bootstrap/browser.dart';
import 'package:test/test.dart';
import 'package:ui/src/engine.dart';
import 'package:ui/ui.dart' as ui;

import '../../common/test_initialization.dart';
import 'text_field_test.dart' as existing;
import 'semantics_tester.dart';

const MethodCodec codec = JSONMethodCodec();
void main() => internalBootstrapBrowserTest(() => testMain);

void testMain() {
  setUpImplicitView();
  for (final initial in <String>['', 'Design studio']) {
    for (final emptyUpdate in <bool>[false, true]) {
      for (final characterize in <bool>[false]) {
        test(
          '${characterize ? "old-behavior" : "retention-contract"} initial="$initial" emptyUpdate=$emptyUpdate',
          () {
            runBoundary(initial, emptyUpdate, characterize: characterize);
          },
        );
      }
    }
  }
  for (final initial in <String>['', 'Design studio']) {
    test('authoritative empty write wins initial="$initial"', () {
      runBoundary(initial, true, ownerWins: true);
    });
  }
  for (final scenario in <String>['accept', 'programmatic', 'clear', 'replace', 'blur', 'dispose', 'switch', 'refocus', 'preclient', 'backward', 'delta', 'composition']) {
    test('prototype lifecycle $scenario', () => runBoundary('', false, scenario: scenario));
  }
  for (final scenario in <String>['accept', 'programmatic', 'reject']) {
    test('active owner $scenario', () => runBoundary('', false, activateFirst: true, scenario: scenario));
  }
  for (final scenario in <String>['delta', 'composition', 'same-id', 'detached', 'reentrant', 'ordered']) {
    test('r11 active lifecycle $scenario', () => runBoundary('', false, activateFirst: true, scenario: scenario));
  }
  test('activated-before-input control retains P then Pr', () {
    runBoundary('', false, activateFirst: true);
  });
}

void runBoundary(
  String initial,
  bool emptyUpdate, {
  bool characterize = false,
  bool ownerWins = false,
  String scenario = "",
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
  var expectedClient = 42;
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
            expect(args[0], expectedClient);
            updates.add(Map<String, dynamic>.from(args[1] as Map));
            if (scenario == 'reentrant' && updates.length == 1) {
              existing.sendFrameworkMessage(codec.encodeMethodCall(MethodCall('TextInput.setEditingState', <String, dynamic>{
                'text': '', 'selectionBase': 0, 'selectionExtent': 0,
                'composingBase': -1, 'composingExtent': -1,
              })), editing);
            }
          }
          if (call.method == 'TextInputClient.updateEditingStateWithDeltas') {
            final args = call.arguments as List<dynamic>;
            expect(args[0], expectedClient);
            final delta = (args[1] as Map)['deltas'][0] as Map;
            final old = delta['oldText'] as String;
            final start = delta['deltaStart'] as int;
            updates.add(<String, dynamic>{
              ...Map<String, dynamic>.from(delta),
              'text': start < 0 ? old : old.replaceRange(start, delta['deltaEnd'] as int, delta['deltaText'] as String),
            });
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
      'INITIAL_EDIT_TRACE ${jsonEncode({'initial': initial, 'emptyUpdate': emptyUpdate, 'characterize': characterize, 'activateFirst': activateFirst, 'ownerWins': ownerWins, 'scenario': scenario, 'trace': initialEditTrace})}',
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
  if (scenario == 'preclient') {
    input.value = 'P';
    input.setSelectionRange(1, 1);
    input.dispatchEvent(createDomEvent('Event', 'input'));
  }
  final config = <String, dynamic>{
      'viewId': kImplicitViewId,
      'inputType': <String, dynamic>{'name': 'TextInputType.text'},
      'inputAction': 'TextInputAction.done',
      'textCapitalization': 'TextCapitalization.none',
      'enableDeltaModel': scenario == 'delta',
  };
  send('TextInput.setClient', <dynamic>[
    42,
    config,
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
  if (scenario == 'same-id') {
    send('TextInput.setClient', <dynamic>[42, config]);
    // A new connection generation must revoke the old handlers before an
    // initialization commit for the replacement. Numeric identity is insufficient.
    input.value = 'ghost';
    input.dispatchEvent(createDomEvent('Event', 'input'));
    expect(updates, isEmpty, reason: 'old generation must not deliver to replacement');
    expect(strategy.isEnabled, isFalse);
    return;
  }
  if (scenario == 'detached') {
    role.dispose();
    input.value = 'ghost';
    input.dispatchEvent(createDomEvent('Event', 'input'));
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates, isEmpty);
    expect(strategy.isEnabled, isFalse);
    return;
  }
  if (scenario == 'delta') input.dispatchEvent(createDomInputEvent('beforeinput', <String, dynamic>{'data': 'P', 'inputType': 'insertText'}));
  // Replace the selected label, as select-all followed by P would do.
  input.value = 'P';
  input.setSelectionRange(1, 1);
  traceInitialEdit('test.DOM.input', {
    'node': 0,
    'text': input.value,
    'enabled': strategy.isEnabled,
    'listeners': strategy.subscriptions.length,
  });
  if (scenario != 'preclient') input.dispatchEvent(createDomEvent('Event', 'input'));
  final before = updates.map((e) => e['text']).toList();
  traceInitialEdit('test.beforeActivation', {'delivered': before});
  if (characterize) expect(before, isEmpty);
  if (scenario == 'reentrant') {
    expect(input.value, '', reason: 'explicit synchronous owner rejection wins');
    expect(updates.map((e) => e['text']).toList(), <String>['P']);
    input.value = 'r';
    input.setSelectionRange(1, 1);
    input.dispatchEvent(createDomEvent('Event', 'input'));
    activate();
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates.map((e) => e['text']).toList(), <String>['P', 'r']);
    return;
  }
  if (scenario == 'ordered') {
    for (final value in <String>['Pr', 'Pro']) {
      input.value = value;
      input.setSelectionRange(value.length, value.length);
      input.dispatchEvent(createDomEvent('Event', 'input'));
    }
    activate();
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates.map((e) => e['text']).toList(), <String>['P', 'Pr', 'Pro']);
    return;
  }
  if (scenario == 'accept') send('TextInput.setEditingState', state('P'));
  if (scenario == 'reject') send('TextInput.setEditingState', state(''));
  if (scenario == 'programmatic') send('TextInput.setEditingState', state('Owner'));
  if (scenario == 'clear' || scenario == 'replace') {
    send(scenario == 'clear' ? 'TextInput.clearClient' : 'TextInput.setClient', scenario == 'clear' ? null : <dynamic>[43, config]);
    if (scenario == 'clear') {
      input.value = 'ghost';
      input.dispatchEvent(createDomEvent('Event', 'input'));
      send('TextInput.setClient', <dynamic>[43, config]);
    }
    expectedClient = 43;
    send('TextInput.setEditingState', state('New'));
    send('TextInput.show');
  }
  if (scenario == 'refocus') {
    input.blur();
    input.focusWithoutScroll();
    activate();
    expect(updates, isEmpty);
    input.value = 'Fresh';
    input.setSelectionRange(5, 5);
    input.dispatchEvent(createDomEvent('Event', 'input'));
    activate();
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates.map((e) => e['text']).toList(), <String>['Fresh']);
    return;
  }
  if (scenario == 'switch') {
    final tester = SemanticsTester(existing.owner());
    final second = tester.updateNode(id: 1, flags: const ui.SemanticsFlags(isTextField: true, isEnabled: ui.Tristate.isTrue), rect: const ui.Rect.fromLTRB(0, 50, 100, 100));
    tester.updateNode(id: 0, flags: const ui.SemanticsFlags(isTextField: true, isEnabled: ui.Tristate.isTrue), children: <SemanticsNodeUpdate>[second], rect: const ui.Rect.fromLTRB(0, 0, 100, 50));
    tester.apply();
    final other = tester.getSemanticsObject(1).semanticRole! as SemanticTextField;
    final otherInput = other.editableElement as DomHTMLInputElement;
    otherInput.focusWithoutScroll();
    send('TextInput.setClient', <dynamic>[43, config]);
    expectedClient = 43;
    send('TextInput.setEditingState', state('Second'));
    send('TextInput.show');
    strategy.activate(other);
    expect(strategy.activeTextField, same(other));
    expect(otherInput.value, 'Second');
    expect(updates, isEmpty);
    input.value = 'ghost';
    input.dispatchEvent(createDomEvent('Event', 'input'));
    expect(updates, isEmpty);
    otherInput.value = 'Next';
    otherInput.setSelectionRange(4, 4);
    otherInput.dispatchEvent(createDomEvent('Event', 'input'));
    strategy.activate(other);
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates.map((e) => e['text']).toList(), <String>['Next']);
    return;
  }
  if (scenario == 'blur' || scenario == 'dispose') {
    if (scenario == 'blur') input.blur(); else role.dispose();
    expect(updates, isEmpty);
    expect(strategy.isEnabled, isFalse);
    return;
  }
  if (scenario == 'backward') {
    input.value = 'Word';
    input.setSelectionRange(1, 3, 'backward');
    input.dispatchEvent(createDomEvent('Event', 'input'));
  }
  if (scenario == 'composition') {
    input.dispatchEvent(createDomCompositionEvent('compositionstart', <String, dynamic>{'data': ''}));
    input.dispatchEvent(createDomCompositionEvent('compositionupdate', <String, dynamic>{'data': 'P'}));
    input.dispatchEvent(createDomEvent('Event', 'input'));
  }
  if (emptyUpdate) send('TextInput.setEditingState', state(''));
  if (!activateFirst) activate();
  if (scenario == 'backward') {
    expect(input.value, 'Word');
    expect(input.selectionDirection, 'backward');
    expect(updates.single['selectionBase'], 3);
    expect(updates.single['selectionExtent'], 1);
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates, hasLength(1));
    return;
  }
  if (scenario == 'composition') {
    expect(updates.single['composingBase'], 0);
    expect(updates.single['composingExtent'], 1);
    return;
  }
  if (scenario == 'preclient') {
    expect(input.value, 'P', reason: 'Desired pre-client retention remains an unresolved ownership contract');
    return;
  }
  if (scenario == 'accept' || scenario == 'reject' || scenario == 'programmatic' || scenario == 'clear' || scenario == 'replace') {
    expect(input.value, scenario == 'accept' ? 'P' : scenario == 'reject' ? '' : scenario == 'programmatic' ? 'Owner' : 'New');
    expect(updates.map((e) => e['text']).toList(), activateFirst ? <String>['P'] : <String>[]);
    input.value = 'Next';
    input.setSelectionRange(4, 4);
    input.dispatchEvent(createDomEvent('Event', 'input'));
    activate();
    domDocument.dispatchEvent(createDomEvent('Event', 'selectionchange'));
    expect(updates.map((e) => e['text']).toList(), activateFirst ? <String>['P', 'Next'] : <String>['Next']);
    return;
  }
  final atActivation = input.value!;
  final selection = <int?>[
    input.selectionStart?.toInt(),
    input.selectionEnd?.toInt(),
  ];
  final pCount = updates.where((e) => e['text'] == 'P').length;
  final insertion = input.selectionStart!.toInt();
  if (scenario == 'delta') input.dispatchEvent(createDomInputEvent('beforeinput', <String, dynamic>{'data': 'r', 'inputType': 'insertText'}));
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
    ownerWins
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
