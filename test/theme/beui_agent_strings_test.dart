import 'package:beui/beui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('const canonicalization is load-bearing for AnimatedTheme', () {
    test('two const BeuiAgentStrings() are ==', () {
      const a = BeuiAgentStrings();
      const b = BeuiAgentStrings();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('two const BeuiAgentTheme() are ==', () {
      const a = BeuiAgentTheme();
      const b = BeuiAgentTheme();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('count-bearing functions produce the documented English default', () {
    const strings = BeuiAgentStrings();

    test('stepCounter', () {
      expect(strings.stepCounter(2, 5), '2/5');
    });

    test('questionProgress', () {
      expect(strings.questionProgress(2, 5), 'Question 2 of 5');
    });

    test('todoCountDenominator', () {
      expect(strings.todoCountDenominator(7), '/7');
    });

    test('todoHeaderLabel when open (Collapse branch)', () {
      expect(
        strings.todoHeaderLabel(3, 7, true),
        '3 of 7 tasks completed. Collapse task list',
      );
    });

    test('todoHeaderLabel when closed (Expand branch)', () {
      expect(
        strings.todoHeaderLabel(3, 7, false),
        '3 of 7 tasks completed. Expand task list',
      );
    });

    test('todoRowLabel', () {
      expect(strings.todoRowLabel('Pending'), 'Pending: ');
    });

    test('activityThoughtFor', () {
      expect(strings.activityThoughtFor('4.6s'), 'Thought for 4.6s');
    });

    test('activityRanTools singular', () {
      expect(strings.activityRanTools(1), 'Ran 1 tool');
    });

    test('activityRanTools plural', () {
      expect(strings.activityRanTools(3), 'Ran 3 tools');
    });

    test('activityToolCallsAndMessages both singular', () {
      expect(
        strings.activityToolCallsAndMessages(1, 1),
        '1 tool call, 1 message',
      );
    });

    test('activityToolCallsAndMessages both plural', () {
      expect(
        strings.activityToolCallsAndMessages(3, 2),
        '3 tool calls, 2 messages',
      );
    });

    test('activityCompletedSteps singular', () {
      expect(strings.activityCompletedSteps(1), 'Completed 1 step');
    });

    test('activityCompletedSteps plural', () {
      expect(strings.activityCompletedSteps(4), 'Completed 4 steps');
    });

    test('activityMoreResults', () {
      expect(strings.activityMoreResults(3), '+3 more');
    });

    test('durationSeconds', () {
      expect(strings.durationSeconds(42), '42s');
    });

    test('durationMinutes', () {
      expect(strings.durationMinutes(3), '3m');
    });

    test('durationMinutesSeconds', () {
      expect(strings.durationMinutesSeconds(3, 12), '3m 12s');
    });

    test('diffAdditions', () {
      expect(strings.diffAdditions(42), '+42');
    });

    test('diffDeletions uses U+2212 MINUS SIGN, not an ASCII hyphen', () {
      final result = strings.diffDeletions(7);
      expect(result.startsWith('−'), isTrue);
      expect(result, '−7');
      expect(result, isNot('-7'));
    });
  });

  group('plain string defaults match the widgets current copy', () {
    const strings = BeuiAgentStrings();

    test('tool approval', () {
      expect(strings.allowOnce, 'Allow once');
      expect(strings.alwaysAllow, 'Always allow');
      expect(strings.deny, 'Deny');
      expect(strings.viewDetails, 'View details');
      expect(strings.toolApprovalTitle, 'Allow this tool to run?');
    });

    test('approval card', () {
      expect(strings.approve, 'Approve');
      expect(strings.reject, 'Reject');
      expect(strings.requestChanges, 'Request changes');
      expect(strings.submitResponse, 'Submit response');
    });

    test('tool result', () {
      expect(strings.copyResult, 'Copy result');
      expect(strings.copied, 'Copied');
      expect(strings.runAgain, 'Run again');
    });

    test('todo list', () {
      expect(strings.todoListTitle, 'To-dos');
      expect(strings.todoEmpty, 'No tasks yet');
      expect(strings.todoListLabel, 'Agent task list');
    });

    test('shared status words', () {
      expect(strings.statusApprovalRequired, 'Approval required');
      expect(strings.statusDenied, 'Denied');
      expect(strings.statusRejected, 'Rejected');
      expect(strings.statusCancelled, 'Cancelled');
    });

    test('custom answer placeholder uses U+2026 ellipsis', () {
      expect(strings.customAnswerPlaceholder, 'Add another response…');
    });

    test('activity thinking uses U+2026 ellipsis', () {
      expect(strings.activityThinking, 'Thinking…');
    });
  });

  group('the refusal vocabulary is intentionally distinct by default', () {
    test('deny != reject', () {
      const strings = BeuiAgentStrings();
      expect(strings.deny, isNot(strings.reject));
    });

    test('statusDenied != statusRejected', () {
      const strings = BeuiAgentStrings();
      expect(strings.statusDenied, isNot(strings.statusRejected));
    });
  });

  group('copyWith', () {
    test('overrides one field and preserves the rest', () {
      const base = BeuiAgentStrings();
      final modified = base.copyWith(allowOnce: 'Autoriser une fois');
      expect(modified.allowOnce, 'Autoriser une fois');
      expect(modified.alwaysAllow, base.alwaysAllow);
      expect(modified.deny, base.deny);
      expect(modified.toolApprovalTitle, base.toolApprovalTitle);
    });

    test('overriding a function field works', () {
      const base = BeuiAgentStrings();
      final modified = base.copyWith(activityRanTools: (n) => 'X$n');
      expect(modified.activityRanTools(3), 'X3');
      expect(base.activityRanTools(3), 'Ran 3 tools');
    });
  });

  group('lerp snaps at the midpoint', () {
    test('lerp(a, b, 0.2) == a', () {
      const a = BeuiAgentStrings();
      final b = a.copyWith(allowOnce: 'Autoriser une fois');
      expect(BeuiAgentStrings.lerp(a, b, 0.2), a);
    });

    test('lerp(a, b, 0.8) == b', () {
      const a = BeuiAgentStrings();
      final b = a.copyWith(allowOnce: 'Autoriser une fois');
      expect(BeuiAgentStrings.lerp(a, b, 0.8), b);
    });
  });
}
