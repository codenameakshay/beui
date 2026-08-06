import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiOtpInput] — mirrors `otp-input.preview.tsx`: the
/// code `123456` verifies, anything else shakes.
Widget otpInputDemo(BuildContext context) => const _OtpDemo();

const _code = '123456';

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
      _status = code == _code ? BeuiOtpStatus.success : BeuiOtpStatus.error;
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: BeuiOtpInput(
      key: ValueKey(_attempt <= 1 ? 0 : _attempt), // replay error shake
      label: 'Verification code',
      hint: 'Enter $_code to verify.',
      successMessage: 'Verified.',
      errorMessage: 'Wrong code, try again.',
      status: _status,
      onChanged: (_) {
        if (_status != BeuiOtpStatus.idle) {
          setState(() => _status = BeuiOtpStatus.idle);
        }
      },
      onComplete: _check,
    ),
  );
}
