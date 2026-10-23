import 'package:beui/beui.dart';
import 'package:beui_example/demos/card_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support.dart';

void main() {
  testWidgets('document text activates its owning checkbox once', (
    tester,
  ) async {
    await tester.pumpWidget(
      beuiTestApp(
        SingleChildScrollView(
          child: SizedBox(width: 768, child: Builder(builder: cardDemo)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
      isTrue,
    );
    await tester.tap(find.text('Signed contract'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
      isFalse,
    );
    await tester.tap(find.byType(BeuiCheckbox).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<BeuiCheckbox>(find.byType(BeuiCheckbox).first).value,
      isTrue,
    );
  });

  testWidgets('studio demo retains source copy and image URL', (tester) async {
    await tester.pumpWidget(
      beuiTestApp(
        SingleChildScrollView(
          child: SizedBox(width: 768, child: Builder(builder: cardDemo)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Desks for 12 people, booked for the March offsite.'),
      findsOneWidget,
    );
    expect(find.text('View booking'), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=720&q=80',
    );
  });
}
