import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_disclosure.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';

// ---------------------------------------------------------------------------
// Motion tokens (local curves mirroring the source's per-transition timings)
// ---------------------------------------------------------------------------

/// Item enter opacity: 180ms EASE_OUT (source `CitationList` opacity transition).
const _itemOpacityMotion = CurvedMotion(
  Duration(milliseconds: 180),
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
  /// consumers.
  ///
  /// **A URL on its own does not make the row interactive.** The package never
  /// opens URLs itself, so a row whose only "action" is a `url` has nothing to
  /// do when activated; it used to advertise a click cursor, a link glyph and
  /// button semantics anyway, and then do nothing. Wire up [onTap] (or
  /// [BeuiCitations.onCitationTap]) — e.g. to `url_launcher` — to make the row
  /// live.
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
///
/// It also carries the **row order**, which is what makes the inline marker's
/// number trustworthy: the badge is derived from the registry rather than
/// hand-numbered at the call site, so a marker can no longer read `[2]` while
/// pointing at row 3.
class _CitationAnchors {
  static final Map<String, Map<String, GlobalKey>> _keys =
      <String, Map<String, GlobalKey>>{};
  static final Map<String, void Function(String citationId)> _openers =
      <String, void Function(String citationId)>{};
  static final Map<String, List<String>> _order = <String, List<String>>{};
  static final Map<String, _CitationRevision> _revisions =
      <String, _CitationRevision>{};

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

  /// Publishes the rendered row order for [prefix].
  ///
  /// Called from the list's `build`, so the notification is deferred to after
  /// the frame — markers elsewhere in the tree rebuild on the next frame rather
  /// than being marked dirty during layout.
  static void setOrder(String prefix, List<String> ids) {
    final existing = _order[prefix];
    if (existing != null && listEquals(existing, ids)) return;
    _order[prefix] = List<String>.unmodifiable(ids);
    final revision = _revisions[prefix];
    if (revision == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Still registered? A list can be torn down in the same frame.
      if (_revisions[prefix] == revision) revision.bump();
    });
  }

  /// A [Listenable] that fires whenever [prefix]'s row order changes.
  static Listenable revisionFor(String prefix) =>
      _revisions.putIfAbsent(prefix, _CitationRevision.new);

  /// The 1-based position of [citationId], or null when the list has not
  /// rendered (or no longer contains) that row.
  static int? positionOf(String prefix, String citationId) {
    final order = _order[prefix];
    if (order == null) return null;
    final index = order.indexOf(citationId);
    return index < 0 ? null : index + 1;
  }

  static void clearPrefix(String prefix) {
    _keys.remove(prefix);
    _openers.remove(prefix);
    _order.remove(prefix);
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

/// Notifier for one prefix's row order. A named subclass purely because
/// `notifyListeners` is protected on [ChangeNotifier].
class _CitationRevision extends ChangeNotifier {
  void bump() => notifyListeners();
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
///
/// **The number is derived, not declared.** The badge shows the row's actual
/// position in the matching list, so appending or filtering sources can no
/// longer leave a `[2]` in the prose pointing at row 3. [index] remains as an
/// override for the frames before the list has rendered, and disagreeing with
/// the registry trips a debug assert.
///
/// The painted badge stays 16px wide (source fidelity) but carries a 44px hit
/// target, and its focus ring is painted outside layout so focusing a marker
/// no longer reflows the paragraph around it.
class BeuiCitation extends StatefulWidget {
  /// Creates an inline citation marker.
  const BeuiCitation({
    required this.citationId,
    required this.idPrefix,
    this.index,
    this.onPressed,
    super.key,
  });

  /// Must match a [BeuiCitationItem.id] in the related list.
  final String citationId;

  /// Optional 1-based display index.
  ///
  /// Only used until the matching list has rendered and published its order;
  /// after that the registry's position wins. Passing a value that disagrees
  /// with the rendered order is a bug and asserts in debug builds.
  final int? index;

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
  Listenable? _revision;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(BeuiCitation old) {
    super.didUpdateWidget(old);
    if (old.idPrefix != widget.idPrefix) {
      _revision?.removeListener(_onRegistryChanged);
      _subscribe();
    }
  }

  @override
  void dispose() {
    _revision?.removeListener(_onRegistryChanged);
    super.dispose();
  }

  void _subscribe() {
    _revision = _CitationAnchors.revisionFor(widget.idPrefix)
      ..addListener(_onRegistryChanged);
  }

  void _onRegistryChanged() {
    if (mounted) setState(() {});
  }

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
    final colors = BeuiColors.resolve(context);
    final fg = (_hovered || _focused)
        ? colors.foreground
        : colors.mutedForeground;

    final registered = _CitationAnchors.positionOf(
      widget.idPrefix,
      widget.citationId,
    );
    assert(
      registered == null || widget.index == null || registered == widget.index,
      'BeuiCitation(citationId: "${widget.citationId}") was given '
      'index: ${widget.index}, but it is row $registered of the list under '
      'idPrefix "${widget.idPrefix}". Drop the explicit index and let the '
      'marker derive it, or fix the number at the call site.',
    );
    final display = registered ?? widget.index;

    // Outermost. Inside a WidgetSpan the paragraph hands each inline child the
    // pointer position unfiltered, so the slop is reachable — but only if
    // nothing sized to the 16px badge sits above it.
    return BeuiMinHitTarget(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
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
              container: true,
              button: true,
              label: display == null
                  ? 'View citation'
                  : 'View citation $display',
              child: Transform.translate(
                // -translate-y-0.5 (2 logical px)
                offset: const Offset(0, -2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2), // mx-0.5
                  // The ring is a foreground overlay, so focusing costs no
                  // layout — the old in-decoration 2px border insetting the
                  // badge reflowed the whole paragraph (audit R27).
                  child: BeuiFocusRing(
                    focused: _focused,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                      ), // min-w-4
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4, // px-1
                        vertical: 2, // py-0.5
                      ),
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(
                          alpha: 0.6,
                        ), // bg-muted/60
                        borderRadius: BorderRadius.circular(6), // rounded-md
                      ),
                      // NOTE: no `alignment:` on the Container — that inserts an
                      // unbounded Align, which inside a WidgetSpan grabs the whole
                      // paragraph width and forces a line break. A shrink-wrapping
                      // Align (width/heightFactor 1) still honours `minWidth: 16`.
                      child: Align(
                        widthFactor: 1,
                        heightFactor: 1,
                        child: Text(
                          display?.toString() ?? '·',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            // Tailwind tracking is `normal`; pin it so an ambient
                            // Material text theme cannot widen the badge.
                            letterSpacing: 0,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
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
    final colors = BeuiColors.resolve(context);
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
            LucideIcons.earth,
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
            LucideIcons.earth,
            size: widget.imageSize * 0.875,
            color: colors.mutedForeground,
          );
        },
      );
    } else {
      child = Icon(
        LucideIcons.earth,
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
    final colors = BeuiColors.resolve(context);
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
  const BeuiCitationList({
    required this.citations,
    this.idPrefix,
    this.onCitationTap,
    super.key,
  });

  /// Rows to render, top to bottom.
  final List<BeuiCitationItem> citations;

  /// Anchor prefix shared with [BeuiCitation] markers. Auto-generated when
  /// null (source `useId()` fallback).
  final String? idPrefix;

  /// Called with the citation when a row is activated.
  ///
  /// The list-level counterpart of [BeuiCitationItem.onTap]: supply either (or
  /// both) to make rows interactive. With neither, rows render as static
  /// reference entries rather than advertising an action they cannot perform.
  final ValueChanged<BeuiCitationItem>? onCitationTap;

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
    // Publish the rendered order so inline markers can number themselves.
    _CitationAnchors.setOrder(
      _resolvedPrefix,
      widget.citations.map((c) => c.id).toList(growable: false),
    );

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
              child: _CitationRow(
                citation: widget.citations[i],
                index: i + 1,
                onCitationTap: widget.onCitationTap,
              ),
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
/// Body is an `AgentDisclosure`-style clip/fade reveal containing a
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
    this.onCitationTap,
    this.idPrefix,
    this.emptyPlaceholder,
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

  /// Called with the citation when a row is activated.
  ///
  /// This is the missing half of the row contract. The package deliberately
  /// does not open URLs — it has no opinion about `url_launcher`, in-app
  /// browsers, or your routing — so a row is interactive **only** when an
  /// activation path exists: this callback, or the item's own
  /// [BeuiCitationItem.onTap]. Rows with neither render as static reference
  /// entries: no click cursor, no link glyph, no button semantics, and nothing
  /// that promises an action the widget cannot perform.
  ///
  /// ```dart
  /// BeuiCitations(
  ///   citations: sources,
  ///   onCitationTap: (c) => launchUrlString(c.url!),
  /// )
  /// ```
  final ValueChanged<BeuiCitationItem>? onCitationTap;

  /// Anchor prefix shared with [BeuiCitation] markers. Auto-generated when
  /// null.
  final String? idPrefix;

  /// Shown in the body when [citations] is empty. Defaults to a muted
  /// "No sources for this answer".
  ///
  /// A grounded answer with nothing behind it is a real state, and it used to
  /// render as `Sources 0` over an empty box.
  final Widget? emptyPlaceholder;

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
    final colors = BeuiColors.resolve(context);

    // Advisory, not fatal: a URL-only row is a legitimate (and now correctly
    // *static*) configuration, so this guides rather than crashes.
    assert(() {
      final hasUrls = widget.citations.any((c) => c.url != null);
      final hasHandler =
          widget.onCitationTap != null ||
          widget.citations.any((c) => c.onTap != null);
      if (hasUrls && !hasHandler) {
        debugPrint(
          'BeuiCitations: ${widget.citations.length} citation(s) carry a url '
          'but no activation path, so their rows render as static reference '
          'entries. Pass onCitationTap (or BeuiCitationItem.onTap) — e.g. to '
          'url_launcher — to make them interactive.',
        );
      }
      return true;
    }());

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
          BeuiAgentDisclosureInternal(
            open: _currentOpen,
            reduce: reduce,
            child: Padding(
              padding: const EdgeInsets.only(top: 4), // mt-1
              child: widget.citations.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 13,
                          height: 18 / 13,
                          letterSpacing: 0,
                          color: colors.mutedForeground,
                        ),
                        child:
                            widget.emptyPlaceholder ??
                            const Text('No sources for this answer'),
                      ),
                    )
                  : BeuiCitationList(
                      citations: widget.citations,
                      idPrefix: _resolvedPrefix,
                      onCitationTap: widget.onCitationTap,
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
        mouseCursor: SystemMouseCursors.click,
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
            child: BeuiFocusRing(
              focused: _focused,
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32), // min-h-8
                child: Padding(
                  // -ml-1 px-1
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        BeuiAgentTheme.of(context).icons.citations,
                        size: 16,
                        color: fg,
                      ),
                      const SizedBox(width: 8), // gap-2
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
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
                            letterSpacing: 0,
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
    final icon = Icon(
      BeuiAgentTheme.of(context).icons.expand,
      size: 14,
      color: color,
    );
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
  const _CitationRow({
    required this.citation,
    required this.index,
    required this.onCitationTap,
  });

  final BeuiCitationItem citation;
  final int index;
  final ValueChanged<BeuiCitationItem>? onCitationTap;

  @override
  State<_CitationRow> createState() => _CitationRowState();
}

class _CitationRowState extends State<_CitationRow> {
  bool _hovered = false;
  bool _focused = false;

  /// A row is interactive when there is somewhere for a tap to *go*.
  ///
  /// A bare `url` no longer counts: the package does not open URLs, so a
  /// url-only row used to advertise a click cursor, a link glyph and button
  /// semantics and then silently do nothing on activation.
  bool get _interactive =>
      widget.citation.onTap != null || widget.onCitationTap != null;

  void _activate() {
    widget.citation.onTap?.call();
    widget.onCitationTap?.call(widget.citation);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final highlighted = _hovered || _focused;
    final titleColor = highlighted
        ? colors.foreground
        : colors.foreground.withValues(alpha: 0.8);
    // 0.7 at rest (was 0.4 → 1.79:1). The external-link glyph is one of the two
    // things that tell a reader this source can be verified.
    final linkColor = highlighted
        ? colors.mutedForeground
        : colors.mutedForeground.withValues(alpha: 0.7);

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
                    letterSpacing: 0,
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
                      letterSpacing: 0,
                      // Un-multiplied. The domain is how a reader judges
                      // whether to trust the source; at 0.6 alpha it measured
                      // 2.55:1 and was the least legible thing in the row.
                      color: colors.mutedForeground,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    child: widget.citation.domain!,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8), // gap-2
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
                    letterSpacing: 0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              // The link glyph is a promise that activating the row goes
              // somewhere, so it only appears when it can be kept.
              if (widget.citation.url != null && _interactive) ...[
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

    if (!_interactive) {
      return Semantics(
        container: true,
        label: 'Citation ${widget.index}',
        child: content,
      );
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Citation ${widget.index}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
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
            child: BeuiFocusRing(
              focused: _focused,
              borderRadius: BorderRadius.circular(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: beuiEaseOut,
                decoration: BoxDecoration(
                  // A real hover affordance at the declared 6px radius. The
                  // row used to answer the pointer with a foreground
                  // 0.8 → 1.0 title shift and nothing else.
                  color: _hovered
                      ? colors.muted.withValues(alpha: 0.5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1;
          _y = 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The channel split, not an all-or-nothing switch. Reduced motion drops the
    // 6px rise and keeps the fade: rows arriving out of nowhere with no
    // transition at all is exactly what the project rule forbids, and
    // `preview_rail` has done this correctly all along (audit R18 / T4).
    final fade = SingleMotionBuilder(
      value: _opacity,
      from: 0,
      motion: motionFor(context, _itemOpacityMotion, isMovement: false),
      builder: (context, o, child) =>
          Opacity(opacity: o.clamp(0.0, 1.0), child: child),
      child: widget.child,
    );

    if (widget.reduce) return fade;

    return SingleMotionBuilder(
      value: _y,
      from: 1,
      motion: motionFor(context, beuiSpringLayout, isMovement: true),
      builder: (context, y, child) => Transform.translate(
        // Source enter y: 6 → 0
        offset: Offset(0, 6 * y),
        child: child,
      ),
      child: fade,
    );
  }
}
