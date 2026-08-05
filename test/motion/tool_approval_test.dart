import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  Object tool = 'terminal.run',
  Object title = 'Allow this tool to run?',
  Object? description,
  List<BeuiToolApprovalParameter> parameters = const [],
  BeuiToolApprovalStatus status = BeuiToolApprovalStatus.pending,
  bool? open,
  bool defaultOpen = false,
  ValueChanged<bool>? onOpenChange,
  VoidCallback? onApprove,
  VoidCallback? onAlwaysAllow,
  VoidCallback? onDeny,
  bool reduce = false,
}) {
  Widget body = Center(
    child: SizedBox(
      width: 400,
      child: BeuiToolApproval(
        tool: tool,
        title: title,
        description: description,
        parameters: parameters,
        status: status,
        open: open,
        defaultOpen: defaultOpen,
        onOpenChange: onOpenChange,
        onApprove: onApprove,
        onAlwaysAllow: onAlwaysAllow,
        onDeny: onDeny,
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
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
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

    testWidgets('Allow once and Deny show even without handlers', (
      tester,
    ) async {
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
      expect(find.text('Always allow'), findsNothing);
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
          theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
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
  });
}
