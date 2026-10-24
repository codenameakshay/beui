import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

void main() {
  testWidgets(
    'review: a surviving wrapped route stays clickable during reflow',
    (tester) async {
      var showFirst = true;
      var activations = 0;
      late StateSetter update;
      await tester.pumpWidget(
        beuiTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeuiBreadcrumbList(
                maxItems: null,
                children: [
                  if (showFirst)
                    const BeuiBreadcrumbItem(
                      key: ValueKey('first'),
                      child: SizedBox(width: 100, height: 32),
                    ),
                  BeuiBreadcrumbItem(
                    key: const ValueKey('survivor'),
                    child: SizedBox(
                      width: 100,
                      height: 32,
                      child: BeuiBreadcrumbLink(
                        onPressed: () => activations++,
                        child: const Text('Kept route'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          width: 180,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kept route'));
      expect(activations, 1);
      update(() => showFirst = false);
      await tester.pump();
      await tester.tapAt(tester.getCenter(find.text('Kept route')));
      final duringReflow = activations;
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kept route'));
      expect(activations, duringReflow + 1);
      expect(duringReflow, 2);
    },
  );
}
