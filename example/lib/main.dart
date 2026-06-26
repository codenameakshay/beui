import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

void main() => runApp(const GalleryApp());

/// The beUI component gallery — one entry per component as they are ported.
/// This is the living showcase and the render target for golden tests.
class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'beUI Gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true)
          .copyWith(extensions: [BeuiColors.light()]),
      darkTheme: ThemeData.dark(useMaterial3: true)
          .copyWith(extensions: [BeuiColors.dark()]),
      home: const GalleryHome(),
    );
  }
}

/// Registry of gallery entries. Add a [GalleryEntry] here as each component
/// lands so it shows up in the list and golden tests can target it.
const _entries = <GalleryEntry>[
  GalleryEntry('Switch', _switchDemo),
  GalleryEntry('Checkbox', _checkboxDemo),
  GalleryEntry('Radio', _radioDemo),
  GalleryEntry('Tabs', _tabsDemo),
  GalleryEntry('Button', _buttonDemo),
];

Widget _switchDemo(BuildContext context) => const _SwitchDemo();

Widget _checkboxDemo(BuildContext context) => const _CheckboxDemo();

Widget _radioDemo(BuildContext context) => const _RadioDemo();

Widget _tabsDemo(BuildContext context) => const _TabsDemo();

Widget _buttonDemo(BuildContext context) => const _ButtonDemo();

/// Exercises button variants, sizes, the stateful lifecycle, and magnetic pull.
class _ButtonDemo extends StatefulWidget {
  const _ButtonDemo();

  @override
  State<_ButtonDemo> createState() => _ButtonDemoState();
}

class _ButtonDemoState extends State<_ButtonDemo> {
  BeuiButtonState _state = BeuiButtonState.idle;

  void _runLifecycle() async {
    setState(() => _state = BeuiButtonState.loading);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.success);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _state = BeuiButtonState.idle);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          BeuiButton(
            onPressed: () {},
            child: _row(const [Text('Continue'), Icon(LucideIcons.arrow_right)]),
          ),
          BeuiButton(
            variant: BeuiButtonVariant.secondary,
            onPressed: () {},
            child: _row(const [Icon(LucideIcons.download), Text('Download')]),
          ),
          BeuiButton(
            variant: BeuiButtonVariant.outline,
            onPressed: () {},
            child: const Text('Outline'),
          ),
          BeuiButton(
            variant: BeuiButtonVariant.ghost,
            onPressed: () {},
            child: const Text('Ghost'),
          ),
        ]),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            BeuiButton(
                size: BeuiButtonSize.sm, onPressed: () {}, child: const Text('Small')),
            BeuiButton(
                size: BeuiButtonSize.md, onPressed: () {}, child: const Text('Medium')),
            BeuiButton(
                size: BeuiButtonSize.lg, onPressed: () {}, child: const Text('Large')),
            BeuiButton(
              size: BeuiButtonSize.icon,
              variant: BeuiButtonVariant.outline,
              onPressed: () {},
              child: const Icon(LucideIcons.trash_2),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          BeuiButton(ripple: true, onPressed: () {}, child: const Text('Ripple')),
          BeuiButton(
            variant: BeuiButtonVariant.outline,
            onPressed: () {},
            child: const Text('Tap me'),
          ),
        ]),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          BeuiStatefulButton(
            label: 'Save changes',
            icon: LucideIcons.arrow_right,
            state: _state,
            onPressed: _runLifecycle,
          ),
          BeuiButton(
            variant: BeuiButtonVariant.outline,
            onPressed: () {},
            child: const Text('Submit'),
          ),
        ]),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          BeuiMagneticButton(
            onPressed: () {},
            child: _row(const [Text('Hover me'), Icon(LucideIcons.arrow_right)]),
          ),
          BeuiMagneticButton(
            variant: BeuiButtonVariant.outline,
            strength: 0.15,
            onPressed: () {},
            child: const Text('Subtle pull'),
          ),
          BeuiMagneticButton(
            variant: BeuiButtonVariant.outline,
            strength: 0.4,
            onPressed: () {},
            child: const Text('Strong pull'),
          ),
        ]),
      ],
    );
  }

  /// A min-width row with the source button's 8px gap between children.
  Widget _row(List<Widget> children) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      );
}

