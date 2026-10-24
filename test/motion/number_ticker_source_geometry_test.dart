import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _mono = TextStyle(fontFamily: 'Ticker Test Geist Mono', fontSize: 12);

Future<void> _mount(
  WidgetTester tester, {
  TextStyle ambient = _mono,
  TextStyle? style,
  double scale = 1,
  String? prefix,
  String? suffix,
  String Function(int)? format,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: DefaultTextStyle(
          style: ambient,
          child: Center(
            child: BeuiNumberTicker(
              value: 123456,
              style: style,
              prefix: prefix,
              suffix: suffix,
              format: format,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Size> _slots(WidgetTester tester) => find
    .byType(ClipRect)
    .evaluate()
    .map((element) => (element.renderObject! as RenderBox).size)
    .toList();

double _baseline(RenderBox box) =>
    box.localToGlobal(Offset.zero).dy +
    box.getDryBaseline(box.constraints, TextBaseline.alphabetic)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Ticker Test Geist Mono')
      ..addFont(
        File(
          'example/assets/fonts/GeistMono-Regular.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  });

  testWidgets('Geist Mono 12px uses source 7.2px zero advance slots', (
    tester,
  ) async {
    await _mount(tester);
    final painter = TextPainter(
      text: const TextSpan(text: '0', style: _mono),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, closeTo(7.2, 0.001));
    painter.dispose();
    expect(_slots(tester), hasLength(6));
    for (final slot in _slots(tester)) {
      expect(slot.width, closeTo(7.2, 0.001));
      expect(slot.height, closeTo(13.2, 0.001));
    }
    expect(
      tester.getSize(find.byType(BeuiNumberTicker)).width,
      closeTo(43.2, 0.001),
    );
  });

  testWidgets('partial style inherits ambient size and keeps glyphs in slots', (
    tester,
  ) async {
    await _mount(
      tester,
      ambient: _mono.copyWith(fontSize: 20, height: 2),
      style: const TextStyle(color: Color(0xff123456)),
    );
    for (final slot in _slots(tester)) {
      expect(slot.width, closeTo(12, 0.001));
      expect(slot.height, closeTo(22, 0.001));
    }
    final paragraphs = tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    );
    for (final paragraph in paragraphs) {
      final style = paragraph.text.style!;
      expect(style.fontSize, 20);
      expect(style.fontFamily, _mono.fontFamily);
      expect(style.color, const Color(0xff123456));
      expect(paragraph.size.height, lessThanOrEqualTo(22.001));
    }
  });

  testWidgets('digits share a baseline with mixed separators and affixes', (
    tester,
  ) async {
    await _mount(
      tester,
      ambient: _mono.copyWith(height: 2),
      prefix: r'$',
      suffix: ' kg',
      format: (_) => '-1,2.3',
    );
    final row = tester.renderObject<RenderFlex>(find.byType(Row));
    final baselines = <double>[];
    row.visitChildren((child) => baselines.add(_baseline(child as RenderBox)));
    for (final baseline in baselines) {
      expect(baseline, closeTo(baselines.first, 0.001));
    }
    // The displayed target glyph has the same baseline as the static text.
    final target = tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byKey(const ValueKey('d-4')),
            matching: find.byType(RichText),
          )
          .last,
    );
    // Column's last glyph is 9; translation puts 1 at the visible baseline.
    expect(_baseline(target) - 8 * 13.2, closeTo(baselines.first, 0.01));
  });

  testWidgets(
    'text scaling scales advances, slots and roll distance together',
    (tester) async {
      await _mount(tester, scale: 2);
      for (final slot in _slots(tester)) {
        expect(slot.width, closeTo(14.4, 0.001));
        expect(slot.height, closeTo(26.4, 0.001));
      }
      final transforms = tester.widgetList<Transform>(find.byType(Transform));
      expect(
        transforms.last.transform.getTranslation().y,
        closeTo(-6 * 26.4, 0.001),
      );
    },
  );

  testWidgets(
    'inherit false and explicit font feature overrides are respected',
    (tester) async {
      await _mount(
        tester,
        ambient: _mono.copyWith(fontSize: 30, letterSpacing: 5),
        style: _mono.copyWith(
          inherit: false,
          fontFeatures: [
            const FontFeature('tnum', 0),
            const FontFeature.slashedZero(),
          ],
        ),
      );
      expect(_slots(tester).first.width, closeTo(7.2, 0.001));
      final style = tester
          .renderObject<RenderParagraph>(find.byType(RichText).first)
          .text
          .style!;
      expect(style.letterSpacing, isNull);
      expect(style.fontFeatures, contains(const FontFeature.slashedZero()));
      expect(
        style.fontFeatures!.lastWhere((f) => f.feature == 'tnum').value,
        0,
      );
    },
  );

  testWidgets('tabular figures are supplied without dropping caller features', (
    tester,
  ) async {
    await _mount(
      tester,
      style: _mono.copyWith(fontFeatures: [const FontFeature.slashedZero()]),
    );
    final style = tester
        .renderObject<RenderParagraph>(find.byType(RichText).first)
        .text
        .style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontFeatures, contains(const FontFeature.slashedZero()));
  });
}
