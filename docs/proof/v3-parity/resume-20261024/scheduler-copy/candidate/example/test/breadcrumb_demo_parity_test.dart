import 'package:beui/beui.dart';
import 'package:beui_example/demos/breadcrumb_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets(
    'breadcrumb source metrics survive the reserved navigation area',
    (tester) async {
      await tester.pumpWidget(
        beuiTestApp(
          Builder(builder: breadcrumbDemo),
          fontFamily: 'Geist',
          width: 592,
        ),
      );
      await tester.pumpAndSettle();
      final workspace = find.ancestor(
        of: find.text('Workspace'),
        matching: find.byType(BeuiBreadcrumbLink),
      );
      final next = find.ancestor(
        of: find.text('Breadcrumb'),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(workspace).width, closeTo(109.40625, .05));
      expect(tester.getSize(find.byType(IconButton)), const Size(32, 32));
      expect(tester.getSize(next), const Size(480, 46));
    },
  );
}
