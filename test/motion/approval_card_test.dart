import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _questions = <BeuiApprovalCardQuestion>[
  BeuiApprovalCardQuestion(
    id: 'scope',
    title: 'How focused should the first release be?',
    options: [
      BeuiApprovalCardOption(value: 'focused', label: 'A focused starter set'),
      BeuiApprovalCardOption(value: 'broad', label: 'A broader collection'),
    ],
    allowCustom: true,
    customPlaceholder: 'Describe another scope…',
  ),
  BeuiApprovalCardQuestion(
    id: 'checks',
    title: 'Which checks should block publishing?',
    description: 'Select every check the agent must pass.',
    multiple: true,
    options: [
      BeuiApprovalCardOption(value: 'types', label: 'Type safety'),
      BeuiApprovalCardOption(value: 'accessibility', label: 'Accessibility'),
    ],
  ),
  BeuiApprovalCardQuestion(
    id: 'preserve',
    title: 'Anything the agent should preserve?',
    allowCustom: true,
    customPlaceholder: 'Add a final constraint…',
  ),
];

Widget _host({
  String title = 'Approval required',
  String? description,
  Widget? child,
  List<BeuiApprovalCardQuestion> questions = const [],
  BeuiApprovalCardStatus status = BeuiApprovalCardStatus.pending,
  BeuiApprovalCardAnswers? answers,
  BeuiApprovalCardAnswers defaultAnswers = const {},
  ValueChanged<BeuiApprovalCardAnswers>? onAnswersChange,
  int? step,
  int defaultStep = 0,
  ValueChanged<int>? onStepChange,
  ValueChanged<BeuiApprovalCardAnswers>? onSubmit,
  VoidCallback? onApprove,
  VoidCallback? onReject,
  VoidCallback? onRequestChanges,
  VoidCallback? onDismiss,
  String approveLabel = 'Approve',
  String submitLabel = 'Submit response',
  Widget? result,
  bool reduce = false,
  bool? expanded,
  bool defaultExpanded = false,
  ValueChanged<bool>? onExpandedChanged,
  Widget? headerAction,
  Widget? compactChild,
  Widget? expandedChild,
  bool showExpandToggle = true,
  String? rejectLabel,
  String? requestChangesLabel,
}) {
  Widget body = Center(
    child: SizedBox(
      width: 400,
      child: BeuiApprovalCard(
        title: title,
        description: description,
        questions: questions,
        status: status,
        answers: answers,
        defaultAnswers: defaultAnswers,
        onAnswersChange: onAnswersChange,
        step: step,
        defaultStep: defaultStep,
        onStepChange: onStepChange,
        onSubmit: onSubmit,
        onApprove: onApprove,
        onReject: onReject,
        onRequestChanges: onRequestChanges,
        onDismiss: onDismiss,
        approveLabel: approveLabel,
        submitLabel: submitLabel,
        result: result,
        expanded: expanded,
        defaultExpanded: defaultExpanded,
        onExpandedChanged: onExpandedChanged,
        headerAction: headerAction,
        compactChild: compactChild,
        expandedChild: expandedChild,
        showExpandToggle: showExpandToggle,
        rejectLabel: rejectLabel,
        requestChangesLabel: requestChangesLabel,
        child: child,
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
      ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  group('BeuiApprovalCard — simple approval', () {
    testWidgets('renders title, description, and action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Publish the component update?',
          description: 'Waiting for your decision.',
          onApprove: () {},
          onRequestChanges: () {},
          onReject: () {},
          child: const Text('Release meta'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publish the component update?'), findsOneWidget);
      expect(find.text('Waiting for your decision.'), findsOneWidget);
      expect(find.text('Release meta'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Request changes'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Input required'), findsOneWidget);
    });

    testWidgets('hides optional actions when callbacks are null', (
      tester,
    ) async {
      await tester.pumpWidget(_host(onApprove: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Request changes'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('approve / reject / request-changes fire callbacks', (
      tester,
    ) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _host(
          onApprove: () => calls.add('approve'),
          onRequestChanges: () => calls.add('changes'),
          onReject: () => calls.add('reject'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.tap(find.text('Request changes'));
      await tester.pump();
      await tester.tap(find.text('Reject'));
      await tester.pump();

      expect(calls, ['approve', 'changes', 'reject']);
    });

    testWidgets('submitting disables actions and shows badge', (tester) async {
      var approved = false;
      await tester.pumpWidget(
        _host(
          status: BeuiApprovalCardStatus.submitting,
          onApprove: () => approved = true,
          onReject: () {},
        ),
      );
      await tester.pump(); // avoid pumpAndSettle hanging on spin

      expect(find.text('Submitting'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(approved, isFalse);
    });

    testWidgets('terminal status collapses interactive body and shows result', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          status: BeuiApprovalCardStatus.approved,
          description: 'Should hide when collapsed.',
          onApprove: () {},
          onReject: () {},
          result: const Text('Publishing was approved.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Should hide when collapsed.'), findsNothing);
      expect(find.text('Publishing was approved.'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
    });

    testWidgets('dismiss callback is wired', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        _host(onApprove: () {}, onDismiss: () => dismissed = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('BeuiApprovalCard — question flow', () {
    testWidgets('renders first question with counter and options', (
      tester,
    ) async {
      await tester.pumpWidget(_host(questions: _questions));
      await tester.pumpAndSettle();

      expect(
        find.text('How focused should the first release be?'),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('A focused starter set'), findsOneWidget);
      expect(find.text('A broader collection'), findsOneWidget);
      // Status badge replaced by counter while interactive + questions.
      expect(find.text('Input required'), findsNothing);
    });

    testWidgets('next disabled until answered; advances on select + next', (
      tester,
    ) async {
      final steps = <int>[];
      await tester.pumpWidget(
        _host(questions: _questions, onStepChange: steps.add),
      );
      await tester.pumpAndSettle();

      // Next is icon-only (arrow) while not on last step.
      final next = find.byIcon(LucideIcons.arrow_right);
      expect(next, findsOneWidget);

      await tester.tap(find.text('A focused starter set'));
      await tester.pumpAndSettle();

      await tester.tap(next);
      await tester.pumpAndSettle();

      expect(steps, isNotEmpty);
      expect(steps.last, 1);
      expect(
        find.text('Which checks should block publishing?'),
        findsOneWidget,
      );
      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('auto-advances single-select after 240ms', (tester) async {
      final steps = <int>[];
      await tester.pumpWidget(
        _host(questions: _questions, onStepChange: steps.add),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A broader collection'));
      await tester.pump(); // start
      expect(find.text('1/3'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();

      expect(steps, contains(1));
      expect(
        find.text('Which checks should block publishing?'),
        findsOneWidget,
      );
    });

    testWidgets('multi-select does not auto-advance', (tester) async {
      await tester.pumpWidget(_host(questions: _questions, defaultStep: 1));
      await tester.pumpAndSettle();

      expect(
        find.text('Which checks should block publishing?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Type safety'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Still on step 2 (index 1).
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Type safety'), findsOneWidget);
    });

    testWidgets('previous navigates back', (tester) async {
      await tester.pumpWidget(_host(questions: _questions, defaultStep: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.arrow_left));
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsOneWidget);
      expect(
        find.text('How focused should the first release be?'),
        findsOneWidget,
      );
    });

    testWidgets('submit on last step reports answers', (tester) async {
      BeuiApprovalCardAnswers? submitted;
      await tester.pumpWidget(
        _host(
          questions: _questions,
          defaultStep: 2,
          defaultAnswers: const {
            'preserve': BeuiApprovalCardAnswer(custom: 'Keep the API stable'),
          },
          onSubmit: (a) => submitted = a,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anything the agent should preserve?'), findsOneWidget);
      await tester.tap(find.text('Submit response'));
      await tester.pump();

      expect(submitted, isNotNull);
      expect(submitted!['preserve']?.custom, 'Keep the API stable');
    });

    testWidgets('controlled answers report onAnswersChange', (tester) async {
      var answers = <String, BeuiApprovalCardAnswer>{};
      final changes = <BeuiApprovalCardAnswers>[];

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _host(
              questions: _questions,
              answers: answers,
              onAnswersChange: (next) {
                changes.add(next);
                setState(() => answers = next);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('A focused starter set'));
      await tester.pumpAndSettle();

      expect(changes, isNotEmpty);
      expect(answers['scope']?.selected, ['focused']);
    });

    testWidgets('answered status collapses and shows result', (tester) async {
      await tester.pumpWidget(
        _host(
          questions: _questions,
          status: BeuiApprovalCardStatus.answered,
          result: const Text('Three responses sent to the agent.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/3'), findsNothing);
      expect(find.text('A focused starter set'), findsNothing);
      expect(find.text('Three responses sent to the agent.'), findsOneWidget);
      expect(find.text('Response submitted'), findsOneWidget);
    });
  });

  group('BeuiApprovalCard — visual fidelity', () {
    testWidgets('heading and action labels keep the ambient font family', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'HostFace',
          ).copyWith(extensions: [BeuiColors.light()]),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: BeuiApprovalCard(
                  questions: _questions,
                  onSubmit: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // A replacing DefaultTextStyle / AnimatedDefaultTextStyle would reset the
      // family to the platform default, silently rendering in the wrong face.
      String? familyOf(Finder finder) =>
          tester.renderObject<RenderParagraph>(finder).text.style?.fontFamily;

      expect(familyOf(find.text(_questions.first.title)), 'HostFace');
      expect(familyOf(find.text('A focused starter set')), 'HostFace');
    });

    testWidgets('question nav buttons are circular (source rounded-full)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(questions: _questions, onSubmit: (_) {}));
      await tester.pump(const Duration(milliseconds: 400));

      for (final label in ['Previous question', 'Next question']) {
        final button = tester.widget<BeuiButton>(
          find.descendant(
            of: find.byTooltip(label),
            matching: find.byType(BeuiButton),
          ),
        );
        expect(
          button.borderRadius,
          BorderRadius.circular(999),
          reason: '$label should be a pill, not the icon size\'s rounded-lg',
        );
      }
    });

    testWidgets('custom-response field sits in a 2px p-0.5 gutter', (
      tester,
    ) async {
      await tester.pumpWidget(_host(questions: _questions, onSubmit: (_) {}));
      await tester.pump(const Duration(milliseconds: 400));

      // Source: `className={cn("p-0.5", question.options?.length && "mt-1.5")}`
      // — 6px margin above plus a 2px gutter all round the 40px field.
      final paddings = tester.widgetList<Padding>(
        find.ancestor(
          of: find.byType(BeuiInput),
          matching: find.byType(Padding),
        ),
      );
      expect(
        paddings.any((p) => p.padding == const EdgeInsets.fromLTRB(2, 8, 2, 2)),
        isTrue,
        reason: 'expected the mt-1.5 + p-0.5 slot around the input',
      );
    });
  });

  group('BeuiApprovalCard — compact-to-expanded', () {
    testWidgets('shows compact content until expanded', (tester) async {
      await tester.pumpWidget(
        _host(
          title: 'Review proposal',
          onApprove: () {},
          compactChild: const Text('Summary only'),
          expandedChild: const Text('Full editor body'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Summary only'), findsOneWidget);
      expect(find.text('Full editor body'), findsNothing);
      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('header action renders without toggling expansion', (
      tester,
    ) async {
      var headerTaps = 0;
      await tester.pumpWidget(
        _host(
          onApprove: () {},
          headerAction: IconButton(
            key: const ValueKey('edit-action'),
            onPressed: () => headerTaps++,
            icon: const Icon(Icons.edit),
          ),
          compactChild: const Text('Summary only'),
          expandedChild: const SizedBox(
            height: 120,
            child: Text('Full editor body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit-action')));
      await tester.pump();
      expect(headerTaps, 1);
      expect(find.text('Full editor body'), findsNothing);
    });

    testWidgets('controlled expansion updates', (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        beuiTestApp(
          SizedBox(
            width: 400,
            child: StatefulBuilder(
              builder: (context, setState) {
                return BeuiApprovalCard(
                  title: 'Approval required',
                  onApprove: () {},
                  expanded: expanded,
                  onExpandedChanged: (v) => setState(() => expanded = v),
                  compactChild: const Text('Summary only'),
                  expandedChild: const SizedBox(
                    height: 80,
                    child: Text('Full editor body'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Full editor body'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pumpAndSettle();
      expect(expanded, isTrue);
      expect(find.text('Full editor body'), findsWidgets);
    });

    testWidgets('uncontrolled toggle reveals expanded content', (tester) async {
      await tester.pumpWidget(
        _host(
          onApprove: () {},
          compactChild: const Text('Summary only'),
          expandedChild: const SizedBox(
            height: 80,
            child: Text('Full editor body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pumpAndSettle();
      expect(find.text('Full editor body'), findsWidgets);
    });

    testWidgets('reversing expansion mid-motion does not throw', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          onApprove: () {},
          compactChild: const Text('Summary only'),
          expandedChild: const SizedBox(
            height: 160,
            child: Text('Full editor body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('Summary only'), findsOneWidget);
    });

    testWidgets('reduced motion snaps expanded content', (tester) async {
      await tester.pumpWidget(
        _host(
          reduce: true,
          onApprove: () {},
          compactChild: const Text('Summary only'),
          expandedChild: const SizedBox(
            height: 80,
            child: Text('Full editor body'),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pump();
      expect(find.text('Full editor body'), findsOneWidget);
    });

    testWidgets('expand control exposes semantics and keyboard activation', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          onApprove: () {},
          compactChild: const Text('Summary only'),
          expandedChild: const SizedBox(
            height: 80,
            child: Text('Full editor body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Show details'), findsOneWidget);

      final expander = find.byKey(const ValueKey('beui-approval-expand'));
      final focus = Focus.maybeOf(tester.element(expander));
      expect(focus, isNotNull);
      focus!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hide details'), findsOneWidget);
      expect(find.text('Full editor body'), findsWidgets);
    });
  });

  // =======================================================================
  // A11 — the header-is-a-trigger invariant
  // =======================================================================

  group('BeuiApprovalCard header trigger invariant', () {
    testWidgets('the whole header row toggles expansion, not just a chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Publish the update?',
          compactChild: const Text('Summary only'),
          expandedChild: const Text('Full editor body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Summary only'), findsWidgets);

      // Tap the *title*, which is nowhere near the 20x20 chevron that used to
      // be the only target.
      await tester.tap(find.text('Publish the update?'));
      await tester.pumpAndSettle();
      expect(find.text('Full editor body'), findsWidgets);
    });

    testWidgets('a card with only child + headerAction has an inert header', (
      tester,
    ) async {
      var actionTaps = 0;
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _host(
          title: 'Publish the update?',
          child: const Text('Summary only'),
          headerAction: IconButton(
            key: const ValueKey('header-action'),
            icon: const Icon(Icons.edit),
            onPressed: () => actionTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The invariant: no expandedChild means the header is not a control.
      expect(find.byKey(const ValueKey('beui-approval-expand')), findsNothing);
      expect(find.bySemanticsLabel('Show details'), findsNothing);
      expect(find.bySemanticsLabel('Hide details'), findsNothing);

      // Tapping the title does nothing at all — no hidden second control.
      await tester.tap(find.text('Publish the update?'));
      await tester.pumpAndSettle();
      expect(actionTaps, 0);

      // ...and headerAction is untouched.
      await tester.tap(find.byKey(const ValueKey('header-action')));
      await tester.pumpAndSettle();
      expect(actionTaps, 1);

      handle.dispose();
    });

    testWidgets('showExpandToggle:false makes the header inert too', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          title: 'Publish the update?',
          compactChild: const Text('Summary only'),
          expandedChild: const Text('Full editor body'),
          showExpandToggle: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('beui-approval-expand')), findsNothing);
      await tester.tap(find.text('Publish the update?'));
      await tester.pumpAndSettle();
      // Still collapsed: the caller turned the affordance off.
      expect(find.text('Full editor body'), findsNothing);
    });

    testWidgets(
      'headerAction stays independent while the header IS a trigger',
      (tester) async {
        var actionTaps = 0;
        await tester.pumpWidget(
          _host(
            title: 'Publish the update?',
            compactChild: const Text('Summary only'),
            expandedChild: const Text('Full editor body'),
            headerAction: IconButton(
              key: const ValueKey('header-action'),
              icon: const Icon(Icons.edit),
              onPressed: () => actionTaps++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('header-action')));
        await tester.pumpAndSettle();

        expect(actionTaps, 1);
        // The action fired and the card did NOT expand.
        expect(find.text('Full editor body'), findsNothing);
      },
    );

    testWidgets('the header trigger clears the 48px touch floor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          compactChild: const Text('Summary only'),
          expandedChild: const Text('Full editor body'),
          onApprove: () {},
        ),
      );
      await tester.pumpAndSettle();

      // Measured directly rather than through
      // `meetsGuideline(androidTapTargetGuideline)`: that walks the whole
      // tree, and `BeuiButton` fixes its own height at 32px for
      // `BeuiButtonSize.sm`, which no wrapper in this file can grow — the
      // semantics rect belongs to the button. Raising the *whole cluster* to
      // 48 needs a min-tap-target option on BeuiButton itself.
      final trigger = tester.getRect(
        find.byKey(const ValueKey('beui-approval-expand')),
      );
      expect(trigger.height, greaterThanOrEqualTo(48));

      // Every target is at least labeled, which is the part that is fully in
      // this widget's gift.
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  // =======================================================================
  // A10 / A12 — expandable body correctness
  // =======================================================================

  group('BeuiApprovalCard expandable body', () {
    test('an expandedChild with nothing to collapse to asserts', () {
      // A chevron over a legitimately blank body is a wiring bug. The
      // assert is in the const constructor, so it throws while the widget is
      // being built rather than during the pump — no tester/pump needed.
      expect(
        () => _host(expandedChild: const Text('Full editor body')),
        throwsAssertionError,
      );
    });

    testWidgets('a stateful expandedChild is instantiated exactly once', (
      tester,
    ) async {
      // The old implementation rendered each child twice — once offstage
      // to measure it, once to display it — so a BeuiInput here became two
      // EditableTexts with two FocusNodes and two independent buffers. The
      // agent-theme demo does exactly this, which is how it was found.
      await tester.pumpWidget(
        _host(
          compactChild: const Text('Summary only'),
          expandedChild: const BeuiInput(placeholder: 'Add a note'),
        ),
      );
      await tester.pumpAndSettle();

      // `skipOffstage: false` is the point of the test: the collapsed body is
      // Offstage, and a second instance hiding there is exactly the bug.
      expect(find.byType(EditableText, skipOffstage: false), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pumpAndSettle();

      expect(find.byType(EditableText, skipOffstage: false), findsOneWidget);
    });

    testWidgets('text typed into the expanded body survives a collapse', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          defaultExpanded: true,
          compactChild: const Text('Summary only'),
          expandedChild: const BeuiInput(placeholder: 'Add a note'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(EditableText), 'keep me');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('beui-approval-expand')));
      await tester.pumpAndSettle();

      // One instance means one buffer: the text the user sees is the text the
      // card would submit.
      final field = find.byType(EditableText, skipOffstage: false);
      expect(field, findsOneWidget);
      expect(tester.widget<EditableText>(field).controller.text, 'keep me');
    });
  });

  // =======================================================================
  // Strings, status roles, and the golden
  // =======================================================================

  group('BeuiApprovalCard theming', () {
    testWidgets('reject and request-changes labels come from the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: BeuiTextTheme.trackingNormal(
            ThemeData.light().copyWith(
              extensions: [
                BeuiColors.light(),
                BeuiAgentTheme(
                  strings: const BeuiAgentStrings(
                    reject: 'Refuser',
                    requestChanges: 'Demander des modifications',
                  ),
                ),
              ],
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 460,
                child: BeuiApprovalCard(
                  title: 'Publish?',
                  onApprove: () {},
                  onReject: () {},
                  onRequestChanges: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refuser'), findsOneWidget);
      expect(find.text('Demander des modifications'), findsOneWidget);
    });

    testWidgets('per-instance labels beat the theme strings', (tester) async {
      await tester.pumpWidget(
        _host(
          onApprove: () {},
          onReject: () {},
          onRequestChanges: () {},
          rejectLabel: 'Turn it down',
          requestChangesLabel: 'Send it back',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Turn it down'), findsOneWidget);
      expect(find.text('Send it back'), findsOneWidget);
    });

    testWidgets('the status badge reads the themed status role', (
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
                width: 460,
                child: BeuiApprovalCard(title: 'Publish?', onApprove: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final badge = tester.widget<Text>(find.text('Input required'));
      expect(badge.style?.color, const Color(0xFF112233));
    });

    testWidgets('a terminal outcome is announced through the live region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(status: BeuiApprovalCardStatus.rejected, onApprove: () {}),
      );
      await tester.pump();

      final node = tester.getSemantics(find.byType(BeuiApprovalCard));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('golden — pending, expandable, and rejected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        beuiTestApp(
          RepaintBoundary(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BeuiApprovalCard(
                    title: 'Publish the component update?',
                    description: 'Ships to the shared registry.',
                    onApprove: () {},
                    onRequestChanges: () {},
                    onReject: () {},
                  ),
                  const SizedBox(height: 12),
                  BeuiApprovalCard(
                    title: 'Review the release notes?',
                    compactChild: const Text('3 entries, 1 breaking'),
                    expandedChild: const Text('Full editor body'),
                    onApprove: () {},
                  ),
                  const SizedBox(height: 12),
                  const BeuiApprovalCard(
                    title: 'Publish the component update?',
                    status: BeuiApprovalCardStatus.rejected,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      // The header title rolls in on a spring, so a single frame catches it
      // mid-roll and the golden records an empty header. A fixed advance
      // settles the roll and the expand height; `pumpAndSettle` is not an
      // option because a submitting card spins indefinitely.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('goldens/beui_approval_card.png'),
      );
    });
  });
}
