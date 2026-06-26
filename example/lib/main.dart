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
];

Widget _switchDemo(BuildContext context) => const _SwitchDemo();

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
