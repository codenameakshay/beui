import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';

// ---------------------------------------------------------------------------
// Motion tokens (local curves mirroring the source's per-transition timings)
// ---------------------------------------------------------------------------

/// Item enter opacity: 180ms EASE_OUT (source `CitationList` opacity transition).
const _itemOpacityMotion = CurvedMotion(
  Duration(milliseconds: 180),
  beuiEaseOut,
);

/// Disclosure open 220ms / close 140ms EASE_OUT (source `AgentDisclosure`).
const _disclosureOpenMotion = CurvedMotion(
  Duration(milliseconds: 220),
  beuiEaseOut,
);
const _disclosureCloseMotion = CurvedMotion(
  Duration(milliseconds: 140),
  beuiEaseOut,
);

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// One citation / source reference — the Flutter port of the source's
/// `CitationItem`.
///
/// A data descriptor, not a widget. Pass a list of these to [BeuiCitations]
/// or [BeuiCitationList].
@immutable
class BeuiCitationItem {
  /// Creates a citation descriptor.
  const BeuiCitationItem({
    required this.id,
    required this.title,
    this.domain,
    this.url,
    this.onTap,
  });

  /// Stable identity within the list (keys enter animations + anchor targets).
  final String id;

  /// Primary label. Accepts any widget (source `ReactNode`); demos typically
  /// pass a [Text].
  final Widget title;

  /// Optional secondary label (usually a domain). Accepts any widget.
  final Widget? domain;

  /// Optional source URL. Used for the favicon resolve path and as a hint for
  /// consumers; the row fires [onTap] when provided (the package does not
  /// open URLs itself — wire [onTap] to `url_launcher` if needed).
  final String? url;

  /// Called when the citation row is activated.
  final VoidCallback? onTap;
}

// ---------------------------------------------------------------------------
// Favicon helper (source `getFaviconUrl`)
// ---------------------------------------------------------------------------

/// Resolve a website URL to its conventional root favicon location
/// (`/favicon.ico` on the same origin). Returns null when [value] is not a
/// valid absolute URL.
String? beuiFaviconUrl(String value) {
  try {
    final uri = Uri.parse(value);
    if (!uri.hasScheme || uri.host.isEmpty) return null;
    // Origin + /favicon.ico (source `new URL("/favicon.ico", value)`).
    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/favicon.ico',
    ).toString();
  } on FormatException {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Anchor registry — Flutter stand-in for HTML `#id` hash links
// ---------------------------------------------------------------------------

/// Document-wide citation anchors keyed by `idPrefix` + citation id.
///
/// Mirrors the source's `href="#prefix-id"` links: [BeuiCitation] markers can
/// live anywhere in the tree (e.g. inside prose above the panel) and still
/// open / scroll to the matching row registered by [BeuiCitations] or
/// [BeuiCitationList].
class _CitationAnchors {
  static final Map<String, Map<String, GlobalKey>> _keys =
      <String, Map<String, GlobalKey>>{};
  static final Map<String, void Function(String citationId)> _openers =
      <String, void Function(String citationId)>{};

  static GlobalKey keyFor(String prefix, String citationId) {
    final bucket = _keys.putIfAbsent(prefix, () => <String, GlobalKey>{});
    return bucket.putIfAbsent(citationId, GlobalKey.new);
  }

  static void prune(String prefix, Set<String> liveIds) {
    final bucket = _keys[prefix];
    if (bucket == null) return;
    bucket.removeWhere((id, _) => !liveIds.contains(id));
    if (bucket.isEmpty) _keys.remove(prefix);
  }

  static void setOpener(
    String prefix,
    void Function(String citationId)? opener,
  ) {
    if (opener == null) {
      _openers.remove(prefix);
    } else {
      _openers[prefix] = opener;
    }
  }

  static void clearPrefix(String prefix) {
    _keys.remove(prefix);
    _openers.remove(prefix);
  }

  /// Opens the host panel (if any) and scrolls to the target row.
  static bool scrollTo(
    String prefix,
    String citationId, {
    bool reduce = false,
  }) {
    _openers[prefix]?.call(citationId);
    final target = _keys[prefix]?[citationId]?.currentContext;
    if (target == null) {
      // Panel may still be closed / building — retry next frame after open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[prefix]?[citationId]?.currentContext;
        if (ctx == null) return;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.1,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
          curve: beuiEaseOut,
        );
      });
      return false;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      curve: beuiEaseOut,
    );
    return true;
  }
}

