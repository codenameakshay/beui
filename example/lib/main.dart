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
];

Widget _switchDemo(BuildContext context) => const _SwitchDemo();

Widget _checkboxDemo(BuildContext context) => const _CheckboxDemo();

Widget _radioDemo(BuildContext context) => const _RadioDemo();

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
                        body: Center(child: Builder(builder: entry.builder)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
