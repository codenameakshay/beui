// The explorer shell: fixed top bar + left sidebar + routed content area.
//
// A persistent chrome (never unmounts) that mirrors beui.dev's docs layout.
// Navigation is in-shell state (a sealed [ExplorerRoute]) rather than the
// Navigator, so the sidebar and top bar stay put exactly like the site.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'catalog.dart';
import 'guides_page.dart';
import 'pages.dart';
import 'search.dart';
import 'theme_scope.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

/// A destination inside the shell.
sealed class ExplorerRoute {
  const ExplorerRoute();
}

/// A section index (the card grid for Components or Blocks).
class IndexRoute extends ExplorerRoute {
  const IndexRoute(this.section);
  final ExploreSection section;
}

/// A component/block detail page.
class DetailRoute extends ExplorerRoute {
  const DetailRoute(this.entry);
  final ExploreEntry entry;
}

/// The Motion Guides long-form page.
class GuidesRoute extends ExplorerRoute {
  const GuidesRoute();
}

/// A simple prose doc page (e.g. AI Agents).
class DocRoute extends ExplorerRoute {
  const DocRoute(this.title, this.body);
  final String title;
  final String body;
}

/// Inherited navigation handle available to the whole subtree.
class ExplorerController extends InheritedWidget {
  const ExplorerController({
    super.key,
    required this.route,
    required this.go,
    required super.child,
  });

  final ExplorerRoute route;
  final ValueChanged<ExplorerRoute> go;

  void openEntry(ExploreEntry e) => go(DetailRoute(e));
  void openIndex(ExploreSection s) => go(IndexRoute(s));
  void openGuides() => go(const GuidesRoute());

  static ExplorerController of(BuildContext context) {
    final c = context.dependOnInheritedWidgetOfExactType<ExplorerController>();
    assert(c != null, 'ExplorerController not found');
    return c!;
  }

  @override
  bool updateShouldNotify(ExplorerController old) => route != old.route;
}

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------

/// The root shell widget.
class ExplorerShell extends StatefulWidget {
  const ExplorerShell({super.key});

  @override
  State<ExplorerShell> createState() => _ExplorerShellState();
}

class _ExplorerShellState extends State<ExplorerShell> {
  ExplorerRoute _route = const IndexRoute(ExploreSection.components);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _contentScroll = ScrollController();