/// Exercises all three tab variants and a fading content panel.
class _TabsDemo extends StatefulWidget {
  const _TabsDemo();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo> {
  String _tab = 'activity';

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const BeuiTab(
        value: 'overview',
        label: Text('Overview'),
        content: Text('Project overview and summary.'),
      ),
      const BeuiTab(
        value: 'activity',
        label: Text('Activity'),
        content: Text('Recent activity feed.'),
      ),
      const BeuiTab(
        value: 'settings',
        label: Text('Settings'),
        content: Text('Configuration and preferences.'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final variant in BeuiTabsVariant.values) ...[
          BeuiTabs<String>(
            variant: variant,
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
            tabs: variant == BeuiTabsVariant.pill ? tabs : _barOnly(tabs),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  List<BeuiTab<String>> _barOnly(List<BeuiTab<String>> tabs) =>
      [for (final t in tabs) BeuiTab(value: t.value, label: t.label)];
}

/// Exercises the radio group's gliding selection dot.
class _RadioDemo extends StatefulWidget {
  const _RadioDemo();

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _plan = 'pro';

  @override
  Widget build(BuildContext context) {
    return BeuiRadioGroup<String>(
      value: _plan,
      onChanged: (v) => setState(() => _plan = v),
      items: const [
        BeuiRadioItem(value: 'starter', label: 'Starter — free'),
        BeuiRadioItem(value: 'pro', label: 'Pro — \$12/mo'),
        BeuiRadioItem(value: 'team', label: 'Team — \$29/mo'),
        BeuiRadioItem(value: 'legacy', label: 'Legacy plan', enabled: false),
      ],
    );
  }
}

/// Exercises the checkbox's states, including indeterminate and disabled.
class _CheckboxDemo extends StatefulWidget {
  const _CheckboxDemo();

  @override
  State<_CheckboxDemo> createState() => _CheckboxDemoState();
}

class _CheckboxDemoState extends State<_CheckboxDemo> {
  bool _terms = true;
  bool _updates = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiCheckbox(
          value: _terms,
          label: 'Accept terms and conditions',
          onChanged: (v) => setState(() => _terms = v),
        ),
        const SizedBox(height: 16),
        BeuiCheckbox(
          value: _updates,
          label: 'Email me product updates',
          onChanged: (v) => setState(() => _updates = v),
        ),
        const SizedBox(height: 16),
        BeuiCheckbox(
          value: true,
          indeterminate: true,
          label: 'Select all (partial)',
          onChanged: (_) {},
        ),
        const SizedBox(height: 16),
        BeuiCheckbox(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// Exercises the switch's variants and states (the gallery doubles as visual QA).
class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo();

  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _notifications = true;
  bool _sounds = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BeuiSwitch(
          value: _notifications,
          label: 'Enable notifications',
          onChanged: (v) => setState(() => _notifications = v),
        ),
        const SizedBox(height: 16),
        BeuiSwitch(
          value: _sounds,
          label: 'Sounds',
          onChanged: (v) => setState(() => _sounds = v),
        ),
        const SizedBox(height: 16),
        BeuiSwitch(
          value: true,
          enabled: false,
          label: 'Disabled',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

class GalleryEntry {
  const GalleryEntry(this.title, this.builder);
  final String title;
  final WidgetBuilder builder;
}

class GalleryHome extends StatelessWidget {
  const GalleryHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('beUI Gallery · $beuiVersion')),
      body: _entries.isEmpty
          ? const Center(
              child: Text('No components ported yet — add entries in main.dart.'),
            )
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final entry = _entries[i];
                return ListTile(
                  title: Text(entry.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: Text(entry.title)),
                        body: SafeArea(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Builder(builder: entry.builder),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
