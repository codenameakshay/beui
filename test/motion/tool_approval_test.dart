import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  String tool = 'terminal.run',
  String title = 'Allow this tool to run?',
  String? description,
  List<BeuiToolApprovalParameter> parameters = const [],
  BeuiToolApprovalStatus status = BeuiToolApprovalStatus.pending,
  BeuiToolApprovalSeverity severity = BeuiToolApprovalSeverity.normal,
  BeuiToolApprovalGrant? grant,
  bool? open,
  bool? defaultOpen = false,
  bool? allowAlways,
  ValueChanged<bool>? onOpenChange,
  VoidCallback? onApprove,
  VoidCallback? onAlwaysAllow,
  VoidCallback? onDeny,
  VoidCallback? onRevoke,
  // A pending card with no handlers now trips a debug assert (A5), so the
  // harness supplies no-ops by default. Tests that need the real null pass
  // `defaultHandlers: false`.
  bool defaultHandlers = true,
  bool reduce = false,
  bool dark = false,
  double width = 400,
}) {
  Widget body = Center(
    child: SizedBox(
      width: width,
      child: BeuiToolApproval(
        tool: tool,
        title: title,
        description: description,
        parameters: parameters,
        status: status,
        severity: severity,
        grant: grant,
        open: open,
        defaultOpen: defaultOpen,
        allowAlways: allowAlways,
        onOpenChange: onOpenChange,
        onApprove: defaultHandlers ? (onApprove ?? () {}) : onApprove,
        onAlwaysAllow: onAlwaysAllow,
        onDeny: defaultHandlers ? (onDeny ?? () {}) : onDeny,
        onRevoke: onRevoke,
      ),
    ),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: BeuiTextTheme.trackingNormal(
      dark
          ? ThemeData.dark().copyWith(extensions: [BeuiColors.dark()])
          : ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

const _sampleParams = <BeuiToolApprovalParameter>[
  BeuiToolApprovalParameter(
    id: 'command',
    label: 'Command',
    value: BeuiToolApprovalCode(code: 'bun test'),
  ),
  BeuiToolApprovalParameter(
    id: 'directory',
    label: 'Directory',
    value: 'ui-components',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BeuiToolApproval', () {
    testWidgets('renders title, tool, status badge, and description', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Allow this tool to run?',
          tool: 'terminal.run',
          description: 'The agent wants to run tests.',
          status: BeuiToolApprovalStatus.pending,
        ),
      );
      await tester.pump();

      expect(find.text('Allow this tool to run?'), findsOneWidget);
      expect(find.text('terminal.run'), findsOneWidget);
      expect(find.text('Approval required'), findsOneWidget);
      expect(find.text('The agent wants to run tests.'), findsOneWidget);
    });

    testWidgets('status copy maps each lifecycle value', (tester) async {
      for (final entry in {
        BeuiToolApprovalStatus.pending: 'Approval required',
        BeuiToolApprovalStatus.approving: 'Approving',
        BeuiToolApprovalStatus.approved: 'Approved',
        BeuiToolApprovalStatus.denied: 'Denied',
        BeuiToolApprovalStatus.running: 'Running',
        BeuiToolApprovalStatus.complete: 'Completed',
        BeuiToolApprovalStatus.error: 'Failed',
      }.entries) {
        await tester.pumpWidget(_host(status: entry.key));
        // Busy states spin forever — pump once is enough for labels.
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
      }
    });

    testWidgets('pending shows Allow once / Always allow / Deny actions', (
      tester,
    ) async {
      var approved = false;
      var always = false;
      var denied = false;

      await tester.pumpWidget(
        _host(
          onApprove: () => approved = true,
          onAlwaysAllow: () => always = true,
          onDeny: () => denied = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Always allow'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);

      await tester.tap(find.text('Allow once'));
      await tester.pump();
      expect(approved, isTrue);

      await tester.tap(find.text('Always allow'));
      await tester.pump();
      expect(always, isTrue);

      await tester.tap(find.text('Deny'));
      await tester.pump();
      expect(denied, isTrue);
    });

    testWidgets('Always allow is hidden when onAlwaysAllow is null', (
      tester,
    ) async {
      await tester.pumpWidget(_host(onApprove: () {}, onDeny: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Always allow'), findsNothing);
      expect(find.text('Deny'), findsOneWidget);
    });

    // A5. The old behaviour was to render a live-looking button that silently
    // did nothing — codified by the test this replaces.
    testWidgets('a null handler renders a disabled action, not an inert one', (
      tester,
    ) async {
      await tester.pumpWidget(_host(onDeny: () {}, defaultHandlers: false));
      await tester.pumpAndSettle();

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('Always allow'), findsNothing);

      // Disabled: the button reports itself as such rather than accepting a
      // tap and dropping it on the floor.
      final allow = tester.widget<BeuiButton>(
        find.ancestor(
          of: find.text('Allow once'),
          matching: find.byType(BeuiButton),
        ),
      );
      expect(allow.onPressed, isNull);

      final deny = tester.widget<BeuiButton>(
        find.ancestor(of: find.text('Deny'), matching: find.byType(BeuiButton)),
      );
      expect(deny.onPressed, isNotNull);
    });

    testWidgets('a pending card with no handlers at all asserts in debug', (
      tester,
    ) async {
      await tester.pumpWidget(_host(defaultHandlers: false));
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('non-pending status hides action row', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approved,
          onApprove: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Allow once'), findsNothing);
      expect(find.text('Deny'), findsNothing);
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('View details toggles parameter disclosure (uncontrolled)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(defaultOpen: false, parameters: _sampleParams),
      );
      await tester.pumpAndSettle();

      expect(find.text('View details'), findsOneWidget);
      expect(find.text('Directory'), findsNothing);
      expect(find.text('ui-components'), findsNothing);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Directory'), findsOneWidget);
      expect(find.text('ui-components'), findsOneWidget);
      expect(find.textContaining('bun test'), findsOneWidget);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('Directory'), findsNothing);
    });

    testWidgets('controlled open respects prop and notifies onOpenChange', (
      tester,
    ) async {
      var open = true;
      final events = <bool>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              open: open,
              parameters: _sampleParams,
              onOpenChange: (v) {
                events.add(v);
                setState(() => open = v);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ui-components'), findsOneWidget);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(events, [false]);
      expect(find.text('ui-components'), findsNothing);
    });

    testWidgets('leaving pending collapses details', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.pending,
          defaultOpen: true,
          parameters: _sampleParams,
          onApprove: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ui-components'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approving,
          defaultOpen: true,
          parameters: _sampleParams,
        ),
      );
      // Approving spins — settle with pumps, not pumpAndSettle forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ui-components'), findsNothing);
      expect(find.text('Approving'), findsOneWidget);
    });

    testWidgets('BeuiToolApprovalCode renders code text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: const Scaffold(
            body: Center(
              child: BeuiToolApprovalCode(
                code: 'echo hello',
                language: BeuiCodeLanguage.bash,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('echo hello'), findsOneWidget);
    });

    testWidgets('reduced motion still renders and toggles', (tester) async {
      await tester.pumpWidget(
        _host(
          reduce: true,
          defaultOpen: false,
          parameters: _sampleParams,
          onApprove: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approval required'), findsOneWidget);
      expect(find.text('Allow once'), findsOneWidget);

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      expect(find.text('ui-components'), findsOneWidget);
    });

    testWidgets('the action row is left-aligned, not centred', (tester) async {
      await tester.pumpWidget(
        _host(onApprove: () {}, onAlwaysAllow: () {}, onDeny: () {}),
      );
      await tester.pumpAndSettle();

      // The source's action row is `flex … px-4 py-3` with no `justify-*`, so
      // it is full-width and flex-start. The reveal's `Align` loosens, so
      // without an explicit full-width box the row shrink-wrapped to its
      // buttons and `topCenter` centred them.
      final card = tester.getRect(find.byType(BeuiToolApproval));
      final first = tester.getRect(find.text('Allow once'));

      expect(first.left - card.left, lessThan(40));
    });

    // ---------------------------------------------------------------------
    // A1 — the command is visible at the moment of approval
    // ---------------------------------------------------------------------

    testWidgets('details open by default when there are parameters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(defaultOpen: null, parameters: _sampleParams),
      );
      await tester.pumpAndSettle();

      // Being asked to allow `terminal.run` with the command folded away is
      // not consent. `defaultOpen: null` resolves to parameters.isNotEmpty.
      expect(find.text('ui-components'), findsOneWidget);
      expect(find.textContaining('bun test'), findsOneWidget);
    });

    testWidgets('a parameterless approval still starts collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(_host(defaultOpen: null));
      await tester.pumpAndSettle();

      // Nothing behind the chevron means no chevron at all.
      expect(find.text('View details'), findsNothing);
    });

    testWidgets('an explicit defaultOpen:false still wins', (tester) async {
      await tester.pumpWidget(
        _host(defaultOpen: false, parameters: _sampleParams),
      );
      await tester.pumpAndSettle();
      expect(find.text('ui-components'), findsNothing);
    });

    // ---------------------------------------------------------------------
    // A2 — every action is keyboard reachable, including Deny
    // ---------------------------------------------------------------------

    testWidgets('Allow once, Always allow and Deny all activate by keyboard', (
      tester,
    ) async {
      var approved = 0;
      var always = 0;
      var denied = 0;

      await tester.pumpWidget(
        _host(
          onApprove: () => approved++,
          onAlwaysAllow: () => always++,
          onDeny: () => denied++,
        ),
      );
      await tester.pumpAndSettle();

      // Walk the traversal order and activate each stop in turn. The point of
      // the test is that Deny is reachable at all: before this pass the file
      // contained zero focus primitives, so a keyboard user could neither
      // approve nor refuse.
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (approved > 0 && always > 0 && denied > 0) break;
      }

      expect(approved, greaterThan(0), reason: 'Allow once never activated');
      expect(always, greaterThan(0), reason: 'Always allow never activated');
      expect(denied, greaterThan(0), reason: 'Deny never activated');
    });

    testWidgets('Space activates an action as well as Enter', (tester) async {
      var denied = 0;
      await tester.pumpWidget(_host(onDeny: () => denied++));
      await tester.pumpAndSettle();

      for (var i = 0; i < 12 && denied == 0; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
      }
      expect(denied, greaterThan(0));
    });

    testWidgets('every action carries a label for assistive technology', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(onApprove: () {}, onAlwaysAllow: () {}, onDeny: () {}),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    // A31. `androidTapTargetGuideline` measures the *semantics* rect, which
    // `BeuiMinHitTarget` deliberately does not grow — the whole point is to
    // widen the touch area without inflating the layout and pushing the
    // buttons apart. So the honest assertion is behavioural: a press that
    // lands outside the painted button still activates it.
    testWidgets('actions accept presses outside their painted bounds', (
      tester,
    ) async {
      var denied = 0;
      await tester.pumpWidget(_host(onApprove: () {}, onDeny: () => denied++));
      await tester.pumpAndSettle();

      final visual = tester.getRect(
        find.ancestor(of: find.text('Deny'), matching: find.byType(BeuiButton)),
      );
      expect(
        visual.height,
        lessThan(44),
        reason: 'the visual is deliberately smaller than the hit target',
      );

      // 4px below the painted bottom edge — inside the 44px slop, outside the
      // button itself.
      await tester.tapAt(Offset(visual.center.dx, visual.bottom + 4));
      await tester.pump();
      expect(denied, 1);
    });

    // ---------------------------------------------------------------------
    // A3 — the severity tier
    // ---------------------------------------------------------------------

    testWidgets('destructive suppresses Always allow and leads with Deny', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          severity: BeuiToolApprovalSeverity.destructive,
          onApprove: () {},
          onAlwaysAllow: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();

      // A standing grant for a destructive capability is not offered in
      // passing, even when the handler is wired.
      expect(find.text('Always allow'), findsNothing);

      // The safe exit reads first.
      final deny = tester.getRect(find.text('Deny'));
      final allow = tester.getRect(find.text('Allow once'));
      expect(deny.left, lessThan(allow.left));
    });

    testWidgets('destructive can be forced to keep Always allow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          severity: BeuiToolApprovalSeverity.destructive,
          allowAlways: true,
          onApprove: () {},
          onAlwaysAllow: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Always allow'), findsOneWidget);
    });

    testWidgets('destructive swaps the shield for a warning glyph', (
      tester,
    ) async {
      await tester.pumpWidget(_host(onApprove: () {}, onDeny: () {}));
      await tester.pumpAndSettle();
      final normalIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      await tester.pumpWidget(
        _host(
          severity: BeuiToolApprovalSeverity.destructive,
          onApprove: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();
      final destructiveIcons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      expect(destructiveIcons, isNot(equals(normalIcons)));
    });

    testWidgets('severity tiers render distinct card borders', (tester) async {
      Future<BoxDecoration> decorationFor(
        BeuiToolApprovalSeverity severity,
      ) async {
        await tester.pumpWidget(
          _host(severity: severity, onApprove: () {}, onDeny: () {}),
        );
        await tester.pumpAndSettle();
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(BeuiToolApproval),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return box.decoration as BoxDecoration;
      }

      final normal = await decorationFor(BeuiToolApprovalSeverity.normal);
      final elevated = await decorationFor(BeuiToolApprovalSeverity.elevated);
      final destructive = await decorationFor(
        BeuiToolApprovalSeverity.destructive,
      );

      expect(normal.border, isNot(equals(elevated.border)));
      expect(elevated.border, isNot(equals(destructive.border)));
    });

    // ---------------------------------------------------------------------
    // A4 — the post-decision double-fire window
    // ---------------------------------------------------------------------

    testWidgets('the exiting action row cannot fire a second decision', (
      tester,
    ) async {
      var approved = 0;
      var status = BeuiToolApprovalStatus.pending;

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: SizedBox(
                    width: 400,
                    child: BeuiToolApproval(
                      tool: 'terminal.run',
                      status: status,
                      onApprove: () {
                        approved++;
                        setState(
                          () => status = BeuiToolApprovalStatus.approving,
                        );
                      },
                      onDeny: () {},
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final allow = find.text('Allow once');
      await tester.tap(allow);
      // One frame in: the row is mid-exit and, before this fix, stayed fully
      // hit-testable for the whole fade.
      await tester.pump(const Duration(milliseconds: 16));

      if (allow.evaluate().isNotEmpty) {
        await tester.tap(allow, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(approved, 1);
    });

    // ---------------------------------------------------------------------
    // A21 / A43 — lapsed states, grant provenance, revocation
    // ---------------------------------------------------------------------

    testWidgets('expired and timedOut render as terminal end-states', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(status: BeuiToolApprovalStatus.expired, onApprove: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Allow once'), findsNothing);

      await tester.pumpWidget(
        _host(status: BeuiToolApprovalStatus.timedOut, onApprove: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Timed out'), findsOneWidget);
    });

    testWidgets('an always-allowed grant reads differently from once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approved,
          grant: BeuiToolApprovalGrant.once,
          onApprove: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Always allowed'), findsNothing);

      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approved,
          grant: BeuiToolApprovalGrant.always,
          onApprove: () {},
        ),
      );
      await tester.pumpAndSettle();
      // A43: a standing permission must never be silently indistinguishable
      // from a one-off.
      expect(find.text('Always allowed'), findsWidgets);
    });

    testWidgets('a standing grant offers a revoke affordance', (tester) async {
      var revoked = 0;
      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approved,
          grant: BeuiToolApprovalGrant.always,
          onApprove: () {},
          onRevoke: () => revoked++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Revoke'), findsOneWidget);
      await tester.tap(find.text('Revoke'));
      await tester.pump();
      expect(revoked, 1);
    });

    testWidgets('no revoke row without onRevoke', (tester) async {
      await tester.pumpWidget(
        _host(
          status: BeuiToolApprovalStatus.approved,
          grant: BeuiToolApprovalGrant.always,
          onApprove: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Revoke'), findsNothing);
    });

    // ---------------------------------------------------------------------
    // A23 — the details panel is bounded
    // ---------------------------------------------------------------------

    testWidgets('a long parameter list caps and scrolls', (tester) async {
      final many = [
        for (var i = 0; i < 40; i++)
          BeuiToolApprovalParameter(
            id: 'p$i',
            label: 'Key $i',
            value: 'value-$i',
          ),
      ];
      await tester.pumpWidget(
        _host(
          parameters: many,
          defaultOpen: true,
          onApprove: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Unbounded, a 300-line diff expanded the card indefinitely inside a
      // transcript.
      // Unbounded, 40 rows would run past 1200px and expand the card
      // indefinitely inside a transcript; the 240px cap holds it here.
      final card = tester.getRect(find.byType(BeuiToolApproval));
      expect(card.height, lessThan(620));
      expect(find.byType(Scrollbar), findsWidgets);
    });

    // ---------------------------------------------------------------------
    // A30 — terminal outcomes are announced
    // ---------------------------------------------------------------------

    testWidgets('terminal outcomes are announced through a live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(status: BeuiToolApprovalStatus.denied, onApprove: () {}),
      );
      await tester.pump();

      final denied = tester.getSemantics(find.bySemanticsLabel('Denied'));
      expect(denied.flagsCollection.isLiveRegion, isTrue);

      await tester.pumpWidget(
        _host(status: BeuiToolApprovalStatus.error, onApprove: () {}),
      );
      await tester.pump();
      final failed = tester.getSemantics(find.bySemanticsLabel('Failed'));
      expect(failed.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    // ---------------------------------------------------------------------
    // A16 / A36 / A27 — reduced motion, theming, strings
    // ---------------------------------------------------------------------

    testWidgets('reduced motion keeps an opacity fade on the disclosure', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          reduce: true,
          defaultOpen: false,
          parameters: _sampleParams,
          onApprove: () {},
          onDeny: () {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View details'));
      await tester.pump(); // commit the state change, seed the animation
      // Mid-fade: the copies this replaces hard-cut, so there was no frame
      // where the panel was partially opaque.
      await tester.pump(const Duration(milliseconds: 60));

      final opacities = tester
          .widgetList<Opacity>(find.byType(Opacity))
          .map((o) => o.opacity)
          .where((o) => o > 0.001 && o < 0.999)
          .toList();
      expect(opacities, isNotEmpty);
      await tester.pumpAndSettle();
    });

    testWidgets('status colour comes from the theme role, not a literal', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                BeuiAgentTheme(
                  statusLight: BeuiAgentStatusColors.light.copyWith(
                    pending: const BeuiAgentStatusPalette(
                      foreground: Color(0xFF112233),
                      background: Color(0xFF445566),
                      border: Color(0xFF778899),
                      solid: Color(0xFFAABBCC),
                      onSolid: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiToolApproval(
                  tool: 'terminal.run',
                  onApprove: () {},
                  onDeny: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final badge = tester.widget<Text>(find.text('Approval required'));
      expect(badge.style?.color, const Color(0xFF112233));
    });

    testWidgets('dark mode resolves the dark status role', (tester) async {
      await tester.pumpWidget(
        _host(dark: true, onApprove: () {}, onDeny: () {}),
      );
      await tester.pump();

      final badge = tester.widget<Text>(find.text('Approval required'));
      expect(badge.style?.color, BeuiAgentStatusColors.dark.pending.foreground);
    });

    testWidgets('labels route through the theme strings role', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                BeuiAgentTheme(
                  strings: const BeuiAgentStrings(
                    allowOnce: 'Autoriser une fois',
                    deny: 'Refuser',
                  ),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiToolApproval(
                  tool: 'terminal.run',
                  onApprove: () {},
                  onDeny: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Autoriser une fois'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
    });

    testWidgets('a per-instance label beats the theme string', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                BeuiAgentTheme(
                  strings: const BeuiAgentStrings(deny: 'Refuser'),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiToolApproval(
                  tool: 'terminal.run',
                  denyLabel: 'Nope',
                  onApprove: () {},
                  onDeny: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nope'), findsOneWidget);
      expect(find.text('Refuser'), findsNothing);
    });

    // ---------------------------------------------------------------------
    // Golden
    // ---------------------------------------------------------------------

    testWidgets('golden — pending, destructive, and approved tiers', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(460, 830));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
          ),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BeuiToolApproval(
                        tool: 'terminal.run',
                        description: 'Run the validation suite.',
                        parameters: const [
                          BeuiToolApprovalParameter(
                            id: 'command',
                            label: 'Command',
                            value: 'bun test checkout',
                          ),
                        ],
                        onApprove: () {},
                        onAlwaysAllow: () {},
                        onDeny: () {},
                      ),
                      const SizedBox(height: 12),
                      BeuiToolApproval(
                        tool: 'fs.remove',
                        title: 'Delete the project directory?',
                        severity: BeuiToolApprovalSeverity.destructive,
                        onApprove: () {},
                        onAlwaysAllow: () {},
                        onDeny: () {},
                      ),
                      const SizedBox(height: 12),
                      BeuiToolApproval(
                        tool: 'terminal.run',
                        status: BeuiToolApprovalStatus.approved,
                        grant: BeuiToolApprovalGrant.always,
                        onApprove: () {},
                        onRevoke: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/beui_tool_approval.png'),
      );
    });
  });
}
