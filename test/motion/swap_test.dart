import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool reduce = false}) {
  Widget body = SingleChildScrollView(
    child: Center(child: SizedBox(width: 420, child: child)),
  );
  if (reduce) {
    final inner = body;
    body = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner,
      ),
    );
  }
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [BeuiColors.light()]),
    home: Scaffold(body: body),
  );
}

const _chains = [
  BeuiChain(id: 'eth', name: 'Ethereum', symbol: 'Ξ'),
  BeuiChain(id: 'sol', name: 'Solana', symbol: '◎'),
];

const _tokens = [
  BeuiToken(
    id: 'eth-eth',
    symbol: 'ETH',
    name: 'Ether',
    chainId: 'eth',
    balance: 2,
    usd: 2,
    popular: true,
  ),
  BeuiToken(
    id: 'sol-sol',
    symbol: 'SOL',
    name: 'Solana',
    chainId: 'sol',
    balance: 10,
    usd: 1,
    popular: true,
  ),
  BeuiToken(
    id: 'eth-usdc',
    symbol: 'USDC',
    name: 'USD Coin',
    chainId: 'eth',
    balance: 100,
    usd: 1,
  ),
];

Widget _swap({bool reduce = false}) => _wrap(
  const BeuiMultiChainSwap(
    chains: _chains,
    tokens: _tokens,
    defaultFromId: 'eth-eth',
    defaultToId: 'sol-sol',
  ),
  reduce: reduce,
);

void main() {
  group('BeuiMultiChainSwap', () {
    testWidgets('renders header, fields and the quote row', (tester) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Swap'), findsOneWidget);
      expect(find.text('YOU PAY'), findsOneWidget);
      expect(find.text('YOU GET'), findsOneWidget);
      expect(find.text('ETH'), findsWidgets);
      expect(find.text('SOL'), findsWidgets);
      expect(find.text('Rate'), findsOneWidget);
      // usd 2 / usd 1 → 1 ETH ≈ 2 SOL.
      expect(find.textContaining('1 ETH ≈ 2 SOL'), findsOneWidget);
    });

    testWidgets('typing an amount quotes the other side by rate', (
      tester,
    ) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(EditableText).first, '3');
      await tester.pump(const Duration(milliseconds: 600)); // quoting settles
      expect(find.text('6'), findsOneWidget); // 3 ETH × rate 2
    });

    testWidgets('a quoting spinner appears while the quote refreshes', (
      tester,
    ) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byType(EditableText).first, '2');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(RotationTransition), findsWidgets); // spinners
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('the flip button reverses direction', (tester) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.bySemanticsLabel('Reverse direction'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.textContaining('1 SOL ≈ 0.5 ETH'), findsOneWidget);
    });

    testWidgets('Max fills the from-amount with the balance', (tester) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('MAX'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('4'), findsOneWidget); // 2 ETH balance × rate 2
    });

    testWidgets('action button states: empty, insufficient, ready', (
      tester,
    ) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Swap ETH → SOL'), findsOneWidget); // default "1"

      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Enter an amount'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).first, '5');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Insufficient ETH'), findsOneWidget); // balance 2
    });

    testWidgets('the token picker filters and picks; same-token swaps sides', (
      tester,
    ) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      // Open the "from" picker.
      await tester.tap(find.text('ETH').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Search name or paste address'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).last, 'usd');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('USD Coin'), findsOneWidget);
      expect(find.text('Solana'), findsNothing);

      await tester.tap(find.text('USD Coin'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('USDC'), findsWidgets); // from side now USDC
      expect(find.text('Search name or paste address'), findsNothing);
    });

    testWidgets('destination row validates addresses', (tester) async {
      await tester.pumpWidget(_swap());
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Send to different address'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));

      final destField = find.byType(EditableText).last;
      await tester.enterText(destField, 'nope');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(LucideIcons.x), findsWidgets); // clear affordance

      await tester.enterText(
        destField,
        '0x1234567890abcdef1234567890abcdef12345678',
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.textContaining('Swap + Send to 0x1234'), findsOneWidget);
    });

    testWidgets('reduced motion opens the picker with a fade', (tester) async {
      await tester.pumpWidget(_swap(reduce: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('ETH').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Search name or paste address'), findsOneWidget);
    });
  });
}
