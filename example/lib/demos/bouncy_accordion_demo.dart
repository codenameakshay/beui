import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery demo for [BeuiBouncyAccordion] — a faithful port of beUI's
/// bouncy-accordion preview: a release-workflow list with one row open by
/// default, panels that spring open by morphing height, and rotating chevrons.
///
/// Uncontrolled (`defaultValue: 'calendar'`), exactly like the source preview —
/// so the row's open state updates synchronously on tap and rapid double-taps
/// toggle correctly (a controlled parent's `value` only updates after its own
/// rebuild, which drops the second of two fast taps).
Widget bouncyAccordionDemo(BuildContext context) =>
    const _BouncyAccordionDemo();

class _BouncyAccordionDemo extends StatelessWidget {
  const _BouncyAccordionDemo();

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
    // The source preview reserves a fixed 480px-tall box (`h-[480px]`) inside a
    // centred `max-w-sm` column and top-anchors the accordion in it. That box is
    // load-bearing, not decoration: with it, opening a row only pushes the rows
    // *below* it: without it the stack re-centres on every toggle and the rows
    // above the one you tapped slide up too.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
        child: const SizedBox(
          height: 480, // h-[480px]
          child: Align(
            alignment: Alignment.topCenter,
            child: BeuiBouncyAccordion(
              items: _items,
              defaultValue: 'calendar',
            ),
          ),
        ),
      ),
    );
  }
}
