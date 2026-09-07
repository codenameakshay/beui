import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

const _accounts = [
  BeuiWalletAccount(
    id: 'main',
    name: 'Main Wallet',
    address: '0x8f3Cb1a29e4D7c6F1B2a3E9d0C4b5A6f7D8e9C0b',
  ),
  BeuiWalletAccount(
    id: 'trading',
    name: 'Trading',
    address: '0x1a2B3c4D5e6F7a8B9c0D1e2F3a4B5c6D7e8F9a0B',
  ),
  BeuiWalletAccount(
    id: 'cold',
    name: 'Cold Storage',
    address: '0x9F8e7D6c5B4a3E2d1C0b9A8f7E6d5C4b3A2e1F0d',
  ),
];

const _recent = ['vitalik.eth', 'Uniswap', 'Send to Trading'];

Widget _app({
  double balance = 12480.32,
  double? defaultChange = 124.5,
  bool hasNotifications = false,
  bool reduce = false,
  ValueChanged<String>? onAccountChange,
  VoidCallback? onSend,
  ValueChanged<String>? onSearchSubmit,
}) {
  final card = BeuiWalletCard(
    accounts: _accounts,
    balance: balance,
    defaultChange: defaultChange,
    searchRecent: _recent,
    hasNotifications: hasNotifications,
    onAccountChange: onAccountChange,
    onSend: onSend,
    onSearchSubmit: onSearchSubmit,
  );
  return beuiTestApp(card, reduce: reduce);
}

void main() {
  group('BeuiWalletCard account switcher', () {
    testWidgets('account panel grows from its trigger when opening', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Main Wallet'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The overlay is mounted on this frame. It must still be between the
      // trigger and its final header-wide rect; mounting at progress 1 would
      // make the panel already full width here.
      final surface = find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ClipRRect),
      );
      expect(surface, findsOneWidget);
      final openingWidth = tester.getSize(surface).width;
      await tester.pumpAndSettle();
      final settledWidth = tester.getSize(surface).width;
      expect(openingWidth, lessThan(settledWidth));
    });

    for (final reduce in [false, true]) {
      testWidgets('trigger morphs open, revealing the account list'
          '${reduce ? " (reduced motion)" : ""}', (tester) async {
        await tester.pumpWidget(_app(reduce: reduce));
        await tester.pumpAndSettle();

        // Closed: only the trigger label is on-stage (list is
        // offstage-measured).
        expect(find.text('Cold Storage'), findsNothing);

        await tester.tap(find.text('Main Wallet'));
        await tester.pumpAndSettle();

        expect(find.text('Cold Storage'), findsOneWidget);
      });
    }

    testWidgets('selecting an account fires onAccountChange and closes', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(_app(onAccountChange: (id) => picked = id));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Main Wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cold Storage'));
      await tester.pumpAndSettle();

      expect(picked, 'cold');
      // Panel closed again → list row gone.
      expect(find.text('Trading'), findsNothing);
    });
  });

  group('BeuiWalletCard search bar', () {
    testWidgets('recent searches remain tappable across the leftward morph', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        _app(onSearchSubmit: (value) => submitted = value),
      );
      await tester.pumpAndSettle();

      final trigger = tester.getRect(find.byIcon(LucideIcons.search));
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();

      final recent = tester.getRect(find.text('vitalik.eth'));
      // The search surface grows left from its right-side trigger. This point
      // is inside the visible recent row but left of the trigger's old
      // follower bounds, so it exercises the panel's full hit region.
      await tester.tapAt(
        Offset((recent.left + trigger.left) / 2, recent.center.dy),
      );
      await tester.pump();

      expect(submitted, 'vitalik.eth');
    });

    testWidgets('icon morphs into a bar exposing recent searches', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('vitalik.eth'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();

      expect(find.text('vitalik.eth'), findsWidgets);
    });
  });

  group('BeuiWalletCard balance', () {
    testWidgets('eye toggle masks the balance', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text(r'$12,480.32'), findsOneWidget);
      expect(find.text('*****'), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.eye));
      await tester.pumpAndSettle();

      expect(find.text('*****'), findsOneWidget);
    });

    testWidgets('shows the balance and an initial delta pill', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.trending_up), findsOneWidget);
    });
  });

  group('BeuiWalletCard actions', () {
    testWidgets('tapping Send invokes the callback', (tester) async {
      var sent = false;
      await tester.pumpWidget(_app(onSend: () => sent = true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(sent, isTrue);
    });
  });

  testWidgets('rest-state golden', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BeuiWalletCard),
      matchesGoldenFile('goldens/beui_wallet_card.png'),
    );
  });
}
