import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

Widget _app(
  num value, {
  int decimals = 0,
  int? pad,
  String? prefix,
  String? suffix,
  bool locale = false,
  bool reduce = false,
  String Function(int value)? format,
  String Function(num roundedValue)? formatNumber,
}) => beuiTestApp(
  SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 28),
      child: BeuiNumberTicker(
        value: value,
        decimals: decimals,
        pad: pad,
        prefix: prefix,
        suffix: suffix,
        locale: locale,
        startOnView: false,
        format: format,
        formatNumber: formatNumber,
      ),
    ),
  ),
  reduce: reduce,
);

Future<void> _pump(
  WidgetTester tester,
  num value, {
  int decimals = 0,
  int? pad,
  String? prefix,
  String? suffix,
  bool locale = false,
  bool reduce = false,
  String Function(int value)? format,
  String Function(num roundedValue)? formatNumber,
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(
    _app(
      value,
      decimals: decimals,
      pad: pad,
      prefix: prefix,
      suffix: suffix,
      locale: locale,
      reduce: reduce,
      format: format,
      formatNumber: formatNumber,
    ),
  );
  await tester.pump();
}

String _semanticsLabel(WidgetTester tester) =>
    tester.getSemantics(find.byType(BeuiNumberTicker)).label;

List<double> _tickerTranslationsY(WidgetTester tester) => tester
    .widgetList<Transform>(
      find.descendant(
        of: find.byType(BeuiNumberTicker),
        matching: find.byType(Transform),
      ),
    )
    .map((transform) => transform.transform.getTranslation().y)
    .toList();

void main() {
  testWidgets('source Math.round ties move toward positive infinity', (
    tester,
  ) async {
    await _pump(tester, 1.25, decimals: 1);
    expect(_semanticsLabel(tester), '1.3');

    await _pump(tester, -1.25, decimals: 1);
    expect(_semanticsLabel(tester), '-1.2');

    await _pump(tester, 2.5);
    expect(_semanticsLabel(tester), '3');

    await _pump(tester, -2.5);
    expect(_semanticsLabel(tester), '-2');
  });

  testWidgets('binary values follow multiply-round-divide, not decimal text', (
    tester,
  ) async {
    await _pump(tester, 1.005, decimals: 2);
    expect(_semanticsLabel(tester), '1.00');

    await _pump(tester, 1.015, decimals: 2);
    expect(_semanticsLabel(tester), '1.01');

    await _pump(tester, 1.2500000000000002, decimals: 1);
    expect(_semanticsLabel(tester), '1.3');

    await _pump(tester, 0.49999999999999994);
    expect(_semanticsLabel(tester), '0');
  });

  testWidgets(
    'negative decimals clamp to zero and positive places stay fixed',
    (tester) async {
      await _pump(tester, 12.3, decimals: -4);
      expect(_semanticsLabel(tester), '12');

      await _pump(tester, 12.3, decimals: 1);
      expect(_semanticsLabel(tester), '12.3');

      await _pump(tester, 12.3, decimals: 2);
      expect(_semanticsLabel(tester), '12.30');
    },
  );

  testWidgets('locale formatting groups and retains fractional places', (
    tester,
  ) async {
    await _pump(tester, 12345.6, decimals: 2, locale: true);
    expect(_semanticsLabel(tester), '12,345.60');
  });

  testWidgets('locale formatting uses decimal rather than binary precision', (
    tester,
  ) async {
    await _pump(tester, 0.1, decimals: 21, locale: true);
    expect(_semanticsLabel(tester), '0.100000000000000000000');

    await _pump(tester, 1e21, decimals: 2, locale: true);
    expect(_semanticsLabel(tester), '999,999,999,999,999,900,000.00');
  });

  testWidgets('locale formatting retains signed zero and infinity symbols', (
    tester,
  ) async {
    await _pump(tester, -0.5, decimals: 0, locale: true);
    expect(_semanticsLabel(tester), '-0');

    await _pump(tester, double.infinity, locale: true);
    expect(_semanticsLabel(tester), '∞');

    await _pump(tester, double.negativeInfinity, locale: true);
    expect(_semanticsLabel(tester), '-∞');
  });

  testWidgets('formatNumber receives source-rounded values', (tester) async {
    final received = <num>[];
    await _pump(
      tester,
      -1.25,
      decimals: 1,
      formatNumber: (rounded) {
        received.add(rounded);
        return 'rounded=$rounded';
      },
    );

    expect(received.last, -1.2);
    expect(_semanticsLabel(tester), 'rounded=-1.2');
  });

  testWidgets('formatNumber wins over legacy and locale formatters', (
    tester,
  ) async {
    final modernValues = <num>[];
    final legacyValues = <int>[];
    await _pump(
      tester,
      1.25,
      decimals: 1,
      locale: true,
      format: (value) {
        legacyValues.add(value);
        return 'legacy';
      },
      formatNumber: (value) {
        modernValues.add(value);
        return 'modern';
      },
    );

    expect(modernValues.last, 1.3);
    expect(legacyValues, isEmpty);
    expect(_semanticsLabel(tester), 'modern');
  });

  testWidgets(
    'legacy formatter keeps Dart integer rounding and ignores places',
    (tester) async {
      final received = <int>[];
      await _pump(
        tester,
        1.25,
        decimals: 2,
        format: (value) {
          received.add(value);
          return 'legacy=$value';
        },
      );
      expect(received.last, 1);
      expect(_semanticsLabel(tester), 'legacy=1');

      await _pump(
        tester,
        -1.5,
        decimals: 1,
        format: (value) {
          received.add(value);
          return 'legacy=$value';
        },
      );
      expect(received.last, -2);
      expect(_semanticsLabel(tester), 'legacy=-2');
    },
  );

  testWidgets('padding follows formatting and affixes wrap the padded text', (
    tester,
  ) async {
    await _pump(
      tester,
      12.3,
      decimals: 1,
      pad: 6,
      prefix: r'$ ',
      suffix: ' USD',
    );
    expect(_semanticsLabel(tester), r'$ 0012.3 USD');
  });

  testWidgets('fixed precision 100 preserves a nontrivial binary fraction', (
    tester,
  ) async {
    await _pump(tester, 0.1, decimals: 100);
    expect(
      _semanticsLabel(tester),
      '0.1000000000000000055511151231257827021181583404541015625000000000000000000000000000000000000000000000',
    );
  });

  testWidgets('built-in precision above 100 throws RangeError', (tester) async {
    await tester.pumpWidget(_app(1, decimals: 101));
    expect(tester.takeException(), isA<RangeError>());

    await tester.pumpWidget(_app(1, decimals: 101, locale: true));
    expect(tester.takeException(), isA<RangeError>());
  });

  testWidgets('custom formatter accepts precision above 100', (tester) async {
    final received = <num>[];
    await _pump(
      tester,
      1.25,
      decimals: 101,
      formatNumber: (value) {
        received.add(value);
        return 'custom';
      },
    );
    expect(received.last, 1.25);
    expect(_semanticsLabel(tester), 'custom');
  });

  testWidgets(
    'custom formatter receives NaN when the source factor overflows',
    (tester) async {
      var receivedNaN = false;
      await _pump(
        tester,
        1.25,
        decimals: 309,
        formatNumber: (value) {
          receivedNaN = value.isNaN;
          return 'overflow';
        },
      );
      expect(receivedNaN, isTrue);
      expect(_semanticsLabel(tester), 'overflow');
    },
  );

  testWidgets('default fixed formatting spells non-finite values literally', (
    tester,
  ) async {
    await _pump(tester, double.nan);
    expect(_semanticsLabel(tester), 'NaN');

    await _pump(tester, double.infinity, decimals: 2);
    expect(_semanticsLabel(tester), 'Infinity');

    await _pump(tester, double.negativeInfinity, decimals: 2);
    expect(_semanticsLabel(tester), '-Infinity');
  });

  testWidgets('fixed formatter uses exponential form at 1e21', (tester) async {
    await _pump(tester, 1e21);
    expect(_semanticsLabel(tester), '1e+21');
  });

  testWidgets('custom formatter receives non-finite source values', (
    tester,
  ) async {
    final received = <num>[];
    await _pump(
      tester,
      double.nan,
      formatNumber: (value) {
        received.add(value);
        return 'not-a-number';
      },
    );
    expect(received.last.isNaN, isTrue);
    expect(_semanticsLabel(tester), 'not-a-number');
  });

  testWidgets('source rounding preserves negative zero for custom callbacks', (
    tester,
  ) async {
    var receivedNegativeZero = false;
    await _pump(
      tester,
      -0.5,
      formatNumber: (value) {
        receivedNegativeZero = value.isNegative && value == 0;
        return 'zero';
      },
    );
    expect(receivedNegativeZero, isTrue);
    expect(_semanticsLabel(tester), 'zero');
  });

  testWidgets('legacy formatter rejects non-finite values', (tester) async {
    await tester.pumpWidget(_app(double.infinity, format: (_) => 'legacy'));
    expect(tester.takeException(), isA<ArgumentError>());
  });

  testWidgets('reduced motion snaps and live value/decimal changes apply', (
    tester,
  ) async {
    await _pump(tester, 2.25, decimals: 1, reduce: true);
    expect(_semanticsLabel(tester), '2.3');
    expect(_tickerTranslationsY(tester), hasLength(2));
    expect(_tickerTranslationsY(tester)[0], closeTo(-2 * 30.8, 0.001));
    expect(_tickerTranslationsY(tester)[1], closeTo(-3 * 30.8, 0.001));

    await tester.pumpWidget(_app(7.25, decimals: 1, reduce: true));
    expect(_semanticsLabel(tester), '7.3');
    expect(_tickerTranslationsY(tester)[0], closeTo(-7 * 30.8, 0.001));
    expect(_tickerTranslationsY(tester)[1], closeTo(-3 * 30.8, 0.001));

    await tester.pumpWidget(_app(7.25, decimals: 0, reduce: true));
    expect(_semanticsLabel(tester), '7');
    expect(_tickerTranslationsY(tester).single, closeTo(-7 * 30.8, 0.001));
  });
}
