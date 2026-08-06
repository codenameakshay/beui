import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiInput] — mirrors the source `input.preview.tsx`:
/// an empty email field that errors (shake + message) on invalid input, a
/// password field with an eye toggle in the right slot, and a search field
/// showing the success check draw.
Widget inputDemo(BuildContext context) => const _InputDemo();

class _InputDemo extends StatefulWidget {
  const _InputDemo();

  @override
  State<_InputDemo> createState() => _InputDemoState();
}

class _InputDemoState extends State<_InputDemo> {
  String _email = '';
  String _pass = 'hunter2';
  String _query = 'Ada';
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final emailError = _email.isNotEmpty && !_email.contains('@')
        ? 'Enter a valid email address.'
        : null;

    return ConstrainedBox(
      // Source: `w-full max-w-xs` (320) with `gap-5` (20) between fields.
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiInput(
            label: 'Email',
            placeholder: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            leftIcon: const Icon(LucideIcons.mail),
            value: _email,
            error: emailError,
            onChanged: (v) => setState(() => _email = v),
          ),
          const SizedBox(height: 20),
          BeuiInput(
            label: 'Password',
            value: _pass,
            obscureText: !_show,
            onChanged: (v) => setState(() => _pass = v),
            rightIcon: Semantics(
              button: true,
              label: _show ? 'Hide password' : 'Show password',
              child: GestureDetector(
                onTap: () => setState(() => _show = !_show),
                behavior: HitTestBehavior.opaque,
                child: Icon(_show ? LucideIcons.eye_off : LucideIcons.eye),
              ),
            ),
          ),
          const SizedBox(height: 20),
          BeuiInput(
            label: 'Search',
            leftIcon: const Icon(LucideIcons.search),
            value: _query,
            success: _query.length > 1,
            onChanged: (v) => setState(() => _query = v),
          ),
        ],
      ),
    );
  }
}
