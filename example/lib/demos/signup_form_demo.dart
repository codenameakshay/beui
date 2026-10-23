import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

Widget signupFormDemo(BuildContext context) => const _SignUpFormDemo();

class _SignUpFormDemo extends StatefulWidget {
  const _SignUpFormDemo();

  @override
  State<_SignUpFormDemo> createState() => _SignUpFormDemoState();
}

class _SignUpFormDemoState extends State<_SignUpFormDemo> {
  String? _error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: BeuiSignUpForm(
      description: 'Sign up with taken@example.com to see the failure state.',
      errorMessage: _error,
      onSubmit: (values) async {
        setState(() => _error = null);
        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (values.email.toLowerCase().startsWith('taken@')) {
          setState(() => _error = 'That email is already registered.');
          throw StateError('Email already registered');
        }
      },
      footer: Text.rich(
        TextSpan(
          text: 'Already have an account? ',
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: BeuiColors.resolve(context).foreground,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationThickness: 1,
                  ),
                ),
                child: const Text('Sign in'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
