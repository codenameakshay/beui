// Motion Guides — a long-form doc page mirroring beui.dev/docs/motion-patterns,
// written against this library's own motion tokens (lib/src/tokens/motion.dart).
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 600 ? 20.0 : 40.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 40, pad, 96),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Eyebrow('beUI motion system'),
            const SizedBox(height: 16),
            Text(
              'Motion that explains, not distracts.',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
                height: 1.1,
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'A practical guide to deciding when something should move, picking '
              'the right token, and shipping motion that stays fast, coherent '
              'and accessible.',
              style: TextStyle(
                fontSize: 17,
                height: 1.55,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 56),

            // Decision framework -------------------------------------------
            _SectionHead(
              eyebrow: 'Decision framework',
              title: 'Four questions before motion',
              lede:
                  'The best animation decision is often made before you touch '
                  'a duration or a spring value.',
            ),
            const SizedBox(height: 24),
            _FrameworkGrid(
              items: const [
                (
                  '01',
                  'Check frequency',
                  'Repeated actions should feel nearly instant. Save expressive '
                      'motion for moments a user sees only occasionally.',
                ),
                (
                  '02',
                  'Name the purpose',
                  'Motion should explain space, confirm input, show state or '
                      'soften a change. Decoration alone is not enough.',
                ),
                (
                  '03',
                  'Choose the physics',
                  'Ease-out for entrances, ease-in-out for movement, linear for '
                      'progress, and springs for gestures.',
                ),
                (
                  '04',
                  'Design the fallback',
                  'Reduced motion keeps useful opacity and colour feedback while '
                      'removing travel, scale and parallax.',
                ),
              ],
            ),
            const SizedBox(height: 56),

            // Tokens --------------------------------------------------------
            _SectionHead(
              eyebrow: 'Motion tokens',
              title: 'One language everywhere',
              lede:
                  'beUI keeps deliberate motion in shared tokens. Choose by '
                  'purpose so components feel related without moving identically.',
            ),
            const SizedBox(height: 24),
            _TokenTable(
              rows: const [
                (
                  'beuiEaseOut',
                  'cubic-bezier(0.16, 1, 0.3, 1)',
                  'Entrances and exits — respond immediately, then settle.',
                ),
                (
                  'beuiEaseInOut',
                  'cubic-bezier(0.77, 0, 0.175, 1)',
                  'Objects already on screen accelerating and decelerating.',
                ),
                (
                  'beuiSpringPress',
                  'stiffness 500 · damping 30 · mass 0.6',
                  'Fast, weighted feedback for buttons and pressable surfaces.',
                ),
                (
                  'beuiSpringLayout',
                  'stiffness 360 · damping 32 · mass 0.6',
                  'Shared surfaces and indicators that glide between positions.',
                ),
                (
                  'beuiSpringPanel',
                  'stiffness 420 · damping 40 · mass 0.5',
                  'Overshoot-free arrivals for modals and sheets.',
                ),
                (
                  'beuiSpringMouse',
                  'stiffness 200 · damping 15 · mass 0.3',
                  'Loose cursor-follow physics for magnetic pull and tilt.',
                ),
              ],
            ),
            const SizedBox(height: 56),

            // Timing --------------------------------------------------------
            _SectionHead(
              eyebrow: 'Timing',
              title: 'Fast enough to feel immediate',
              lede:
                  'Duration depends on size, distance and frequency. These '
                  'ranges are starting points, not targets to hit mechanically.',
            ),
            const SizedBox(height: 24),
            _TimingTable(
              rows: const [
                ('Press feedback', '100–160ms', 'Immediate and physical'),
                ('Tooltip / popover', '125–200ms', 'Quick, origin-aware'),
                ('Dropdown / select', '150–250ms', 'Responsive, no waiting'),
                ('Modal / drawer', '200–500ms', 'Enough time to explain space'),
              ],
            ),
            const SizedBox(height: 20),
            _Callout(
              'Under 300ms is the default for interface motion. Longer motion '
              'belongs to explanatory demos, deliberate gestures and large '
              'spatial changes.',
            ),
            const SizedBox(height: 56),

            // Accessibility -------------------------------------------------
            _SectionHead(
              eyebrow: 'Accessibility',
              title: 'Reduced motion is a state, not an afterthought',
              lede:
                  'Every component routes its tokens through one resolver '
                  '(motionFor). Movement collapses to none; opacity and colour '
                  'feedback is always preserved.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: colors.mutedForeground,
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({
    required this.eyebrow,
    required this.title,
    required this.lede,
  });
  final String eyebrow;
  final String title;
  final String lede;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(eyebrow),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          lede,
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _FrameworkGrid extends StatelessWidget {
  const _FrameworkGrid({required this.items});
  final List<(String, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final twoUp = c.maxWidth >= 640;
        const gap = 16.0;
        final w = twoUp ? (c.maxWidth - gap) / 2 : c.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (n, title, body) in items)
              SizedBox(
                width: w,
                child: _FrameworkCard(number: n, title: title, body: body),
              ),
          ],
        );
      },
    );
  }
}

class _FrameworkCard extends StatelessWidget {
  const _FrameworkCard({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TokenTable extends StatelessWidget {
  const _TokenTable({required this.rows});
  final List<(String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rows[i].$1,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12.5,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rows[i].$3,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimingTable extends StatelessWidget {
  const _TimingTable({required this.rows});
  final List<(String, String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[i].$2,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      rows[i].$3,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.foreground.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          height: 1.55,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}
