import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('BeuiApprovalCard — reduced motion', () {
    testWidgets('still renders and accepts input under reduced motion', (
      tester,
    ) async {
      var approved = false;
      await tester.pumpWidget(
        _host(reduce: true, onApprove: () => approved = true, onReject: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      expect(approved, isTrue);
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
}
