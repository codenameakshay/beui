import 'dart:ui' as ui;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: child),
  ),
);

const _initialOptions = <BeuiSelectOption>[
  BeuiSelectOption(value: 'alpha', label: 'Alpha'),
  BeuiSelectOption(value: 'beta', label: 'Beta'),
  BeuiSelectOption(value: 'gamma', label: 'Gamma'),
];

void main() {
  group('BeuiSelect source behavior', () {
    testWidgets('semantic trigger tap opens and closes exactly once', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final changes = <bool>[];
        await tester.pumpWidget(
          _app(BeuiSelect(options: _initialOptions, onOpenChange: changes.add)),
        );
        var trigger = tester.getSemantics(find.bySemanticsLabel('Select'));
        expect(
          trigger.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        trigger.owner!.performAction(trigger.id, ui.SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(changes, [true]);
        expect(find.text('Alpha'), findsOneWidget);
        trigger = tester.getSemantics(find.bySemanticsLabel('Select'));
        trigger.owner!.performAction(trigger.id, ui.SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(changes, [true, false]);
        expect(find.text('Alpha'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('disabled semantic trigger exposes no tap action', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final changes = <bool>[];
        await tester.pumpWidget(
          _app(
            BeuiSelect(
              options: _initialOptions,
              enabled: false,
              onOpenChange: changes.add,
            ),
          ),
        );
        final trigger = tester.getSemantics(find.bySemanticsLabel('Select'));
        expect(
          trigger.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        trigger.owner!.performAction(trigger.id, ui.SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(changes, isEmpty);
        expect(find.text('Alpha'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      'semantic option tap commits once and disabled row cannot activate',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final changes = <bool>[];
          final commits = <String>[];
          await tester.pumpWidget(
            _app(
              BeuiSelect(
                options: const [
                  BeuiSelectOption(
                    value: 'alpha',
                    label: 'Alpha',
                    labelWidget: Text('Decorative alpha'),
                  ),
                  BeuiSelectOption(
                    value: 'blocked',
                    label: 'Blocked',
                    enabled: false,
                  ),
                ],
                defaultOpen: true,
                onChanged: commits.add,
                onOpenChange: changes.add,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final blocked = tester.getSemantics(find.bySemanticsLabel('Blocked'));
          expect(
            blocked.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isFalse,
          );
          blocked.owner!.performAction(blocked.id, ui.SemanticsAction.tap);
          await tester.pump();
          expect(commits, isEmpty);
          expect(changes, isEmpty);
          final alpha = tester.getSemantics(find.bySemanticsLabel('Alpha'));
          expect(
            alpha.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
          alpha.owner!.performAction(alpha.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(commits, ['alpha']);
          expect(changes, [false]);
          expect(find.text('Blocked'), findsNothing);
          final selected = tester.getSemantics(find.bySemanticsLabel('Alpha'));
          expect(
            selected.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isTrue,
          );
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets(
      'Space release selects the genuinely focused enabled option once',
      (tester) async {
        final changes = <bool>[];
        final commits = <String>[];
        await tester.pumpWidget(
          _app(
            BeuiSelect(
              options: const [
                BeuiSelectOption(
                  value: 'blocked',
                  label: 'Blocked',
                  enabled: false,
                ),
                BeuiSelectOption(value: 'alpha', label: 'Alpha'),
              ],
              onChanged: commits.add,
              onOpenChange: changes.add,
            ),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        final focus = tester
            .widgetList<Focus>(find.byType(Focus))
            .singleWhere(
              (widget) =>
                  widget.focusNode?.debugLabel == 'beui_select_option_alpha',
            )
            .focusNode!;
        expect(focus.hasPrimaryFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(commits, isEmpty);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(commits, ['alpha']);
        expect(changes, [true, false]);
        expect(find.text('Blocked'), findsNothing);
      },
    );

    testWidgets('opening with Space does not commit on its release', (
      tester,
    ) async {
      final commits = <String>[];
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiSelect(
            options: _initialOptions,
            onChanged: commits.add,
            onOpenChange: changes.add,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      expect(changes, [true]);
      expect(find.text('Alpha'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(commits, ['alpha']);
      expect(changes, [true, false]);
    });

    testWidgets('Space cannot activate disabled options', (tester) async {
      final commits = <String>[];
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiSelect(
            options: const [
              BeuiSelectOption(
                value: 'blocked',
                label: 'Blocked',
                enabled: false,
              ),
            ],
            onChanged: commits.add,
            onOpenChange: changes.add,
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(commits, isEmpty);
      expect(changes, [true]);
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets(
      'settled open panel paints its shadow outside the reveal bounds',
      (tester) async {
        final previousDisableShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          const capture = ValueKey('select-shadow-capture');
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: ThemeData.light().copyWith(
                  extensions: [BeuiColors.light()],
                ),
                home: const Scaffold(
                  backgroundColor: Colors.white,
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: SizedBox(
                        width: 240,
                        child: BeuiSelect(
                          options: _initialOptions,
                          defaultOpen: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final panel = tester.getRect(
            find
                .ancestor(
                  of: find.text('Alpha'),
                  matching: find.byType(ClipRect),
                )
                .first,
          );
          final point = Offset(panel.center.dx, panel.bottom + 8);
          final pixel = (await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(capture))
                .toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final index =
                  (point.dy.floor() * image.width + point.dx.floor()) * 4;
              return List.generate(
                4,
                (channel) => bytes.getUint8(index + channel),
              );
            } finally {
              image.dispose();
            }
          }))!;
          // Black alpha 26 with sigma 14.36, sampled 3.5px inside its shifted
          // bottom edge, composites to about 239 over white.
          for (final channel in pixel.take(3)) {
            expect(channel, closeTo(239, 2));
          }
          expect(pixel[3], 255);
        } finally {
          debugDisableShadows = previousDisableShadows;
        }
      },
    );

    testWidgets('controlled closed state requests opening without opening', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiSelect(
            options: _initialOptions,
            open: false,
            onOpenChange: changes.add,
          ),
        ),
      );

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(changes, [true]);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('controlled owner can open and close with one callback each', (
      tester,
    ) async {
      var open = false;
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => BeuiSelect(
              options: _initialOptions,
              open: open,
              onOpenChange: (next) {
                changes.add(next);
                setState(() => open = next);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(changes, [true]);
      expect(find.text('Alpha'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, [true, false]);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('controlled open does not close until owner updates', (
      tester,
    ) async {
      final changes = <bool>[];
      await tester.pumpWidget(
        _app(
          BeuiSelect(
            options: _initialOptions,
            open: true,
            onOpenChange: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(find.text('Alpha'), findsOneWidget);
      await tester.pumpWidget(
        _app(const BeuiSelect(options: _initialOptions, open: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('controlled-to-uncontrolled handoff resumes default state', (
      tester,
    ) async {
      bool? open = true;
      late StateSetter updateOpen;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              updateOpen = setState;
              return BeuiSelect(
                options: _initialOptions,
                open: open,
                defaultOpen: false,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      updateOpen(() => open = null);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('defaultOpen shows options on first build', (tester) async {
      await tester.pumpWidget(
        _app(BeuiSelect(options: _initialOptions, defaultOpen: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    for (final controlled in [false, true]) {
      testWidgets(
        'initial ${controlled ? 'controlled open' : 'defaultOpen'} flips above a bottom trigger without stealing focus',
        (tester) async {
          final externalFocus = FocusNode();
          addTearDown(externalFocus.dispose);
          externalFocus.requestFocus();
          await tester.pumpWidget(
            _app(
              Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    width: 200,
                    child: TextField(focusNode: externalFocus),
                  ),
                  Positioned(
                    left: 80,
                    bottom: 16,
                    width: 200,
                    child: BeuiSelect(
                      options: _initialOptions,
                      open: controlled ? true : null,
                      defaultOpen: !controlled,
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          final trigger = tester.getRect(find.byType(BeuiSelect));
          final panel = tester.getRect(
            find
                .ancestor(
                  of: find.text('Alpha'),
                  matching: find.byType(ClipRect),
                )
                .first,
          );
          expect(trigger.bottom, 584);
          expect(panel.bottom, closeTo(trigger.top - 8, 0.01));
          expect(panel.top, greaterThanOrEqualTo(0));
          expect(externalFocus.hasPrimaryFocus, isTrue);
        },
      );
    }

    testWidgets('ArrowUp opens; Home and End choose enabled endpoints', (
      tester,
    ) async {
      final commits = <String>[];
      const endpointOptions = [
        BeuiSelectOption(value: 'alpha', label: 'Alpha'),
        BeuiSelectOption(value: 'disabled', label: 'Disabled', enabled: false),
        BeuiSelectOption(value: 'omega', label: 'Omega'),
      ];
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BeuiSelect(options: endpointOptions, onChanged: commits.add),
              const TextField(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_trigger',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_option_alpha',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, ['alpha']);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, ['alpha', 'omega']);
    });

    testWidgets('prefix typeahead selects matching enabled option', (
      tester,
    ) async {
      final commits = <String>[];
      await tester.pumpWidget(
        _app(BeuiSelect(options: _initialOptions, onChanged: commits.add)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(commits, ['gamma']);
    });

    testWidgets(
      'typeahead cycles duplicate initials, builds prefixes, expires',
      (tester) async {
        final commits = <String>[];
        const options = [
          BeuiSelectOption(value: 'alpha', label: 'Alpha'),
          BeuiSelectOption(value: 'alpine', label: 'Alpine'),
          BeuiSelectOption(value: 'beta', label: 'Beta'),
        ];
        await tester.pumpWidget(
          _app(BeuiSelect(options: options, onChanged: commits.add)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'beui_select_option_alpine',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'beui_select_option_alpine',
        );

        await tester.pump(const Duration(milliseconds: 500));
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'beui_select_option_alpha',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(commits, ['alpha']);
      },
    );

    testWidgets('repeated letters retain the source exact-prefix behavior', (
      tester,
    ) async {
      final commits = <String>[];
      const options = [
        BeuiSelectOption(value: 'beta', label: 'Beta'),
        BeuiSelectOption(value: 'bravo', label: 'Bravo'),
        BeuiSelectOption(value: 'bison', label: 'Bison'),
      ];
      await tester.pumpWidget(
        _app(BeuiSelect(options: options, onChanged: commits.add)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_option_bravo',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_option_bravo',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, ['bravo']);
    });

    testWidgets('active option identity is invalidated by replacement', (
      tester,
    ) async {
      final commits = <String>[];
      Widget select(List<BeuiSelectOption> options) => _app(
        BeuiSelect(options: options, value: 'gamma', onChanged: commits.add),
      );

      await tester.pumpWidget(select(_initialOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gamma'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        select(const [
          BeuiSelectOption(value: 'new-a', label: 'New A'),
          BeuiSelectOption(value: 'new-b', label: 'New B'),
          BeuiSelectOption(value: 'new-c', label: 'New C'),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(commits, ['new-a']);
    });

    testWidgets('active option identity survives a reordered option list', (
      tester,
    ) async {
      final commits = <String>[];
      Widget buildSelect(List<BeuiSelectOption> options) =>
          _app(BeuiSelect(options: options, onChanged: commits.add));
      await tester.pumpWidget(buildSelect(_initialOptions));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_option_beta',
      );
      await tester.pumpWidget(
        buildSelect(const [
          BeuiSelectOption(value: 'gamma', label: 'Gamma'),
          BeuiSelectOption(value: 'beta', label: 'Beta'),
          BeuiSelectOption(value: 'alpha', label: 'Alpha'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_option_beta',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, ['beta']);
    });

    testWidgets('rich display label retains string semantics and typeahead', (
      tester,
    ) async {
      final commits = <String>[];
      const options = [
        BeuiSelectOption(
          value: 'gpt',
          label: 'GPT 6 Luna',
          labelWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(Icons.auto_awesome), Text('Luna model')],
          ),
        ),
      ];
      await tester.pumpWidget(
        _app(BeuiSelect(options: options, onChanged: commits.add)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('Luna model'), findsOneWidget);
      expect(find.bySemanticsLabel('GPT 6 Luna'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, ['gpt']);
      expect(find.text('Luna model'), findsOneWidget);
    });

    testWidgets('Tab closes without consuming focus traversal', (tester) async {
      final fieldFocus = FocusNode();
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BeuiSelect(options: _initialOptions),
              TextField(
                key: const ValueKey('after-select'),
                focusNode: fieldFocus,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsNothing);
      expect(fieldFocus.hasPrimaryFocus, isTrue);
      fieldFocus.dispose();
    });

    testWidgets('Shift+Tab closes and advances backward', (tester) async {
      final beforeFocus = FocusNode();
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(focusNode: beforeFocus),
              const BeuiSelect(options: _initialOptions),
              const TextField(),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsNothing);
      expect(beforeFocus.hasPrimaryFocus, isTrue);
      beforeFocus.dispose();
    });

    testWidgets('Escape closes and restores trigger focus', (tester) async {
      await tester.pumpWidget(_app(BeuiSelect(options: _initialOptions)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Alpha'), findsNothing);
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'beui_select_trigger',
      );
    });

    testWidgets(
      'defaultOpen preserves external focus on mount and focuses on reopen',
      (tester) async {
        final externalFocus = FocusNode();
        externalFocus.requestFocus();
        await tester.pumpWidget(
          _app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(focusNode: externalFocus),
                const BeuiSelect(options: _initialOptions, defaultOpen: true),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(externalFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Alpha'), findsNothing);
        expect(externalFocus.hasPrimaryFocus, isTrue);
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          'beui_select_option_alpha',
        );
        externalFocus.dispose();
      },
    );

    testWidgets('reduced-motion update snaps geometry and removes row motion', (
      tester,
    ) async {
      var reduce = false;
      late StateSetter updateReduce;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              updateReduce = setState;
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduce),
                child: const BeuiSelect(options: _initialOptions),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      updateReduce(() => reduce = true);
      await tester.pump(Duration.zero);

      final transforms = find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Transform))
          .evaluate()
          .map((element) => element.widget as Transform)
          .toList();
      expect(transforms, hasLength(1));
      expect(transforms.single.transform.getTranslation().y, 8);
      expect(
        find.byKey(const ValueKey('beui-select-row-reveal-alpha')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 30));
      final settledTransforms = find
          .ancestor(of: find.text('Alpha'), matching: find.byType(Transform))
          .evaluate()
          .map((element) => element.widget as Transform)
          .toList();
      expect(settledTransforms.single.transform.getTranslation().y, 8);
    });

    testWidgets('rapid reopen and disposal during motion are safe', (
      tester,
    ) async {
      var open = false;
      late StateSetter updateOpen;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              updateOpen = setState;
              return BeuiSelect(options: _initialOptions, open: open);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      updateOpen(() => open = true);
      await tester.pump(const Duration(milliseconds: 35));
      updateOpen(() => open = false);
      await tester.pump(const Duration(milliseconds: 35));
      updateOpen(() => open = true);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      updateOpen(() => open = false);
      await tester.pump(const Duration(milliseconds: 35));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
