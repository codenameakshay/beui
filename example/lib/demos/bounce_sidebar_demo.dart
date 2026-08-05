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
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 360, maxWidth: 208),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Active: $_active',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            BeuiBounceSidebar(
              items: _destinations,
              value: _active,
              onChanged: (id) => setState(() => _active = id),
              semanticLabel: 'beUI sections',
            ),
          ],
        ),
      ),
    );
  }
}
