import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'button/base.dart';
import 'button/stateful.dart';
import 'checkbox.dart';
import 'input.dart';

enum BeuiSignUpStatus { idle, loading, success, error }

@immutable
class BeuiSignUpValues {
  const BeuiSignUpValues({
    this.name = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.terms = false,
  });

  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final bool terms;

  BeuiSignUpValues copyWith({
    String? name,
    String? email,
    String? password,
    String? confirmPassword,
    bool? terms,
  }) => BeuiSignUpValues(
    name: name ?? this.name,
    email: email ?? this.email,
    password: password ?? this.password,
    confirmPassword: confirmPassword ?? this.confirmPassword,
    terms: terms ?? this.terms,
  );
}

@immutable
class BeuiSignUpErrors {
  const BeuiSignUpErrors({
    this.name,
    this.email,
    this.password,
    this.confirmPassword,
    this.terms,
  });

  final String? name;
  final String? email;
  final String? password;
  final String? confirmPassword;
  final String? terms;

  bool get hasErrors =>
      name != null ||
      email != null ||
      password != null ||
      confirmPassword != null ||
      terms != null;
}

const _emailPattern = r'^[^\s@]+@[^\s@]+\.[^\s@]+$';
const _minimumPasswordLength = 8;
const _strengthLabels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];

// Framer duration 0.3s, bounce 0 → ω=2π/duration and ζ=1−bounce.
const _passwordRevealSpring = SpringMotion(
  SpringDescription(mass: 1, stiffness: 438.65, damping: 41.89),
);

int beuiPasswordStrength(String password) {
  if (password.length < _minimumPasswordLength) return 0;

  var score = 1;
  if (password.length >= 12) score++;
  if (password.length >= 16) score++;
  final classes = [
    RegExp(r'[a-z]'),
    RegExp(r'[A-Z]'),
    RegExp(r'\d'),
    RegExp(r'[^A-Za-z0-9]'),
  ].where((pattern) => pattern.hasMatch(password)).length;
  if (classes >= 3) score++;
  return score.clamp(0, 4);
}

BeuiSignUpErrors _defaultValidation(BeuiSignUpValues values) {
  String? name;
  String? email;
  String? password;
  String? confirmPassword;
  String? terms;
  if (values.name.trim().isEmpty) name = 'Enter your name.';
  if (values.email.trim().isEmpty) {
    email = 'Enter your email.';
  } else if (!RegExp(_emailPattern).hasMatch(values.email)) {
    email = "That doesn't look like an email address.";
  }
  if (values.password.isEmpty) {
    password = 'Choose a password.';
  } else if (values.password.length < _minimumPasswordLength) {
    password = 'Use at least $_minimumPasswordLength characters.';
  }
  if (values.confirmPassword.isEmpty) {
    confirmPassword = 'Confirm your password.';
  } else if (values.confirmPassword != values.password) {
    confirmPassword = "Passwords don't match.";
  }
  if (!values.terms) terms = 'Accept the terms to continue.';
  return BeuiSignUpErrors(
    name: name,
    email: email,
    password: password,
    confirmPassword: confirmPassword,
    terms: terms,
  );
}

class BeuiSignUpForm extends StatefulWidget {
  const BeuiSignUpForm({
    this.values,
    this.defaultValues = const BeuiSignUpValues(),
    this.onValuesChange,
    this.onSubmit,
    this.validate,
    this.status,
    this.errorMessage,
    this.title = 'Create your account',
    this.description = 'Start building in under a minute.',
    this.submitLabel = 'Create account',
    this.footer,
    this.strengthMeter = true,
    super.key,
  });

  final BeuiSignUpValues? values;
  final BeuiSignUpValues defaultValues;
  final ValueChanged<BeuiSignUpValues>? onValuesChange;
  final FutureOr<void> Function(BeuiSignUpValues)? onSubmit;
  final BeuiSignUpErrors Function(BeuiSignUpValues)? validate;
  final BeuiSignUpStatus? status;
  final String? errorMessage;
  final String title;
  final String description;
  final String submitLabel;
  final Widget? footer;
  final bool strengthMeter;

  @override
  State<BeuiSignUpForm> createState() => _BeuiSignUpFormState();
}

class _BeuiSignUpFormState extends State<BeuiSignUpForm> {
  late BeuiSignUpValues _values = widget.values ?? widget.defaultValues;
  BeuiSignUpStatus _internalStatus = BeuiSignUpStatus.idle;
  final Set<String> _touched = {};
  final _focusNodes = <String, FocusNode>{};
  bool _revealPassword = false;

  BeuiSignUpValues get _currentValues => widget.values ?? _values;
  BeuiSignUpStatus get _currentStatus => widget.status ?? _internalStatus;

