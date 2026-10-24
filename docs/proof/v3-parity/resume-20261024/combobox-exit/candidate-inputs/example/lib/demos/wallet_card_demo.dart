import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiWalletCard] — the composed wallet overview card with a
/// morphing account switcher + search bar, a rolling balance, and a spring
/// actions row. Mirrors the source `wallet-card.preview.tsx`.
Widget walletCardDemo(BuildContext context) => const _WalletCardDemo();

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

const _recentSearches = [
  'vitalik.eth',
  '0xA0b8…6EB4',
  'Uniswap',
  'Send to Trading',
];

class _WalletCardDemo extends StatefulWidget {
  const _WalletCardDemo();

  @override
  State<_WalletCardDemo> createState() => _WalletCardDemoState();
}

class _WalletCardDemoState extends State<_WalletCardDemo> {
  final _rng = math.Random();
  double _balance = 12480.32;

  void _simulate() {
    final sign = _rng.nextBool() ? 1 : -1;
    final delta = sign * (50 + _rng.nextDouble() * 400);
    setState(() => _balance = (_balance + delta).clamp(0, double.infinity));
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiWalletCard(
          accounts: _accounts,
          balance: _balance,
          defaultChange: 124.5,
          searchRecent: _recentSearches,
          hasNotifications: true,
        ),
        const SizedBox(height: 16), // gap-4
        // Source preview uses the library's own ghost/sm button, not a
        // Material TextButton — muted-foreground label at text-xs.
        BeuiButton(
          variant: BeuiButtonVariant.ghost,
          size: BeuiButtonSize.sm,
          onPressed: _simulate,
          child: const Text('Simulate balance change'),
        ),
      ],
    ),
  );
}
