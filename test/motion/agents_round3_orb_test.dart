import 'dart:convert';
import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets('orb retains source velocity through ramp release and repeat', (
    tester,
  ) async {
    final reference =
        jsonDecode(
              File(
                'docs/proof/v3-parity/agents/round3/orb-retarget-source.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final activity = ValueNotifier<double>(0);
    addTearDown(activity.dispose);
    await tester.pumpWidget(
      beuiTestApp(BeuiVoiceOrb(activityListenable: activity)),
    );
    final transforms = find.descendant(
      of: find.byType(BeuiVoiceOrb),
      matching: find.byType(Transform),
    );
    for (final segment in reference['segments'] as List) {
      activity.value = (segment['target'] as num).toDouble();
      await tester.pump();
      var previousMs = 0;
      for (final sample in segment['samples'] as List) {
        final timeMs = sample['timeMs'] as int;
        await tester.pump(Duration(milliseconds: timeMs - previousMs));
        previousMs = timeMs;
        final scale = tester.widgetList<Transform>(transforms).last.transform;
        final level = (scale.entry(0, 0) - 1) / 0.04;
        expect(
          level,
          closeTo((sample['value'] as num).toDouble(), 0.0002),
          reason: 'target ${segment['target']}, elapsed $timeMs ms',
        );
        expect(scale.entry(1, 1), closeTo(1 - level * 0.018, 0.00001));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