  @override
  void initState() {
    super.initState();
    for (final field in ['name', 'email', 'password', 'confirmPassword']) {
      final node = FocusNode();
      node.addListener(() {
        if (!node.hasFocus) _touch(field);
      });
      _focusNodes[field] = node;
    }
  }

  @override
  void didUpdateWidget(covariant BeuiSignUpForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values == null && widget.values != null) {
      _values = widget.values!;
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _touch(String field) {
    if (_touched.add(field)) setState(() {});
  }

  void _setValues(BeuiSignUpValues values) {
    if (widget.values == null) {
      setState(() {
        _values = values;
        if (widget.status == null &&
            (_internalStatus == BeuiSignUpStatus.success ||
                _internalStatus == BeuiSignUpStatus.error)) {
          _internalStatus = BeuiSignUpStatus.idle;
        }
      });
    }
    widget.onValuesChange?.call(values);
  }

  Future<void> _submit() async {
    setState(() {
      _touched.addAll([
        'name',
        'email',
        'password',
        'confirmPassword',
        'terms',
      ]);
    });
    final values = _currentValues;
    final errors = (widget.validate ?? _defaultValidation)(values);
    if (errors.hasErrors || widget.onSubmit == null) return;
    if (widget.status == null) {
      setState(() => _internalStatus = BeuiSignUpStatus.loading);
    }
    try {
      await widget.onSubmit!(values);
      if (mounted && widget.status == null) {
        setState(() => _internalStatus = BeuiSignUpStatus.success);
      }
    } catch (_) {
      if (mounted && widget.status == null) {
        setState(() => _internalStatus = BeuiSignUpStatus.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final values = _currentValues;
    final errors = (widget.validate ?? _defaultValidation)(values);
    final status = _currentStatus;
    final busy = status == BeuiSignUpStatus.loading;
    String? shown(String field, String? error) =>
        _touched.contains(field) ? error : null;
    bool valid(String field, String? error, String value) =>
        _touched.contains(field) && error == null && value.isNotEmpty;

    Widget textField({
      required String keyName,
      required String label,
      required String value,
      required String placeholder,
      required IconData icon,
      required ValueChanged<String> onChanged,
      String? error,
      bool success = false,
      bool obscure = false,
      TextInputType? keyboardType,
      Iterable<String>? autofillHints,
      Widget? rightIcon,
    }) {
      final input = BeuiInput(
        key: ValueKey(keyName),
        label: label,
        value: value,
        onChanged: onChanged,
        onSubmitted: (_) {
          const next = {
            'name': 'email',
            'email': 'password',
            'password': 'confirmPassword',
          };
          final nextField = next[keyName];
          if (nextField == null) {
            _submit();
          } else {
            FocusScope.of(context).requestFocus(_focusNodes[nextField]);
          }
        },
        focusNode: _focusNodes[keyName],
        placeholder: placeholder,
        error: shown(keyName, error),
        success: success,
        enabled: !busy,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints?.toList(),
        textInputAction: keyName == 'confirmPassword'
            ? TextInputAction.done
            : TextInputAction.next,
        leftIcon: Icon(icon, size: 16),
        rightIcon: rightIcon,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 90),
            child: Align(alignment: Alignment.topCenter, child: input),
          ),
        ],
      );
    }

    final strength = beuiPasswordStrength(values.password);
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 384),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20),
                textField(
                  keyName: 'name',
                  label: 'Name',
                  value: values.name,
                  placeholder: 'Ada Lovelace',
                  icon: LucideIcons.user,
                  autofillHints: [AutofillHints.name],
                  error: errors.name,
                  success: valid('name', errors.name, values.name),
                  onChanged: (value) =>
                      _setValues(values.copyWith(name: value)),
                ),
                const SizedBox(height: 4),
                textField(
                  keyName: 'email',
                  label: 'Email',
                  value: values.email,
                  placeholder: 'you@example.com',
                  icon: LucideIcons.mail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: [AutofillHints.email],
                  error: errors.email,
                  success: valid('email', errors.email, values.email),
                  onChanged: (value) =>
                      _setValues(values.copyWith(email: value)),
                ),
                const SizedBox(height: 4),
                textField(
                  keyName: 'password',
                  label: 'Password',
                  value: values.password,
                  placeholder: 'At least 8 characters',
                  icon: LucideIcons.lock,
                  obscure: !_revealPassword,
                  autofillHints: [AutofillHints.newPassword],
                  error: errors.password,
                  onChanged: (value) =>
                      _setValues(values.copyWith(password: value)),
                  rightIcon: MergeSemantics(
                    child: Semantics(
                      button: true,
                      label: _revealPassword
                          ? 'Hide password'
                          : 'Show password',
                      child: IconButton(
                        tooltip: _revealPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => _revealPassword = !_revealPassword,
                              ),
                        icon: _PasswordRevealGlyph(revealed: _revealPassword),
                      ),
                    ),
                  ),
                ),
                if (widget.strengthMeter && values.password.isNotEmpty)
                  _SpringEntrance(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: List.generate(
                                4,
                                (index) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: index == 3 ? 0 : 6,
                                    ),
                                    child: _StrengthSegment(
                                      index: index,
                                      filled: index < strength,
                                      color: strength <= 1
                                          ? colors.destructive
                                          : strength == 2
                                          ? colors.warning
                                          : colors.success,
                                      track: colors.mutedForeground.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Password strength: ${_strengthLabels[strength]}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: colors.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                textField(
                  keyName: 'confirmPassword',
                  label: 'Confirm password',
                  value: values.confirmPassword,
                  placeholder: 'Re-enter your password',
                  icon: LucideIcons.lock,
                  obscure: !_revealPassword,
                  autofillHints: [AutofillHints.newPassword],
                  error: errors.confirmPassword,
                  success: valid(
                    'confirmPassword',
                    errors.confirmPassword,
                    values.confirmPassword,
                  ),
                  onChanged: (value) =>
                      _setValues(values.copyWith(confirmPassword: value)),
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'I agree to the Terms and Privacy Policy',
                  child: Row(
                    children: [
                      BeuiCheckbox(
                        value: values.terms,
                        enabled: !busy,
                        onChanged: (value) {
                          _setValues(values.copyWith(terms: value));
                          _touch('terms');
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: busy
                              ? null
                              : () {
                                  _setValues(
                                    values.copyWith(terms: !values.terms),
                                  );
                                  _touch('terms');
                                },
                          child: const Text(
                            'I agree to the Terms and Privacy Policy',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (shown('terms', errors.terms) case final message?)
                  _AnimatedMessage(
                    message: message,
                    color: colors.destructive,
                    alert: true,
                  ),
                if (widget.errorMessage case final message?) ...[
                  const SizedBox(height: 12),
                  _AnimatedMessage(
                    message: message,
                    color: colors.destructive,
                    alert: true,
                  ),
                ],
                const SizedBox(height: 20),
                Semantics(
                  hint: widget.errorMessage,
                  child: BeuiStatefulButton(
                    label: widget.submitLabel,
                    size: BeuiButtonSize.lg,
                    state: switch (status) {
                      BeuiSignUpStatus.idle => BeuiButtonState.idle,
                      BeuiSignUpStatus.loading => BeuiButtonState.loading,
                      BeuiSignUpStatus.success => BeuiButtonState.success,
                      BeuiSignUpStatus.error => BeuiButtonState.error,
                    },
                    loadingText: 'Creating account',
                    successText: 'Account created',
                    errorText: 'Try again',
                    onPressed: _submit,
                  ),
                ),
                if (widget.footer != null) ...[
                  const SizedBox(height: 20),
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: colors.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                    child: widget.footer!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMessage extends StatelessWidget {
  const _AnimatedMessage({
    required this.message,
    required this.color,
    required this.alert,
  });

  final String message;
  final Color color;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: alert,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: _SpringEntrance(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}

class _StrengthSegment extends StatelessWidget {
  const _StrengthSegment({
    required this.index,
    required this.filled,
    required this.color,
    required this.track,
  });

  final int index;
  final bool filled;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    Widget segment(double progress) => SizedBox(
      height: 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: track,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Transform.scale(
            key: ValueKey('strength-segment-$index-fill'),
            alignment: Alignment.centerLeft,
            scaleX: progress,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );

    final target = filled ? 1.0 : 0.0;
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    if (motion is NoMotion) return segment(target);
    return SingleMotionBuilder(
      value: target,
      from: 0,
      motion: motion,
      builder: (context, progress, _) => segment(progress),
    );
  }
}

class _SpringEntrance extends StatelessWidget {
  const _SpringEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(context, beuiSpringLayout, isMovement: true);
    if (motion is NoMotion) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 140),
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: child,
      );
    }
    return SingleMotionBuilder(
      value: 1,
      from: 0,
      motion: motion,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * -4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: (1 - progress) * 4,
              sigmaY: (1 - progress) * 4,
            ),
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _PasswordRevealGlyph extends StatelessWidget {
  const _PasswordRevealGlyph({required this.revealed});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final motion = motionFor(context, _passwordRevealSpring, isMovement: true);
    final icon = Icon(
      revealed ? LucideIcons.eye_off : LucideIcons.eye,
      size: 16,
    );
    if (motion is NoMotion) return icon;
    return SingleMotionBuilder(
      key: ValueKey(revealed),
      value: 1,
      from: 0,
      motion: motion,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}
