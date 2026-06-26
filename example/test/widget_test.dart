import 'package:beui_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery boots', (tester) async {
    await tester.pumpWidget(const GalleryApp());
    expect(find.textContaining('beUI Gallery'), findsOneWidget);
  });
}
