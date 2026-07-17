// The routed content pages: section index grid, component/block detail, and a
// simple prose doc page.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'shell.dart';
import 'theme_scope.dart';
import 'widgets.dart';

EdgeInsets _pagePadding(double width) =>
    EdgeInsets.fromLTRB(width < 600 ? 20 : 40, 32, width < 600 ? 20 : 40, 96);

int _gridColumns(double width) {
  if (width >= 980) return 4;
  if (width >= 720) return 3;
  if (width >= 480) return 2;
  return 1;
}

// ---------------------------------------------------------------------------
// Index page (card grid)
// ---------------------------------------------------------------------------

/// The grid of cards for a section, split into "New" and "All".
class IndexPage extends StatelessWidget {
  const IndexPage({super.key, required this.section});
  final ExploreSection section;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    final entries = entriesFor(section);
    final newEntries = entries.where((e) => e.isNew).toList();

    return Padding(
      padding: _pagePadding(width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Breadcrumb(crumbs: [(section.title, null)]),
          const SizedBox(height: 16),
          PageHeading(section.title),
          const SizedBox(height: 10),
          Text(
            section.subtitle,
            style: TextStyle(fontSize: 16, color: colors.mutedForeground),
          ),
          const SizedBox(height: 40),
          if (newEntries.isNotEmpty) ...[
            const SectionLabel('New'),
            const SizedBox(height: 16),
            _CardGrid(entries: newEntries),
            const SizedBox(height: 44),
          ],
          SectionLabel('All ${section.title}'),
          const SizedBox(height: 16),
          _CardGrid(entries: entries),
        ],
      ),
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.entries});
  final List<ExploreEntry> entries;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 16.0;
        final cols = _gridColumns(constraints.maxWidth);
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        final controller = ExplorerController.of(context);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final e in entries)
              SizedBox(
                width: itemWidth,
                height: 168,
                child: ExplorerCard(
                  entry: e,
                  onTap: () => controller.openEntry(e),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Detail page
// ---------------------------------------------------------------------------

enum _DetailTab { preview, usage, code }

/// The component/block detail page: breadcrumb, heading, tabs and a right rail.
class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.entry});
  final ExploreEntry entry;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  _DetailTab _tab = _DetailTab.preview;

  @override
  void didUpdateWidget(DetailPage old) {
    super.didUpdateWidget(old);
    if (old.entry.slug != widget.entry.slug) _tab = _DetailTab.preview;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    final controller = ExplorerController.of(context);
    final entry = widget.entry;
    final showRail = width >= ExplorerMetrics.onThisPageBreakpoint;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Breadcrumb(
          crumbs: [
            (entry.section.title, () => controller.openIndex(entry.section)),
            (entry.title, null),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PageHeading(entry.title)),
            if (entry.isNew) ...[const SizedBox(width: 12), const NewBadge()],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          entry.blurb,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 24),
        _SegmentedTabs(value: _tab, onChanged: (t) => setState(() => _tab = t)),
        const SizedBox(height: 20),
        _TabBody(entry: entry, tab: _tab),
      ],
    );

    return Padding(
      padding: _pagePadding(width),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: main),
          if (showRail) ...[
            const SizedBox(width: 40),
            SizedBox(
              width: ExplorerMetrics.onThisPage,
              child: _OnThisPage(
                entry: entry,
                tab: _tab,
                onTab: (t) => setState(() => _tab = t),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.value, required this.onChanged});
  final _DetailTab value;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.foreground.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _DetailTab.values)
            _Segment(
              label: switch (t) {
                _DetailTab.preview => 'Preview',
                _DetailTab.usage => 'Usage',
                _DetailTab.code => 'Code',
              },
              active: t == value,
              onTap: () => onChanged(t),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? colors.foreground.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active ? colors.background : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.entry, required this.tab});
  final ExploreEntry entry;
  final _DetailTab tab;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      _DetailTab.preview => PreviewSurface(
        child: entry.ported
            ? Builder(builder: entry.builder!)
            : _NotPorted(entry: entry),
      ),
      _DetailTab.usage => _UsageBlock(entry: entry),
      _DetailTab.code => _CodeTab(entry: entry),
    };
  }
}

class _NotPorted extends StatelessWidget {
  const _NotPorted({required this.entry});
  final ExploreEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.hammer, size: 28, color: colors.mutedForeground),
        const SizedBox(height: 16),
        Text(
          'Not yet ported',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 320,
          child: Text(
            'This component exists on beui.dev but hasn\'t been ported to the '
            'Flutter package yet, so there\'s no live demo to show.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: colors.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}

class _UsageBlock extends StatelessWidget {
  const _UsageBlock({required this.entry});
  final ExploreEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add the package',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        const CodeBlock('flutter pub add beui'),
        const SizedBox(height: 24),
        Text(
          'Import and use',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.foreground,
          ),
        ),
        const SizedBox(height: 12),
        const CodeBlock(
          "import 'package:beui/beui.dart';\n\n"
          '// Every component is an exported widget prefixed `Beui`.\n'
          '// Colors come from the theme extension, never hardcoded:\n'
          'final colors = Theme.of(context).extension<BeuiColors>()!;',
        ),
        const SizedBox(height: 16),
        Text(
          'Motion follows the shared spring/easing tokens in '
          'lib/src/tokens/motion.dart and honours reduced-motion.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _CodeTab extends StatelessWidget {
  const _CodeTab({required this.entry});
  final ExploreEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final demoFile =
        'example/lib/demos/${entry.slug.replaceAll('-', '_')}_demo.dart';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This demo lives in the example gallery:',
          style: TextStyle(fontSize: 14, color: colors.mutedForeground),
        ),
        const SizedBox(height: 12),
        CodeBlock(demoFile),
        const SizedBox(height: 24),
        Text(
          'The component itself is published under lib/src/motion/ in the '
          'beui package. Read the source for its full API — the demo above '
          'exercises the same public widget you would use in your app.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// A monospace code block surface.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});
  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.55,
          color: colors.foreground.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

class _OnThisPage extends StatelessWidget {
  const _OnThisPage({
    required this.entry,
    required this.tab,
    required this.onTab,
  });
  final ExploreEntry entry;
  final _DetailTab tab;
  final ValueChanged<_DetailTab> onTab;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final controller = ExplorerController.of(context);
    final related = entriesFor(
      entry.section,
    ).where((e) => e.slug != entry.slug).take(6).toList();

    Widget railLink(String label, bool active, VoidCallback onTap) => InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            color: active ? colors.foreground : colors.mutedForeground,
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('On this page'),
        const SizedBox(height: 8),
        railLink(
          'Preview',
          tab == _DetailTab.preview,
          () => onTab(_DetailTab.preview),
        ),
        railLink(
          'Usage',
          tab == _DetailTab.usage,
          () => onTab(_DetailTab.usage),
        ),
        railLink('Code', tab == _DetailTab.code, () => onTab(_DetailTab.code)),
        const SizedBox(height: 24),
        const SectionLabel('Related'),
        const SizedBox(height: 8),
        for (final e in related)
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => controller.openEntry(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                e.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.mutedForeground),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Simple prose doc page
// ---------------------------------------------------------------------------

/// A minimal prose page (used for the AI Agents entry).
class DocPage extends StatelessWidget {
  const DocPage({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: _pagePadding(width),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeading(title),
            const SizedBox(height: 20),
            Text(
              body,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
