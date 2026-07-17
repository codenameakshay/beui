import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiInput] — idle, focus, error (with shake + message),
/// success (with check draw), disabled, and icon slots.
Widget inputDemo(BuildContext context) => const _InputDemo();

class _InputDemo extends StatefulWidget {
  const _InputDemo();

  @override
  State<_InputDemo> createState() => _InputDemoState();
}

class _InputDemoState extends State<_InputDemo> {
  String _email = '';
  String? _emailError;

  void _validate(String v) {
    setState(() {
      _email = v;
      _emailError = v.isEmpty || v.contains('@')
          ? null
          : 'Enter a valid email address.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiInput(
            label: 'Email',
            placeholder: 'you@example.com',
            leftIcon: const Icon(LucideIcons.mail),
            value: _email,
            error: _emailError,
            onChanged: _validate,
          ),
          const SizedBox(height: 24),
          const BeuiInput(
            label: 'Username',
            defaultValue: 'saurabh',
            success: true,
            leftIcon: Icon(LucideIcons.at_sign),
          ),
          const SizedBox(height: 24),
          const BeuiInput(
            label: 'Search',
            placeholder: 'Type to search…',
            leftIcon: Icon(LucideIcons.search),
            rightIcon: Icon(LucideIcons.command),
          ),
          const SizedBox(height: 24),
          const BeuiInput(
            label: 'Disabled',
            defaultValue: 'Read only',
            enabled: false,
          ),
        ],
      ),
    );
  }
}
