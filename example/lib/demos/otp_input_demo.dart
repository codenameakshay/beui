import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiOtpInput] — the code `421907` verifies, anything
/// else shakes.
Widget otpInputDemo(BuildContext context) => const _OtpDemo();

class _OtpDemo extends StatefulWidget {
  const _OtpDemo();

  @override
  State<_OtpDemo> createState() => _OtpDemoState();
}

class _OtpDemoState extends State<_OtpDemo> {
  BeuiOtpStatus _status = BeuiOtpStatus.idle;
  int _attempt = 0;

  void _check(String code) {
    setState(() {
      _attempt++;
      _status = code == '421907' ? BeuiOtpStatus.success : BeuiOtpStatus.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiOtpInput(
            key: ValueKey(_attempt <= 1 ? 0 : _attempt), // replay error shake
            label: 'Verification code',
            hint: 'Try 421907',
            successMessage: 'Verified — welcome back.',
            errorMessage: 'That code didn’t match. Try 421907.',
            status: _status,
            onChanged: (_) {
              if (_status != BeuiOtpStatus.idle) {
                setState(() => _status = BeuiOtpStatus.idle);
              }
            },
            onComplete: _check,
          ),
          const SizedBox(height: 32),
          BeuiOtpInput(
            length: 4,
            label: 'Masked PIN',
            hint: '4 digits, dots only',
            mask: true,
          ),
        ],
      ),
    );
  }
}