  void _go(ExplorerRoute r) {
    setState(() => _route = r);
    // Reset scroll on navigation and close the mobile drawer if open.
    if (_contentScroll.hasClients) _contentScroll.jumpTo(0);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _contentScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= ExplorerMetrics.sidebarBreakpoint;

    return ExplorerController(
      route: _route,
      go: _go,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: colors.background,
        drawer: showSidebar
            ? null
            : Drawer(
                backgroundColor: colors.background,
                width: ExplorerMetrics.sidebar,
                child: SafeArea(child: ExplorerSidebar(route: _route)),
              ),
        body: Column(
          children: [
            ExplorerTopBar(
              route: _route,
              showMenuButton: !showSidebar,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Divider(height: 1, thickness: 1, color: colors.border),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showSidebar) ...[
                    SizedBox(
                      width: ExplorerMetrics.sidebar,
                      child: ExplorerSidebar(route: _route),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colors.border,
                    ),
                  ],
                  Expanded(
                    child: _Content(route: _route, scroll: _contentScroll),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the routed content region.
class _Content extends StatelessWidget {
  const _Content({required this.route, required this.scroll});
  final ExplorerRoute route;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final child = switch (route) {
      IndexRoute(:final section) => IndexPage(
        key: ValueKey('index-${section.slug}'),
        section: section,
      ),
      DetailRoute(:final entry) => DetailPage(
        key: ValueKey('detail-${entry.slug}'),
        entry: entry,
      ),
      GuidesRoute() => const GuidesPage(key: ValueKey('guides')),
      DocRoute(:final title, :final body) => DocPage(
        key: ValueKey('doc-$title'),
        title: title,
        body: body,
      ),
    };
    return Scrollbar(
      controller: scroll,
      child: SingleChildScrollView(
        controller: scroll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ExplorerMetrics.content,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

/// The fixed top navigation bar.
class ExplorerTopBar extends StatelessWidget {
  const ExplorerTopBar({
    super.key,
    required this.route,
    required this.showMenuButton,
    required this.onMenu,
  });

  final ExplorerRoute route;
  final bool showMenuButton;
  final VoidCallback onMenu;

  ExploreSection? get _activeSection => switch (route) {
    IndexRoute(:final section) => section,
    DetailRoute(:final entry) => entry.section,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final controller = ExplorerController.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // Progressive disclosure so the bar never overflows at any width.
    final showNav = width >= 900;
    final searchAsField = width >= 760;
    final showGithub = width >= 680;

    return SizedBox(
      height: ExplorerMetrics.topBar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (showMenuButton) ...[
              _IconChip(icon: LucideIcons.menu, tooltip: 'Menu', onTap: onMenu),
              const SizedBox(width: 8),
            ],
            const _Wordmark(),
            if (showNav) ...[
              const SizedBox(width: 24),
              _NavTab(
                label: 'Components',
                active: _activeSection == ExploreSection.components,
                onTap: () => controller.openIndex(ExploreSection.components),
              ),
              _NavTab(
                label: 'Agents',
                active: _activeSection == ExploreSection.agents,
                onTap: () => controller.openIndex(ExploreSection.agents),
              ),
              _NavTab(
                label: 'Blocks',
                active: _activeSection == ExploreSection.blocks,
                onTap: () => controller.openIndex(ExploreSection.blocks),
              ),
              _NavTab(
                label: 'Guides',
                active: route is GuidesRoute,
                onTap: controller.openGuides,
              ),
            ],
            const Spacer(),
            if (searchAsField) const _SearchField() else const _SearchIcon(),
            const SizedBox(width: 8),
            const _ThemePicker(),
            const SizedBox(width: 8),
            const _BrightnessToggle(),
            if (showGithub) ...[
              const SizedBox(width: 8),
              _GithubButton(colors: colors),
            ],
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () =>
          ExplorerController.of(context).openIndex(ExploreSection.components),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: colors.foreground,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.background, width: 2.4),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              'beUI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
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
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: active ? colors.foreground : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showExplorerSearch(context),
      child: Container(
        width: 260,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.foreground.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 15, color: colors.mutedForeground),
            const SizedBox(width: 8),
            Text(
              'Search',
              style: TextStyle(fontSize: 14, color: colors.mutedForeground),
            ),
            const Spacer(),
            _Kbd(colors: colors, text: '⌘K'),
          ],
        ),
      ),
    );
  }
}

class _SearchIcon extends StatelessWidget {
  const _SearchIcon();
  @override
  Widget build(BuildContext context) => _IconChip(
    icon: LucideIcons.search,
    tooltip: 'Search',
    onTap: () => showExplorerSearch(context),
  );
}

class _Kbd extends StatelessWidget {
  const _Kbd({required this.colors, required this.text});
  final BeuiColors colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.foreground.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

class _BrightnessToggle extends StatelessWidget {
  const _BrightnessToggle();

  @override
  Widget build(BuildContext context) {
    final scope = ThemeScope.of(context);
    final isDark = scope.brightness == Brightness.dark;
    return _IconChip(
      icon: isDark ? LucideIcons.sun : LucideIcons.moon,
      tooltip: isDark ? 'Light mode' : 'Dark mode',
      onTap: scope.toggleBrightness,
    );
  }
}

/// A color-theme picker popup showing each [BeuiColorTheme] swatch.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final scope = ThemeScope.of(context);
    return PopupMenuButton<BeuiColorTheme>(
      tooltip: 'Color theme',
      position: PopupMenuPosition.under,
      color: colors.popover,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border),
      ),
      onSelected: scope.setColorTheme,
      itemBuilder: (context) => [
        for (final theme in BeuiColorTheme.values)
          PopupMenuItem(
            value: theme,
            height: 40,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.foreground,
                    fontWeight: scope.colorTheme == theme
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (scope.colorTheme == theme) ...[
                  const Spacer(),
                  Icon(LucideIcons.check, size: 14, color: colors.foreground),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          LucideIcons.palette,
          size: 16,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

class _GithubButton extends StatelessWidget {
  const _GithubButton({required this.colors});
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.star, size: 15, color: colors.foreground),
          const SizedBox(width: 8),
          Text(
            'GitHub',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// A square bordered icon button used across the top bar.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final button = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: colors.mutedForeground),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

/// The left navigation sidebar.
class ExplorerSidebar extends StatelessWidget {
  const ExplorerSidebar({super.key, required this.route});
  final ExplorerRoute route;

  String? get _activeSlug => switch (route) {
    DetailRoute(:final entry) => entry.slug,
    _ => null,
  };

  bool get _onComponentsHome =>
      route is IndexRoute &&
      (route as IndexRoute).section == ExploreSection.components;

  @override
  Widget build(BuildContext context) {
    final controller = ExplorerController.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _SidebarHeader(label: 'Intro'),
        _SidebarItem(
          label: 'Home',
          active: _onComponentsHome,
          onTap: () => controller.openIndex(ExploreSection.components),
        ),
        const SizedBox(height: 20),
        _SidebarHeader(label: 'Guides'),
        _SidebarItem(
          label: 'Motion Guides',
          active: route is GuidesRoute,
          onTap: controller.openGuides,
        ),
        const SizedBox(height: 20),
        _SidebarHeader(label: 'Components', count: kComponents.length),
        for (final e in kComponents)
          _SidebarItem(
            label: e.title,
            isNew: e.isNew,
            active: _activeSlug == e.slug,
            onTap: () => controller.openEntry(e),
          ),
        const SizedBox(height: 20),
        _SidebarHeader(label: 'AI Agents', count: kAgents.length),
        for (final e in kAgents)
          _SidebarItem(
            label: e.title,
            isNew: e.isNew,
            active: _activeSlug == e.slug,
            onTap: () => controller.openEntry(e),
          ),
        const SizedBox(height: 20),
        _SidebarHeader(label: 'Blocks', count: kBlocks.length),
        for (final e in kBlocks)
          _SidebarItem(
            label: e.title,
            isNew: e.isNew,
            active: _activeSlug == e.slug,
            onTap: () => controller.openEntry(e),
          ),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.label, this.count});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: colors.mutedForeground,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: colors.foreground.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.label,
    required this.active,
    required this.onTap,
    this.isNew = false,
  });
  final String label;
  final bool active;
  final bool isNew;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final bg = widget.active
        ? colors.foreground.withValues(alpha: 0.06)
        : _hover
        ? colors.foreground.withValues(alpha: 0.035)
        : Colors.transparent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: widget.active
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: widget.active
                          ? colors.foreground
                          : _hover
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                  ),
                ),
                if (widget.isNew) const NewBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
