// ignore_for_file: avoid_relative_lib_imports

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../example/lib/demos/volume_profile_demo.dart';
import '../support.dart';

void main() {
  testWidgets('volume sessions and summary remain reachable in a short view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      beuiTestApp(
        Builder(builder: volumeProfileDemo),
        width: 343,
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final profile = tester.widget<BeuiVolumeProfile>(
      find.byType(BeuiVolumeProfile),
    );
    expect(profile.data.first.volume, 75);
    expect(profile.data[11].volume, 1182);
    expect(tester.getSize(find.byType(BeuiVolumeProfilePlot)).height, 312);
    await tester.ensureVisible(find.text('Total volume'));
    await tester.pumpAndSettle();
    final label = tester.getRect(find.text('Total volume'));
    expect(label.top, greaterThanOrEqualTo(0));
    expect(label.bottom, lessThanOrEqualTo(420));
    expect(tester.takeException(), isNull);
  });
}
