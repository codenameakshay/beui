import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {Size size = const Size(1024, 800)}) {
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    ),
  );
}

Widget _scopeProbe(String name) => Builder(
  builder: (context) {
    final scope = BeuiAnimatedSidebarScope.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$name:${scope.expanded}:${scope.openMobile}:${scope.isMobile}',
          key: ValueKey('$name-state'),
        ),
        Text('$name-controlled:${scope.isExpandedControlled}'),
        TextButton(
          key: ValueKey('$name-toggle'),
          onPressed: scope.toggle,
          child: Text('$name toggle'),
        ),
        TextButton(
          key: ValueKey('$name-expand'),
          onPressed: () => scope.setExpanded(!scope.expanded),
          child: Text('$name expand'),
        ),
      ],
    );
  },
);

IconButton _triggerButton(WidgetTester tester) => tester.widget<IconButton>(
  find.descendant(
    of: find.byType(BeuiAnimatedSidebarTrigger),
    matching: find.byType(IconButton),
  ),
);

void main() {
  group('BeuiAnimatedSidebarProvider', () {
    for (final legacy in [false, true]) {
      testWidgets(
        'control handoff restores retained defaults in ${legacy ? 'legacy sidebar' : 'provider'}',
        (tester) async {
          var controlled = true;
          late StateSetter updateOwner;
          await tester.pumpWidget(
            _wrap(
              StatefulBuilder(
                builder: (context, setState) {
                  updateOwner = setState;
                  final child = _scopeProbe('retained');
                  return legacy
                      ? BeuiAnimatedSidebar(
                          groups: const [],
                          expanded: controlled ? true : null,
                          defaultExpanded: false,
                          openMobile: controlled ? false : null,
                          defaultOpenMobile: true,
                          child: child,
                        )
                      : BeuiAnimatedSidebarProvider(
                          expanded: controlled ? true : null,
                          defaultExpanded: false,
                          openMobile: controlled ? false : null,
                          defaultOpenMobile: true,
                          child: child,
                        );
                },
              ),
            ),
          );
          expect(find.text('retained:true:false:false'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('retained-expand')));
          await tester.pump();
          expect(find.text('retained:true:false:false'), findsOneWidget);
          updateOwner(() => controlled = false);
          await tester.pumpAndSettle();
          expect(find.text('retained:false:true:false'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('retained-toggle')));
          await tester.pumpAndSettle();
          expect(find.text('retained:true:true:false'), findsOneWidget);
        },
      );
    }

    testWidgets('scope owns provider-only state and defaults seed once', (
      tester,
    ) async {
      var defaultExpanded = true;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                BeuiAnimatedSidebarProvider(
                  defaultExpanded: defaultExpanded,
                  defaultOpenMobile: true,
                  child: _scopeProbe('provider'),
                ),
                TextButton(
                  key: const ValueKey('change-default'),
                  onPressed: () => setState(() => defaultExpanded = false),
                  child: const Text('change default'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('provider:true:true:false'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('change-default')));
      await tester.pump();
      expect(find.text('provider:true:true:false'), findsOneWidget);
    });

    testWidgets('controlled requests notify once and wait for parent handoff', (
      tester,
    ) async {
      var expanded = true;
      var openMobile = false;
      var expandedRequests = 0;
      var mobileRequests = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(
            Column(
              children: [
                BeuiAnimatedSidebarProvider(
                  expanded: expanded,
                  openMobile: openMobile,
                  onExpandedChange: (_) => expandedRequests++,
                  onOpenMobileChange: (_) => mobileRequests++,
                  child: _scopeProbe('controlled'),
                ),
                TextButton(
                  key: const ValueKey('accept-controlled-request'),
                  onPressed: () => setState(() => expanded = false),
                  child: const Text('accept'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('controlled-expand')));
      await tester.pump();
      expect(expandedRequests, 1);
      expect(find.text('controlled:true:false:false'), findsOneWidget);
      expect(find.text('controlled-controlled:true'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('controlled-toggle')));
      await tester.pump();
      expect(expandedRequests, 2);
      expect(mobileRequests, 0);
      expect(find.text('controlled:true:false:false'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('accept-controlled-request')));
      await tester.pump();
      expect(find.text('controlled:false:false:false'), findsOneWidget);
    });

    testWidgets('borrowed legacy sidebar uses provider values and callbacks', (
      tester,
    ) async {
      var requests = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebarProvider(
            defaultExpanded: true,
            onExpandedChange: (_) => requests++,
            child: BeuiAnimatedSidebar(
              groups: const [],
              defaultExpanded: false,
              defaultOpenMobile: true,
              child: Column(
                children: [
                  const BeuiAnimatedSidebarTrigger(),
                  Builder(
                    builder: (context) {
                      final scope = BeuiAnimatedSidebarScope.of(context);
                      return Text(
                        'borrowed:${scope.expanded}:${scope.openMobile}',
                      );
                    },
                  ),
                  Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('borrowed:true:false'), findsOneWidget);
      expect(_triggerButton(tester).isSelected, isTrue);
      await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(_triggerButton(tester).isSelected, isFalse);
    });

    testWidgets('nested providers resolve nearest scope and shortcut owner', (
      tester,
    ) async {
      var outerRequests = 0;
      var innerRequests = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebarProvider(
            onExpandedChange: (_) => outerRequests++,
            child: Column(
              children: [
                _scopeProbe('outer'),
                BeuiAnimatedSidebarProvider(
                  defaultExpanded: false,
                  onExpandedChange: (_) => innerRequests++,
                  child: Column(
                    children: [
                      _scopeProbe('inner'),
                      const TextField(key: ValueKey('inner-editor')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('outer:true:false:false'), findsOneWidget);
      expect(find.text('inner:false:false:false'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inner-toggle')));
      await tester.pump();
      expect(innerRequests, 1);
      expect(outerRequests, 0);
      expect(find.text('outer:true:false:false'), findsOneWidget);
      expect(find.text('inner:true:false:false'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inner-editor')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(innerRequests, 2);
      expect(outerRequests, 0);
    });

    testWidgets('disabled inner shortcut owner blocks the outer owner', (
      tester,
    ) async {
      var outerRequests = 0;
      var innerRequests = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebarProvider(
            onExpandedChange: (_) => outerRequests++,
            child: BeuiAnimatedSidebarProvider(
              enableKeyboardShortcut: false,
              onExpandedChange: (_) => innerRequests++,
              child: const TextField(key: ValueKey('disabled-inner-editor')),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('disabled-inner-editor')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(innerRequests, 0);
      expect(outerRequests, 0);
    });

    testWidgets('control handoff preserves an untouched true default', (
      tester,
    ) async {
      var controlled = true;
      var requests = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(
            Column(
              children: [
                BeuiAnimatedSidebarProvider(
                  expanded: controlled ? true : null,
                  onExpandedChange: (_) => requests++,
                  child: _scopeProbe('handoff'),
                ),
                TextButton(
                  key: const ValueKey('release-control'),
                  onPressed: () => setState(() => controlled = false),
                  child: const Text('release'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('handoff-expand')));
      await tester.pump();
      expect(requests, 1);
      expect(find.text('handoff:true:false:false'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('release-control')));
      await tester.pump();
      expect(find.text('handoff:true:false:false'), findsOneWidget);
      expect(find.text('handoff-controlled:false'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('handoff-toggle')));
      await tester.pump();
      expect(find.text('handoff:false:false:false'), findsOneWidget);
      expect(requests, 2);
    });

    testWidgets('controlled mobile requests wait for the owner update', (
      tester,
    ) async {
      var openMobile = false;
      var requests = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(
            Column(
              children: [
                BeuiAnimatedSidebarProvider(
                  openMobile: openMobile,
                  onOpenMobileChange: (_) => requests++,
                  child: _scopeProbe('mobile-controlled'),
                ),
                TextButton(
                  key: const ValueKey('accept-mobile-open'),
                  onPressed: () => setState(() => openMobile = true),
                  child: const Text('accept mobile'),
                ),
              ],
            ),
            size: const Size(390, 844),
          ),
        ),
      );

      expect(find.text('mobile-controlled:true:false:true'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mobile-controlled-toggle')));
      await tester.pump();
      expect(requests, 1);
      expect(find.text('mobile-controlled:true:false:true'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('accept-mobile-open')));
      await tester.pump();
      expect(find.text('mobile-controlled:true:true:true'), findsOneWidget);
    });

    testWidgets('legacy standalone sidebar retains its shortcut', (
      tester,
    ) async {
      var requests = 0;
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebar(
            groups: const [],
            onExpandedChange: (_) => requests++,
            child: const Column(
              children: [
                BeuiAnimatedSidebarTrigger(),
                Expanded(child: TextField()),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(_triggerButton(tester).isSelected, isFalse);
    });

    testWidgets('public scope constructor and lookups remain usable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebarScope(
            expanded: false,
            openMobile: true,
            isMobile: true,
            toggle: () {},
            setExpanded: (_) {},
            setOpenMobile: (_) {},
            child: Builder(
              builder: (context) {
                final scope = BeuiAnimatedSidebarScope.of(context);
                final maybeScope = BeuiAnimatedSidebarScope.maybeOf(context);
                return Text(
                  '${scope.expanded}:${scope.openMobile}:${scope.isMobile}:'
                  '${identical(scope, maybeScope)}:${scope.isExpandedControlled}',
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('false:true:true:true:false'), findsOneWidget);
    });

    testWidgets('breakpoint crosses at 767/768 without state callbacks', (
      tester,
    ) async {
      var size = const Size(767, 800);
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MediaQuery(
                data: MediaQueryData(size: size),
                child: Column(
                  children: [
                    BeuiAnimatedSidebarProvider(
                      onExpandedChange: (_) => requests++,
                      onOpenMobileChange: (_) => requests++,
                      child: _scopeProbe('resize'),
                    ),
                    TextButton(
                      key: const ValueKey('resize-screen'),
                      onPressed: () =>
                          setState(() => size = const Size(768, 800)),
                      child: const Text('resize'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('resize:true:false:true'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('resize-screen')));
      await tester.pump();
      expect(find.text('resize:true:false:false'), findsOneWidget);
      expect(requests, 0);
    });

    testWidgets('mobile-open intent survives viewport exit and re-entry', (
      tester,
    ) async {
      var size = const Size(767, 844);
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MediaQuery(
                data: MediaQueryData(size: size),
                child: Column(
                  children: [
                    TextButton(
                      key: const ValueKey('cross-breakpoint'),
                      onPressed: () => setState(
                        () => size = size.width == 767
                            ? const Size(768, 844)
                            : const Size(767, 844),
                      ),
                      child: const Text('cross'),
                    ),
                    Expanded(
                      child: BeuiAnimatedSidebarProvider(
                        defaultOpenMobile: true,
                        onOpenMobileChange: (_) => requests++,
                        child: Column(
                          children: [
                            const BeuiAnimatedSidebarTrigger(),
                            Builder(
                              builder: (context) {
                                final scope = BeuiAnimatedSidebarScope.of(
                                  context,
                                );
                                return Text(
                                  '${scope.openMobile}:${scope.isMobile}',
                                );
                              },
                            ),
                            Expanded(
                              child: BeuiAnimatedSidebar(
                                groups: const [],
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('true:true'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cross-breakpoint')));
      await tester.pumpAndSettle();
      expect(find.text('true:false'), findsOneWidget);
      expect(requests, 0);
      expect(
        FocusManager.instance.primaryFocus,
        _triggerButton(tester).focusNode,
      );
      await tester.tap(find.byKey(const ValueKey('cross-breakpoint')));
      await tester.pumpAndSettle();
      expect(find.text('true:true'), findsOneWidget);
      expect(requests, 0);
    });

    testWidgets('closed viewport crossing preserves external focus', (
      tester,
    ) async {
      var size = const Size(767, 844);
      late StateSetter resize;
      final externalFocus = FocusNode();
      addTearDown(externalFocus.dispose);
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            resize = setState;
            return _wrap(
              BeuiAnimatedSidebarProvider(
                child: BeuiAnimatedSidebar(
                  groups: const [],
                  child: Column(
                    children: [
                      const BeuiAnimatedSidebarTrigger(),
                      TextField(focusNode: externalFocus),
                    ],
                  ),
                ),
              ),
              size: size,
            );
          },
        ),
      );
      externalFocus.requestFocus();
      await tester.pump();
      expect(externalFocus.hasPrimaryFocus, isTrue);
      resize(() => size = const Size(768, 844));
      await tester.pumpAndSettle();
      expect(externalFocus.hasPrimaryFocus, isTrue);
    });

    testWidgets('borrowed panel uses the provider viewport mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BeuiAnimatedSidebarProvider(
            child: MediaQuery(
              data: const MediaQueryData(size: Size(390, 844)),
              child: BeuiAnimatedSidebar(
                groups: const [],
                child: _scopeProbe('borrowed-mode'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('borrowed-mode:true:false:false'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('borrowed-mode-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('borrowed-mode:false:false:false'), findsOneWidget);
    });

    testWidgets(
      'disposing an open borrowed panel does not dispose by request',
      (tester) async {
        var requests = 0;
        await tester.pumpWidget(
          _wrap(
            BeuiAnimatedSidebarProvider(
              defaultOpenMobile: true,
              onOpenMobileChange: (_) => requests++,
              child: BeuiAnimatedSidebar(
                groups: const [],
                child: const SizedBox.expand(),
              ),
            ),
            size: const Size(390, 844),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(requests, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mobile sheet gates exit focus and falls back after invoker removal',
      (tester) async {
        var showInvoker = true;
        final sheetActionFocus = FocusNode();
        addTearDown(sheetActionFocus.dispose);
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => _wrap(
              BeuiAnimatedSidebarProvider(
                child: Column(
                  children: [
                    if (showInvoker)
                      const BeuiAnimatedSidebarTrigger(
                        key: ValueKey('opening-trigger'),
                      ),
                    const BeuiAnimatedSidebarTrigger(
                      key: ValueKey('fallback-trigger'),
                    ),
                    TextButton(
                      key: const ValueKey('remove-invoker'),
                      onPressed: () => setState(() => showInvoker = false),
                      child: const Text('remove'),
                    ),
                    Builder(
                      builder: (context) => TextButton(
                        key: const ValueKey('close-mobile'),
                        onPressed: () => BeuiAnimatedSidebarScope.of(
                          context,
                        ).setOpenMobile(false),
                        child: const Text('close'),
                      ),
                    ),
                    Expanded(
                      child: BeuiAnimatedSidebar(
                        groups: const [],
                        header: TextButton(
                          key: const ValueKey('sheet-first-focus'),
                          focusNode: sheetActionFocus,
                          onPressed: () {},
                          child: const Text('sheet action'),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
              size: const Size(390, 844),
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('opening-trigger')));
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, sheetActionFocus);

        await tester.tap(find.byKey(const ValueKey('remove-invoker')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('close-mobile')));
        await tester.pump(const Duration(milliseconds: 1));
        final sheetActionFinder = find.byKey(
          const ValueKey('sheet-first-focus'),
        );
        expect(sheetActionFinder, findsOneWidget);
        final focusGate = tester.widget<Focus>(
          find
              .ancestor(of: sheetActionFinder, matching: find.byType(Focus))
              .first,
        );
        expect(focusGate.descendantsAreFocusable, isFalse);
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(
                      of: sheetActionFinder,
                      matching: find.byType(IgnorePointer),
                    )
                    .first,
              )
              .ignoring,
          isTrue,
        );
        await tester.pumpAndSettle();

        final fallback = tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(const ValueKey('fallback-trigger')),
            matching: find.byType(IconButton),
          ),
        );
        expect(FocusManager.instance.primaryFocus, fallback.focusNode);
      },
    );

    testWidgets(
      'mobile sheet traps forward and backward Tab at its boundaries',
      (tester) async {
        final firstFocus = FocusNode(debugLabel: 'first sheet action');
        final lastFocus = FocusNode(debugLabel: 'last sheet action');
        final outsideFocus = FocusNode(debugLabel: 'outside sheet');
        addTearDown(firstFocus.dispose);
        addTearDown(lastFocus.dispose);
        addTearDown(outsideFocus.dispose);
        await tester.pumpWidget(
          _wrap(
            BeuiAnimatedSidebarProvider(
              child: Column(
                children: [
                  const BeuiAnimatedSidebarTrigger(),
                  TextButton(
                    focusNode: outsideFocus,
                    onPressed: () {},
                    child: const Text('outside'),
                  ),
                  Expanded(
                    child: BeuiAnimatedSidebar(
                      groups: const [],
                      header: TextButton(
                        focusNode: firstFocus,
                        onPressed: () {},
                        child: const Text('first'),
                      ),
                      footer: TextButton(
                        focusNode: lastFocus,
                        onPressed: () {},
                        child: const Text('last'),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
            size: const Size(390, 844),
          ),
        );
        await tester.tap(find.byType(BeuiAnimatedSidebarTrigger));
        await tester.pumpAndSettle();
        expect(firstFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<IconButton>()
              ?.tooltip,
          'Close sidebar',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(lastFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(firstFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(lastFocus.hasPrimaryFocus, isTrue);
        expect(outsideFocus.hasFocus, isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(outsideFocus.hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('none projection does not overwrite raw provider state', (
      tester,
    ) async {
      var collapsible = BeuiAnimatedSidebarCollapsible.none;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => BeuiAnimatedSidebarProvider(
              defaultExpanded: true,
              child: Column(
                children: [
                  _scopeProbe('owner'),
                  Expanded(
                    child: BeuiAnimatedSidebar(
                      groups: const [],
                      collapsible: collapsible,
                      child: Builder(
                        builder: (context) {
                          final scope = BeuiAnimatedSidebarScope.of(context);
                          return Column(
                            children: [
                              const BeuiAnimatedSidebarTrigger(),
                              Text('panel:${scope.expanded}'),
                              TextButton(
                                key: const ValueKey('set-raw-false'),
                                onPressed: () => scope.setExpanded(false),
                                child: const Text('set false'),
                              ),
                              TextButton(
                                key: const ValueKey('switch-icon'),
                                onPressed: () => setState(
                                  () => collapsible =
                                      BeuiAnimatedSidebarCollapsible.icon,
                                ),
                                child: const Text('icon'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('owner:true:false:false'), findsOneWidget);
      expect(find.text('panel:true'), findsOneWidget);
      expect(_triggerButton(tester).isSelected, isTrue);
      await tester.tap(find.byKey(const ValueKey('set-raw-false')));
      await tester.pump();
      expect(find.text('owner:false:false:false'), findsOneWidget);
      expect(find.text('panel:true'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('switch-icon')));
      await tester.pumpAndSettle();
      expect(find.text('owner:false:false:false'), findsOneWidget);
      expect(_triggerButton(tester).isSelected, isFalse);
    });
  });
}
