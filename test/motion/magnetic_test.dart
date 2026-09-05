import 'package:beui/beui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support.dart';

void main() {
  testWidgets('pulls toward the pointer on hover (strength 0.35)', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(const BeuiMagnetic(child: SizedBox(width: 40, height: 40))),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    final center = tester.getCenter(find.byType(BeuiMagnetic));
    // 10px right of center (inside the 40x40 box), at strength 0.35 → target
    // offset (3.5, 0).
    await gesture.moveTo(center + const Offset(10, 0));
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(BeuiMagnetic),
        matching: find.byType(Transform),
      ),
    );
    expect(
      transform.transform.getTranslation().x,
      moreOrLessEquals(3.5, epsilon: 0.5),
    );

    // Leaving springs it back to rest.
    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    final settled = tester.widget<Transform>(
      find.descendant(
        of: find.byType(BeuiMagnetic),
        matching: find.byType(Transform),
      ),
    );
    expect(
      settled.transform.getTranslation().x,
      moreOrLessEquals(0, epsilon: 0.01),
    );
  });

  testWidgets('is inert under reduced motion', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        const BeuiMagnetic(child: SizedBox(width: 40, height: 40)),
        reduce: true,
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    final center = tester.getCenter(find.byType(BeuiMagnetic));
    await gesture.moveTo(center + const Offset(20, 0));
    await tester.pumpAndSettle();

    // Reduced motion skips MouseRegion/MotionBuilder entirely and renders the
    // child as-is — no Transform.translate ever mounts.
    expect(
      find.descendant(
        of: find.byType(BeuiMagnetic),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });
}
