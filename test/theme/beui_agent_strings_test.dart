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
    final cases = <(String Function(), String)>[
      (() => strings.stepCounter(2, 5), '2/5'),
      (() => strings.questionProgress(2, 5), 'Question 2 of 5'),
      (() => strings.todoCountDenominator(7), '/7'),
      (
        () => strings.todoHeaderLabel(3, 7, true),
        '3 of 7 tasks completed. Collapse task list',
      ),
      (
        () => strings.todoHeaderLabel(3, 7, false),
        '3 of 7 tasks completed. Expand task list',
      ),
      (() => strings.todoRowLabel('Pending'), 'Pending: '),
      (() => strings.activityThoughtFor('4.6s'), 'Thought for 4.6s'),
      (() => strings.activityRanTools(1), 'Ran 1 tool'),
      (() => strings.activityRanTools(3), 'Ran 3 tools'),
      (
        () => strings.activityToolCallsAndMessages(1, 1),
        '1 tool call, 1 message',
      ),
      (
        () => strings.activityToolCallsAndMessages(3, 2),
        '3 tool calls, 2 messages',
      ),
      (() => strings.activityCompletedSteps(1), 'Completed 1 step'),
      (() => strings.activityCompletedSteps(4), 'Completed 4 steps'),
      (() => strings.activityMoreResults(3), '+3 more'),
      (() => strings.durationSeconds(42), '42s'),
      (() => strings.durationMinutes(3), '3m'),
      (() => strings.durationMinutesSeconds(3, 12), '3m 12s'),
      (() => strings.diffAdditions(42), '+42'),
      // U+2212 MINUS SIGN, not an ASCII hyphen.
      (() => strings.diffDeletions(7), '−7'),
      (
        () => strings.activityFailedSummary('Ran 3 tools'),
        'Failed · Ran 3 tools',
      ),
      (
        () => strings.activityCancelledSummary('Ran 3 tools'),
        'Cancelled · Ran 3 tools',
      ),
      (() => strings.showSources(1), '1 source'),
      (() => strings.showSources(3), '3 sources'),
      (() => strings.hiddenLines(1), '1 more line'),
      (() => strings.hiddenLines(3), '3 more lines'),
      (() => strings.hiddenLinesCollapsed(1), '1 hidden line'),
      (() => strings.hiddenLinesCollapsed(3), '3 hidden lines'),
      (() => strings.expandHiddenLines(1), 'Expand 1 hidden line'),
      (() => strings.expandHiddenLines(3), 'Expand 3 hidden lines'),
    ];
    for (final (fn, expected) in cases) {
      test(expected, () => expect(fn(), expected));
    }
  });

  test('no default string uses three dots instead of the U+2026 ellipsis', () {
    const strings = BeuiAgentStrings();
    expect(strings.customAnswerPlaceholder, isNot(contains('...')));
    expect(strings.activityThinking, isNot(contains('...')));
    expect(strings.promptPlaceholder, isNot(contains('...')));
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

    test('overrides copyCode and hiddenLines, preserves copyDiff and '
        'hiddenLinesCollapsed', () {
      const base = BeuiAgentStrings();
      final modified = base.copyWith(
        copyCode: 'Copier le code',
        hiddenLines: (n) => 'X$n',
      );
      expect(modified.copyCode, 'Copier le code');
      expect(modified.hiddenLines(3), 'X3');
      expect(modified.copyDiff, base.copyDiff);
      expect(modified.hiddenLinesCollapsed(3), base.hiddenLinesCollapsed(3));
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