String _sanitizeId(String citationId) {
  return citationId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
}

/// Builds the DOM-style target id (`prefix-sanitizedId`) used in the source.
String citationTargetId(String prefix, String citationId) {
  return '$prefix-${_sanitizeId(citationId)}';
}

// ---------------------------------------------------------------------------
// BeuiCitation — inline superscript marker
// ---------------------------------------------------------------------------

/// Inline citation marker that jumps to the matching reference in a
/// [BeuiCitationList] / [BeuiCitations] (source `Citation`).
///
/// Style: muted mini badge, slightly raised (`-translate-y-0.5`). Tap scrolls
/// to the row registered under [idPrefix] + [citationId], or fires
/// [onPressed] when provided.
class BeuiCitation extends StatefulWidget {
  /// Creates an inline citation marker.
  const BeuiCitation({
    required this.citationId,
    required this.index,
    required this.idPrefix,
    this.onPressed,
    super.key,
  });

  /// Must match a [BeuiCitationItem.id] in the related list.
  final String citationId;

  /// 1-based display index shown inside the badge.
  final int index;

  /// Must match the related [BeuiCitations.idPrefix] / [BeuiCitationList.idPrefix].
  final String idPrefix;

  /// Optional override. When null, the marker scrolls to the matching row via
  /// the document-wide citation anchor registry.
  final VoidCallback? onPressed;

  @override
  State<BeuiCitation> createState() => _BeuiCitationState();
}

