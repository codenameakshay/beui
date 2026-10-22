import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAlert].
Widget alertDemo(BuildContext context) => const _AlertDemo();

class _AlertDemo extends StatefulWidget {
  const _AlertDemo();

  @override
  State<_AlertDemo> createState() => _AlertDemoState();
}

class _AlertDemoState extends State<_AlertDemo> {
  BeuiAlertVariant _variant = BeuiAlertVariant.info;
  bool _open = true;
  final FocusNode _showFocus = FocusNode();

  @override
  void dispose() {
    _showFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = switch (_variant) {
      BeuiAlertVariant.default_ => (
        'Notice',
        'A little heads up',
        'Your changes are saved automatically as you work.',
      ),
      BeuiAlertVariant.info => (
        'Info',
        'A little heads up',
        'Your changes are saved automatically as you work.',
      ),
      BeuiAlertVariant.success => (
        'Success',
        'All set',
        'Your changes have been saved.',
      ),
      BeuiAlertVariant.warning => (
        'Warning',
        'Almost at the limit',
        "You're getting close to your storage limit. Free up some space before uploading more files.",
      ),
      BeuiAlertVariant.destructive => (
        'Error',
        'Something went wrong',
        "We couldn't save your changes. Give it another try.",
      ),
    };
    final variants = BeuiAlertVariant.values;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BeuiTabs<BeuiAlertVariant>(
            value: _variant,
            variant: BeuiTabsVariant.segment,
            onChanged: (value) => setState(() {
              _variant = value;
              _open = true;
            }),
            tabs: [
              for (final variant in variants)
                BeuiTab(value: variant, label: Text(_label(variant))),
            ],
          ),
          const SizedBox(height: 24),
          BeuiAlert(
            variant: _variant,
            open: _open,
            onOpenChange: (value) => setState(() => _open = value),
            returnFocus: _showFocus,
            children: [
              const BeuiAlertIcon(),
              BeuiAlertContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BeuiAlertTitle(child: Text(copy.$2)),
                    BeuiAlertDescription(child: Text(copy.$3)),
                    if (_variant == BeuiAlertVariant.destructive)
                      BeuiAlertAction(
                        child: BeuiButton(
                          size: BeuiButtonSize.sm,
                          variant: BeuiButtonVariant.outline,
                          onPressed: () => setState(() {
                            _variant = BeuiAlertVariant.success;
                            _open = true;
                          }),
                          child: const Text('Try again'),
                        ),
                      ),
                  ],
                ),
              ),
              const BeuiAlertClose(),
            ],
          ),
          const SizedBox(height: 16),
          BeuiButton(
            focusNode: _showFocus,
            variant: BeuiButtonVariant.ghost,
            size: BeuiButtonSize.sm,
            onPressed: _open ? null : () => setState(() => _open = true),
            child: const Text('Show alert'),
          ),
          const SizedBox(height: 2),
          Text(copy.$1, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _label(BeuiAlertVariant variant) => switch (variant) {
    BeuiAlertVariant.default_ => 'Default',
    BeuiAlertVariant.info => 'Info',
    BeuiAlertVariant.success => 'Success',
    BeuiAlertVariant.warning => 'Warning',
    BeuiAlertVariant.destructive => 'Error',
  };
}
