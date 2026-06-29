import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiBouncyAccordion] — a faithful port of beUI's
/// bouncy-accordion preview: a release-workflow list with one row open by
/// default, panels that spring open by morphing height, and rotating chevrons.
Widget bouncyAccordionDemo(BuildContext context) =>
    const _BouncyAccordionDemo();

class _BouncyAccordionDemo extends StatefulWidget {
  const _BouncyAccordionDemo();

  @override
  State<_BouncyAccordionDemo> createState() => _BouncyAccordionDemoState();
}

class _BouncyAccordionDemoState extends State<_BouncyAccordionDemo> {
  // Controlled, seeded to 'calendar' (matches the source preview's
  // defaultValue). Keeping it controlled here doubles as a usage example.
  String? _open = 'calendar';

  static const _items = <BeuiBouncyAccordionItem>[
    BeuiBouncyAccordionItem(
      id: 'brief',
      title: Text('Release Brief'),
      icon: LucideIcons.file_text,
      description: Text(
        'Collect launch notes, owners, and risks in one compact handoff '
        'before the release window opens.',
      ),
    ),
    BeuiBouncyAccordionItem(
      id: 'launch',
      title: Text('Launch Checklist'),
      icon: LucideIcons.shield_check,
      description: Text(
        'Verify copy, links, analytics, rollback steps, and final approvals '
        'without leaving the queue.',
      ),
    ),
    BeuiBouncyAccordionItem(
      id: 'campaign',
      title: Text('Campaign Notes'),
      icon: LucideIcons.radio_tower,
      description: Text(
        'Keep channel-specific notes close to the task while preserving a calm '
        'collapsed list.',
      ),
    ),
    BeuiBouncyAccordionItem(
      id: 'calendar',
      title: Text('Rollout Calendar'),
      icon: LucideIcons.calendar_clock,
      description: Text(
        'Plan announcements, staging checks, reminders, and quiet periods '
        'around the same timeline.',
      ),
    ),
    BeuiBouncyAccordionItem(
      id: 'ship',
      title: Text('Ship Build'),
      icon: LucideIcons.package_check,
      description: Text(
        'Track the current artifact, deploy status, and final sign-off before '
        'marking the release complete.',
      ),
    ),
    BeuiBouncyAccordionItem(
      id: 'archive',
      title: Text('Archive Assets'),
      icon: LucideIcons.folder_kanban,
      description: Text(
        'Move final copy, images, and source files into the campaign folder '
        'once the rollout is done.',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
        child: BeuiBouncyAccordion(
          items: _items,
          value: _open,
          onChanged: (v) => setState(() => _open = v),
        ),
      ),
    );
  }
}
