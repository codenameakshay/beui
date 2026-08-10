import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiBounceSidebar] — matches the source preview:
/// five nav destinations with a bouncing active-dot indicator.
Widget bounceSidebarDemo(BuildContext context) => const _BounceSidebarDemo();

class _BounceSidebarDemo extends StatefulWidget {
  const _BounceSidebarDemo();

  @override
  State<_BounceSidebarDemo> createState() => _BounceSidebarDemoState();
}

class _BounceSidebarDemoState extends State<_BounceSidebarDemo> {
  String _active = 'components';

  static const _destinations = <BeuiBounceSidebarItem>[
    BeuiBounceSidebarItem(id: 'overview', label: Text('Overview')),
    BeuiBounceSidebarItem(id: 'components', label: Text('Components')),
    BeuiBounceSidebarItem(id: 'motion', label: Text('Motion')),
    BeuiBounceSidebarItem(id: 'templates', label: Text('Templates')),
    BeuiBounceSidebarItem(id: 'changelog', label: Text('Changelog')),
  ];

  @override
  Widget build(BuildContext context) {
    // Source preview: the bare sidebar at `w-52` (208), centred in a
    // `min-h-[360px]` box — no surrounding labels.
    return Center(
      child: SizedBox(
        width: 208,
        child: BeuiBounceSidebar(
          items: _destinations,
          value: _active,
          onChanged: (id) => setState(() => _active = id),
          semanticLabel: 'beUI sections',
        ),
      ),
    );
  }
}
