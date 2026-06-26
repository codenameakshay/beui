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
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const GalleryHome(),
    );
  }
}

/// Registry of gallery entries. Add a [GalleryEntry] here as each component
/// lands so it shows up in the list and golden tests can target it.
const _entries = <GalleryEntry>[
  // GalleryEntry('Switch', _buildSwitchDemo),
];

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
