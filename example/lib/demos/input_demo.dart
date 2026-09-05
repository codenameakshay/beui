import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Gallery route for [BeuiInput] — mirrors the source `input.preview.tsx`:
/// an empty email field that errors (shake + message) on invalid input, a
/// password field with an eye toggle in the right slot, and a search field
/// showing the success check draw.
///
/// The email field also demonstrates [BeuiInput.errorNonce]: pressing
/// **Validate** on an already-invalid address replays the shake, so a repeated
/// rejection still reads as a rejection.
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
  int _submits = 0;

  @override
  Widget build(BuildContext context) {
    final emailError = _email.isNotEmpty && !_email.contains('@')
        ? 'Enter a valid email address.'
        : null;

    // Align first: ConstrainedBox enforces against the incoming constraints,
    // so under a tight full-stage width it is widened straight past `maxWidth`
    // and the fields render full-bleed instead of the source's `max-w-xs`.
    // Align loosens; it is a no-op when the parent is already loose.
    return Align(
      child: ConstrainedBox(
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
              // Platform autofill and a "next" key, both now reachable through
              // the public API.
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              leftIcon: const Icon(LucideIcons.mail),
              value: _email,
              error: emailError,
              errorNonce: _submits,
              onChanged: (v) => setState(() => _email = v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: BeuiButton(
                variant: BeuiButtonVariant.secondary,
                size: BeuiButtonSize.sm,
                onPressed: () => setState(() => _submits++),
                child: const Text('Validate'),
              ),
            ),
            const SizedBox(height: 20),
            BeuiInput(
              label: 'Password',
              value: _pass,
              obscureText: !_show,
              autofillHints: const [AutofillHints.password],
              // The soft keyboard's suggestion bar has no business here.
              enableSuggestions: false,
              onChanged: (v) => setState(() => _pass = v),
              rightIcon: _RevealToggle(
                revealed: _show,
                onToggle: () => setState(() => _show = !_show),
              ),
            ),
            const SizedBox(height: 20),
            BeuiInput(
              label: 'Search',
              leftIcon: const Icon(LucideIcons.search),
              value: _query,
              textInputAction: TextInputAction.search,
              success: _query.length > 1,
              onChanged: (v) => setState(() => _query = v),
            ),
          ],
        ),
      ),
    );
  }
}

/// The password show/hide toggle.
///
/// The gallery is the de-facto documentation, so this models the full
/// interactive contract rather than the bare `GestureDetector` it replaces:
/// [FocusableActionDetector] gives it a tab stop, Enter/Space activation, a
/// hover cursor and a focus highlight, and the slot is sized to a real target
/// instead of a 16px glyph.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.revealed, required this.onToggle});

  final bool revealed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final label = revealed ? 'Hide password' : 'Show password';

    return DemoPressable(
      semanticLabel: label,
      onPressed: onToggle,
      builder: (context, focusVisible) => Container(
        // Fills the pill's height, so the target is 28x44 rather than the
        // glyph's 16x16.
        width: 28,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focusVisible ? colors.focusRing : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(revealed ? LucideIcons.eye_off : LucideIcons.eye),
      ),
    );
  }
}
