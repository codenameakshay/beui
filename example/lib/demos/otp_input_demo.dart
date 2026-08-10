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
  // Controlled, exactly like the source preview: the parent owns the code and
  // clears the status on any edit, so a re-filled wrong code replays the shake
  // without the input ever losing the digits already typed.
  String _value = '';
  BeuiOtpStatus _status = BeuiOtpStatus.idle;

  @override
  Widget build(BuildContext context) => Center(
    child: BeuiOtpInput(
      label: 'Verification code',
      hint: 'Enter $_code to verify.',
      successMessage: 'Verified.',
      errorMessage: 'Wrong code, try again.',
      value: _value,
      status: _status,
      onChanged: (v) => setState(() {
        _value = v;
        if (_status != BeuiOtpStatus.idle) _status = BeuiOtpStatus.idle;
      }),
      onComplete: (v) => setState(
        () =>
            _status = v == _code ? BeuiOtpStatus.success : BeuiOtpStatus.error,
      ),
    ),
  );
}