class _BeuiCitationState extends State<BeuiCitation> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() {
    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    _CitationAnchors.scrollTo(
      widget.idPrefix,
      widget.citationId,
      reduce: reduce,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final fg = (_hovered || _focused)
        ? colors.foreground
        : colors.mutedForeground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _activate,
          child: Semantics(
            button: true,
            label: 'View citation ${widget.index}',
            child: Transform.translate(
              // -translate-y-0.5 (2 logical px)
              offset: const Offset(0, -2),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2), // mx-0.5
                constraints: const BoxConstraints(minWidth: 16), // min-w-4
                padding: const EdgeInsets.symmetric(
                  horizontal: 4, // px-1
                  vertical: 2, // py-0.5
                ),
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.6), // bg-muted/60
                  borderRadius: BorderRadius.circular(6), // rounded-md
                  border: _focused
                      ? Border.all(color: colors.ring, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiCitationFavicon
// ---------------------------------------------------------------------------

/// Leading favicon for a citation row / stack, falling back to a globe glyph
/// when the URL is missing or the image fails (source `CitationFavicon`).
class BeuiCitationFavicon extends StatefulWidget {
  /// Creates a citation favicon.
  const BeuiCitationFavicon({
    this.url,
    this.size = 20,
    this.imageSize = 16,
    this.decoration,
    super.key,
  });

  /// Source page URL — favicon is resolved via [beuiFaviconUrl].
  final String? url;

  /// Outer slot size (source `size-5` = 20, stack uses `size-6` = 24).
  final double size;

  /// Favicon image size (source `size-4` = 16).
  final double imageSize;

  /// Optional outer decoration (stack wraps with a ring + background).
  final BoxDecoration? decoration;

  @override
  State<BeuiCitationFavicon> createState() => _BeuiCitationFaviconState();
}

class _BeuiCitationFaviconState extends State<BeuiCitationFavicon> {
  String? _failedUrl;

  @override
  void didUpdateWidget(BeuiCitationFavicon old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _failedUrl = null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final favicon = widget.url != null ? beuiFaviconUrl(widget.url!) : null;
    final showImage = favicon != null && _failedUrl != favicon;

    Widget child;
    if (showImage) {
      child = Image.network(
        favicon,
        width: widget.imageSize,
        height: widget.imageSize,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          // Schedule state write after this frame to avoid setState during build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _failedUrl != favicon) {
              setState(() => _failedUrl = favicon);
            }
          });
          return Icon(
            LucideIcons.globe,
            size: widget.imageSize * 0.875, // size-3.5 relative to 16
            color: colors.mutedForeground,
          );
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(2), // rounded-sm
              child: child,
            );
          }
          return Icon(
            LucideIcons.globe,
            size: widget.imageSize * 0.875,
            color: colors.mutedForeground,
          );
        },
      );
    } else {
      child = Icon(
        LucideIcons.globe,
        size: widget.imageSize * 0.875,
        color: colors.mutedForeground,
      );
    }

    return ExcludeSemantics(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: widget.decoration,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiCitationStack
// ---------------------------------------------------------------------------

/// Overlapping favicon stack used as a compact source summary (source
/// `CitationStack`). Defaults to the first 3 items.
class BeuiCitationStack extends StatelessWidget {
  /// Creates a citation favicon stack.
  const BeuiCitationStack({required this.citations, this.limit = 3, super.key});

  /// Source items (only the first [limit] are shown).
  final List<BeuiCitationItem> citations;

  /// Max favicons to render (source default `3`).
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final shown = citations.take(limit).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    // flex -space-x-1.5 → 6px overlap; each chip is 24×24 (size-6).
    const chip = 24.0;
    const overlap = 6.0;
    final width = chip + (shown.length - 1) * (chip - overlap);

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: chip,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * (chip - overlap),
                child: BeuiCitationFavicon(
                  url: shown[i].url,
                  size: chip,
                  imageSize: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.background,
                    border: Border.all(color: colors.background, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiCitationList
// ---------------------------------------------------------------------------

/// Progressively rendered citation rows with enter opacity + y spring (source
/// `CitationList`). New items animate in as the list grows.
class BeuiCitationList extends StatefulWidget {
  /// Creates a citation list.
  const BeuiCitationList({required this.citations, this.idPrefix, super.key});

  /// Rows to render, top to bottom.
  final List<BeuiCitationItem> citations;

  /// Anchor prefix shared with [BeuiCitation] markers. Auto-generated when
  /// null (source `useId()` fallback).
  final String? idPrefix;

  @override
  State<BeuiCitationList> createState() => _BeuiCitationListState();
}

class _BeuiCitationListState extends State<BeuiCitationList> {
  late String _resolvedPrefix =
      widget.idPrefix ?? 'citation-list-${identityHashCode(this)}';

  @override
  void didUpdateWidget(BeuiCitationList old) {
    super.didUpdateWidget(old);
    if (widget.idPrefix != null && widget.idPrefix != _resolvedPrefix) {
      // Drop anchors registered under the previous auto/old prefix.
      if (old.idPrefix == null || old.idPrefix != widget.idPrefix) {
        _CitationAnchors.clearPrefix(_resolvedPrefix);
      }
      _resolvedPrefix = widget.idPrefix!;
    }
    final ids = widget.citations.map((c) => c.id).toSet();
    _CitationAnchors.prune(_resolvedPrefix, ids);
  }

  @override
  void dispose() {
    // Only clear when we own a unique auto-generated prefix; shared prefixes
    // (e.g. nested under BeuiCitations) stay registered for the parent.
    if (widget.idPrefix == null) {
      _CitationAnchors.clearPrefix(_resolvedPrefix);
    } else {
      final ids = widget.citations.map((c) => c.id).toSet();
      _CitationAnchors.prune(_resolvedPrefix, ids);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final ids = widget.citations.map((c) => c.id).toSet();
    _CitationAnchors.prune(_resolvedPrefix, ids);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.citations.length; i++) ...[
          if (i > 0) const SizedBox(height: 2), // gap-0.5
          _CitationEnter(
            key: ValueKey<String>(widget.citations[i].id),
            reduce: reduce,
            child: KeyedSubtree(
              key: _CitationAnchors.keyFor(
                _resolvedPrefix,
                widget.citations[i].id,
              ),
              child: _CitationRow(citation: widget.citations[i], index: i + 1),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BeuiCitations — collapsible sources panel
// ---------------------------------------------------------------------------

/// Collapsible, progressively rendered reference collection for grounded agent
/// responses — the Flutter port of beUI's `citations`.
///
/// Header shows a book glyph, title, count badge, and spring-rotated chevron.
/// Body is an [AgentDisclosure]-style clip/fade reveal containing a
/// [BeuiCitationList]. Controlled when [open] is non-null; otherwise internal
/// state seeded by [defaultOpen].
///
/// Pair with [BeuiCitation] inline markers sharing the same [idPrefix] so taps
/// expand the panel and scroll to the matching row.
class BeuiCitations extends StatefulWidget {
  /// Creates a collapsible citations panel.
  const BeuiCitations({
    required this.citations,
    this.title,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.idPrefix,
    super.key,
  });

  /// Source rows.
  final List<BeuiCitationItem> citations;

  /// Header label. Defaults to `"Sources"`. Accepts any widget.
  final Widget? title;

  /// Controlled open state. When non-null the panel is *controlled* — keep it
  /// in sync via [onOpenChange]. Leave null for the uncontrolled pattern.
  final bool? open;

  /// Initial open state in the uncontrolled case (ignored when [open] is
  /// supplied). Source default is `false`.
  final bool defaultOpen;

  /// Called with the new open state on every toggle.
  final ValueChanged<bool>? onOpenChange;

  /// Anchor prefix shared with [BeuiCitation] markers. Auto-generated when
  /// null.
  final String? idPrefix;

  @override
  State<BeuiCitations> createState() => _BeuiCitationsState();
}

class _BeuiCitationsState extends State<BeuiCitations> {
  late bool _internalOpen = widget.defaultOpen;
  late String _resolvedPrefix =
      widget.idPrefix ?? 'citation-${identityHashCode(this)}';

  bool get _isControlled => widget.open != null;
  bool get _currentOpen => widget.open ?? _internalOpen;

  @override
  void initState() {
    super.initState();
    _CitationAnchors.setOpener(_resolvedPrefix, _ensureOpen);
  }

  @override
  void didUpdateWidget(BeuiCitations old) {
    super.didUpdateWidget(old);
    if (widget.idPrefix != null && widget.idPrefix != _resolvedPrefix) {
      _CitationAnchors.setOpener(_resolvedPrefix, null);
      _resolvedPrefix = widget.idPrefix!;
      _CitationAnchors.setOpener(_resolvedPrefix, _ensureOpen);
    }
  }

  @override
  void dispose() {
    _CitationAnchors.setOpener(_resolvedPrefix, null);
    if (widget.idPrefix == null) {
      _CitationAnchors.clearPrefix(_resolvedPrefix);
    }
    super.dispose();
  }

  void _setOpen(bool next) {
    if (next == _currentOpen) return;
    if (!_isControlled) setState(() => _internalOpen = next);
    widget.onOpenChange?.call(next);
  }

  void _toggle() => _setOpen(!_currentOpen);

  void _ensureOpen(String _) {
    if (!_currentOpen) _setOpen(true);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Semantics(
      container: true,
      label: 'Sources',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CitationsHeader(
            open: _currentOpen,
            title: widget.title ?? const Text('Sources'),
            count: widget.citations.length,
            colors: colors,
            reduce: reduce,
            onToggle: _toggle,
          ),
          _AgentDisclosure(
            open: _currentOpen,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(top: 4), // mt-1
              child: BeuiCitationList(
                citations: widget.citations,
                idPrefix: _resolvedPrefix,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _CitationsHeader extends StatefulWidget {
  const _CitationsHeader({
    required this.open,
    required this.title,
    required this.count,
    required this.colors,
    required this.reduce,
    required this.onToggle,
  });

  final bool open;
  final Widget title;
  final int count;
  final BeuiColors colors;
  final bool reduce;
  final VoidCallback onToggle;

  @override
  State<_CitationsHeader> createState() => _CitationsHeaderState();
}

class _CitationsHeaderState extends State<_CitationsHeader> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final fg = (_hovered || _focused)
        ? colors.foreground
        : colors.mutedForeground;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onToggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onToggle,
          child: Semantics(
            button: true,
            expanded: widget.open,
            label: 'Sources, ${widget.count}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32), // min-h-8
              child: Padding(
                // -ml-1 px-1
                padding: const EdgeInsets.only(left: 0, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.book_open_text, size: 16, color: fg),
                    const SizedBox(width: 8), // gap-2
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fg,
                      ),
                      child: widget.title,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6, // px-1.5
                        vertical: 2, // py-0.5
                      ),
                      decoration: BoxDecoration(
                        color: colors.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${widget.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Chevron(
                      open: widget.open,
                      reduce: widget.reduce,
                      color: colors.mutedForeground.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({
    required this.open,
    required this.reduce,
    required this.color,
  });

  final bool open;
  final bool reduce;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(LucideIcons.chevron_down, size: 14, color: color);
    if (reduce) {
      return Transform.rotate(angle: open ? math.pi : 0, child: icon);
    }
    return SingleMotionBuilder(
      value: open ? 180.0 : 0.0,
      motion: motionFor(context, beuiSpringSwap, isMovement: true),
      builder: (context, deg, child) =>
          Transform.rotate(angle: deg * math.pi / 180.0, child: child),
      child: icon,
    );
  }
}

// ---------------------------------------------------------------------------
// Citation row
// ---------------------------------------------------------------------------

class _CitationRow extends StatefulWidget {
  const _CitationRow({required this.citation, required this.index});

  final BeuiCitationItem citation;
  final int index;

  @override
  State<_CitationRow> createState() => _CitationRowState();
}

class _CitationRowState extends State<_CitationRow> {
  bool _hovered = false;
  bool _focused = false;

  bool get _interactive =>
      widget.citation.onTap != null || widget.citation.url != null;

  void _activate() {
    widget.citation.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final titleColor = _hovered || _focused
        ? colors.foreground
        : colors.foreground.withValues(alpha: 0.8);
    final linkColor = _hovered || _focused
        ? colors.mutedForeground
        : colors.mutedForeground.withValues(alpha: 0.4);

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 4,
      ), // px-1.5 py-1
      child: Row(
        children: [
          BeuiCitationFavicon(url: widget.citation.url),
          const SizedBox(width: 8), // gap-2
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8, // gap-x-2
              runSpacing: 2, // gap-y-0.5
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 20 / 14,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  child: widget.citation.title,
                ),
                if (widget.citation.domain != null)
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 12,
                      height: 16 / 12,
                      color: colors.mutedForeground.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    child: widget.citation.domain!,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20, // size-5
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.foreground.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.index}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              if (widget.citation.url != null) ...[
                const SizedBox(width: 6), // gap-1.5
                Icon(
                  LucideIcons.external_link,
                  size: 14, // size-3.5
                  color: linkColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    Widget row = content;
    if (_interactive) {
      row = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: FocusableActionDetector(
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _activate,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: _focused
                    ? Border.all(color: colors.ring, width: 2)
                    : null,
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      button: _interactive,
      label: 'Citation ${widget.index}',
      child: row,
    );
  }
}

// ---------------------------------------------------------------------------
// Enter animation (opacity 180ms EASE_OUT + y SPRING_LAYOUT)
// ---------------------------------------------------------------------------

class _CitationEnter extends StatefulWidget {
  const _CitationEnter({required this.reduce, required this.child, super.key});

  final bool reduce;
  final Widget child;

  @override
  State<_CitationEnter> createState() => _CitationEnterState();
}

class _CitationEnterState extends State<_CitationEnter> {
  double _opacity = 0;
  double _y = 1; // 1 = enter offset, 0 = settled

  @override
  void initState() {
    super.initState();
    if (widget.reduce) {
      _opacity = 1;
      _y = 0;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _opacity = 1;
            _y = 0;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduce) {
      return widget.child;
    }
    return SingleMotionBuilder(
      value: _opacity,
      from: 0,
      motion: motionFor(context, _itemOpacityMotion, isMovement: false),
      builder: (context, o, child) {
        return SingleMotionBuilder(
          value: _y,
          from: 1,
          motion: motionFor(context, beuiSpringLayout, isMovement: true),
          builder: (context, y, child) {
            return Opacity(
              opacity: o.clamp(0.0, 1.0),
              child: Transform.translate(
                // Source enter y: 6 → 0
                offset: Offset(0, 6 * y),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Agent disclosure (height + opacity + y clip reveal)
// ---------------------------------------------------------------------------

/// Shared transform-only reveal for collapsible agent content — the Flutter
/// port of the source's `AgentDisclosure`.
class _AgentDisclosure extends StatelessWidget {
  const _AgentDisclosure({
    required this.open,
    required this.reduce,
    required this.child,
  });

  final bool open;
  final bool reduce;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = open ? 1.0 : 0.0;
    final motion = open ? _disclosureOpenMotion : _disclosureCloseMotion;

    if (reduce) {
      return Offstage(
        offstage: !open,
        child: IgnorePointer(
          ignoring: !open,
          child: ExcludeSemantics(
            excluding: !open,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: open ? 1.0 : 0.0,
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return SingleMotionBuilder(
      value: target,
      motion: motionFor(context, motion, isMovement: true),
      builder: (context, t, child) {
        final tt = t.clamp(0.0, 1.0);
        final closed = tt < 0.01;
        return Offstage(
          offstage: closed,
          child: IgnorePointer(
            ignoring: closed,
            child: ExcludeSemantics(
              excluding: closed,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: tt,
                  child: Opacity(
                    opacity: tt,
                    child: Transform.translate(
                      offset: Offset(0, -4 * (1 - tt)),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
