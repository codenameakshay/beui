import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets('date trigger matches source tabular date width in Geist', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiDateRangePickerDropdown(
          value: BeuiDateRange(from: '2026-10-17', to: '2026-10-23'),
        ),
        fontFamily: 'Geist',
      ),
    );
    expect(
      tester.getSize(find.byType(OutlinedButton)).width,
      closeTo(204.28125, .05),
    );
    expect(tester.getSize(find.byType(OutlinedButton)).height, 36);
  });
}
