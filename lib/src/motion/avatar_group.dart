import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerExitEvent;
import 'package:flutter/material.dart';

import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import 'tooltip.dart';

/// The source-defined avatar sizes.
enum BeuiAvatarSize {
  /// 28px circle with 10px initials.
  sm(28, 10),

  /// 36px circle with 12px initials.
  md(36, 12),

  /// 44px circle with 14px initials.
  lg(44, 14);

  const BeuiAvatarSize(this.pixels, this.fontSize);

  /// Circle diameter in logical pixels.
  final double pixels;

  /// Initials font size in logical pixels.
  final double fontSize;
}

/// A member rendered by [BeuiAvatarGroup].
@immutable
class BeuiAvatarGroupMember {
  /// Creates a member with a stable [id] and visible [name].
  const BeuiAvatarGroupMember({required this.id, required this.name, this.src});

  /// Stable identity, used to retain animation state across updates.
  final String id;

  /// Person's full name, exposed to assistive technology and as image alt text.
  final String name;

  /// Optional network image. Missing or failed images show initials.
  final String? src;
}

/// A circular avatar with initials shown when no image is available.
class BeuiAvatar extends StatelessWidget {
  /// Creates an avatar for [name].
  const BeuiAvatar({
    required this.name,
    this.src,
    this.size = BeuiAvatarSize.md,
    super.key,
  });

  /// Full name used for semantics and initials.
  final String name;

  /// Optional network image URL.
  final String? src;

  /// Avatar diameter and initials size.
  final BeuiAvatarSize size;

  /// Builds source-compatible uppercase initials.
  static String initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.runes;
    if (parts.length == 1) {
      return String.fromCharCodes(first.take(2)).toUpperCase();
    }
    return '${String.fromCharCode(first.first)}${String.fromCharCode(parts.last.runes.first)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final imageUrl = src;
    return Semantics(
      image: imageUrl != null && imageUrl.isNotEmpty,
      label: name,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size.pixels,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(color: colors.background, width: 2),
            ),
            child: ClipOval(
              child: imageUrl == null || imageUrl.isEmpty
                  ? _AvatarInitials(name: name, size: size, colors: colors)
                  : Image.network(
                      imageUrl,
                      key: ValueKey<String>(imageUrl),
                      fit: BoxFit.cover,
                      width: size.pixels,
                      height: size.pixels,
                      errorBuilder: (context, error, stackTrace) =>
                          _AvatarInitials(
                            name: name,
                            size: size,
                            colors: colors,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({
    required this.name,
    required this.size,
    required this.colors,
  });
  final String name;
  final BeuiAvatarSize size;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      BeuiAvatar.initialsFor(name),
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: colors.mutedForeground,
        fontSize: size.fontSize,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

/// An overlapping, expandable row of avatars with mouse-only fan-out motion.
///
/// Member spans intentionally are not keyboard tab stops, matching the source.
/// Their names remain present in semantics when tooltips are closed. Only the
/// overflow button is focusable; it toggles the complete list and remains
/// rendered while expanded.
class BeuiAvatarGroup extends StatefulWidget {
  /// Creates an avatar group.
  const BeuiAvatarGroup({
    required this.members,
    this.max = 4,
    this.size = BeuiAvatarSize.md,
    this.expanded,
    this.defaultExpanded = false,
    this.onExpandedChange,
    this.label = 'Members',
    this.onPointerLeave,
    super.key,
  });

  /// Members in logical source order. Every [id] must be unique.
  final List<BeuiAvatarGroupMember> members;

  /// Maximum members shown when collapsed; the source floors this at one.
  final int max;

  /// Avatar size.
  final BeuiAvatarSize size;

  /// Controlled expanded state. Null makes the group uncontrolled.
  final bool? expanded;

  /// Initial uncontrolled state; read once when the State is created.
  final bool defaultExpanded;

  /// Called after a toggle; uncontrolled state updates first.
  final ValueChanged<bool>? onExpandedChange;

  /// Accessible list name.
  final String label;

  /// Called when the pointer leaves the group; hover state then resets.
  final ValueChanged<PointerExitEvent>? onPointerLeave;

  @override
  State<BeuiAvatarGroup> createState() => _BeuiAvatarGroupState();
}

class _AvatarEntry {
  _AvatarEntry(this.member, {required this.targetIndex, required this.initial});
  BeuiAvatarGroupMember member;
  int targetIndex;
  bool initial;
  bool exiting = false;
}

class _BeuiAvatarGroupState extends State<BeuiAvatarGroup> {
  late bool _internalExpanded = widget.defaultExpanded;
  final Map<String, _AvatarEntry> _entries = {};
  final Map<String, Timer> _exitTimers = {};
  final FocusNode _overflowFocusNode = FocusNode();
  int? _hoveredIndex;
  bool _overflowHasFocus = false;
  bool _keyboardInput = false;
  bool _overflowFocused = false;
  bool _overflowPressed = false;

  bool get _expanded => widget.expanded ?? _internalExpanded;
  int get _limit => math.max(1, widget.max).toInt();
  int get _overflow => math.max(0, widget.members.length - _limit).toInt();
  List<BeuiAvatarGroupMember> get _visible =>
      _expanded ? widget.members : widget.members.take(_limit).toList();

  @override
  void initState() {
    super.initState();
    _syncEntries(initial: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final entry in _entries.values) {
        entry.initial = false;
      }
    });
  }

  void _handleOverflowFocusChange(bool hasFocus) {
    _overflowHasFocus = hasFocus;
    _updateOverflowFocusVisibility();
  }

  void _updateOverflowFocusVisibility() {
    final visible = _overflowHasFocus && _keyboardInput;
    if (_overflowFocused == visible) return;
    setState(() => _overflowFocused = visible);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_keyboardInput) {
      _keyboardInput = true;
      _updateOverflowFocusVisibility();
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerDown() {
    if (!_keyboardInput) return;
    _keyboardInput = false;
    _updateOverflowFocusVisibility();
  }

  @override
  void didUpdateWidget(covariant BeuiAvatarGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEntries(initial: false);
    if (oldWidget.expanded != widget.expanded && widget.expanded != null) {
      _hoveredIndex = null;
    }
  }

  void _syncEntries({required bool initial}) {
    final membersById = {
      for (final member in widget.members) member.id: member,
    };
    assert(
      membersById.length == widget.members.length,
      'Avatar member ids must be unique.',
    );
    final visible = _visible;
    final visibleIndices = {
      for (var i = 0; i < visible.length; i++) visible[i].id: i,
    };

    for (final member in widget.members) {
      final entry = _entries[member.id];
      if (entry == null) {
        if (visibleIndices.containsKey(member.id)) {
          _entries[member.id] = _AvatarEntry(
            member,
            targetIndex: visibleIndices[member.id]!,
            initial: initial,
          );
        }
      } else {
        entry.member = member;
        final nextIndex = visibleIndices[member.id];
        if (nextIndex != null) {
          _exitTimers.remove(member.id)?.cancel();
          entry
            ..exiting = false
            ..targetIndex = nextIndex;
        } else if (!entry.exiting) {
          entry.exiting = true;
          _scheduleExit(member.id);
        }
      }
    }
    for (final entry in _entries.values) {
      final nextIndex = visibleIndices[entry.member.id];
      if (nextIndex != null) {
        entry
          ..targetIndex = nextIndex
          ..exiting = false;
      } else if (!entry.exiting) {
        entry.exiting = true;
        _scheduleExit(entry.member.id);
      }
    }
  }

  void _scheduleExit(String id) {
    _exitTimers.remove(id)?.cancel();
    _exitTimers[id] = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      final entry = _entries[id];
      if (entry != null && entry.exiting) {
        setState(() => _entries.remove(id));
      }
    });
  }

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    _exitTimers.clear();
    _overflowFocusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !_expanded;
    setState(() {
      if (widget.expanded == null) _internalExpanded = next;
      _hoveredIndex = null;
      _syncEntries(initial: false);
    });
    widget.onExpandedChange?.call(next);
  }

  void _setHovered(int? index) {
    if (_hoveredIndex == index) return;
    setState(() => _hoveredIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final canHover = !reduce && _hoveredIndex != null;
    final px = widget.size.pixels;
    final overlap = (px / 3).roundToDouble();
    final push = (overlap * 0.75).roundToDouble();
    final visible = _visible;
    final overflow = _overflow;
    final hasOverflow = overflow > 0;
    final slotCount = visible.length + (hasOverflow ? 1 : 0);
    final width = slotCount == 0 ? 0.0 : px + (slotCount - 1) * (px - overlap);
    final height = slotCount == 0 ? 0.0 : px;
    final targetById = {
      for (var i = 0; i < visible.length; i++) visible[i].id: i,
    };

    return BeuiTooltipProvider(
      skipDelay: const Duration(milliseconds: 400),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: _handleKeyEvent,
        child: Listener(
          onPointerDown: (_) => _handlePointerDown(),
          child: MouseRegion(
            onExit: (event) {
              widget.onPointerLeave?.call(event);
              _setHovered(null);
            },
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: widget.label,
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final entry
                        in (_entries.values.toList()..sort((a, b) {
                          final aHovered =
                              canHover && _hoveredIndex == a.targetIndex;
                          final bHovered =
                              canHover && _hoveredIndex == b.targetIndex;
                          if (aHovered == bHovered) {
                            return a.targetIndex.compareTo(b.targetIndex);
                          }
                          return aHovered ? 1 : -1;
                        })))
                      _AvatarGroupItem(
                        key: ValueKey<String>(entry.member.id),
                        entry: entry,
                        member: entry.member,
                        visualIndex: targetById[entry.member.id] == null
                            ? entry.targetIndex
                            : targetById[entry.member.id]!,
                        size: widget.size,
                        overlap: overlap,
                        push: push,
                        hoveredIndex: _hoveredIndex,
                        canHover: canHover,
                        reduce: reduce,
                        colors: colors,
                        onMouseEnter: _setHovered,
                      ),
                    if (hasOverflow)
                      _OverflowAvatar(
                        left: visible.length * (px - overlap),
                        size: widget.size,
                        value: overflow,
                        expanded: _expanded,
                        offset: canHover && _hoveredIndex != visible.length
                            ? (_hoveredIndex! < visible.length ? push : -push)
                            : 0,
                        reduce: reduce,
                        focused: _overflowFocused,
                        hasFocus: _overflowHasFocus,
                        focusNode: _overflowFocusNode,
                        pressed: _overflowPressed,
                        colors: colors,
                        onFocusChange: _handleOverflowFocusChange,
                        onHighlightChanged: (value) =>
                            setState(() => _overflowPressed = value),
                        onMouseEnter: () => _setHovered(visible.length),
                        onTap: _toggle,
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

class _AvatarGroupItem extends StatelessWidget {
  const _AvatarGroupItem({
    required super.key,
    required this.entry,
    required this.member,
    required this.visualIndex,
    required this.size,
    required this.overlap,
    required this.push,
    required this.hoveredIndex,
    required this.canHover,
    required this.reduce,
    required this.colors,
    required this.onMouseEnter,
  });

  final _AvatarEntry entry;
  final BeuiAvatarGroupMember member;
  final int visualIndex;
  final BeuiAvatarSize size;
  final double overlap;
  final double push;
  final int? hoveredIndex;
  final bool canHover;
  final bool reduce;
  final BeuiColors colors;
  final ValueChanged<int?> onMouseEnter;

  @override
  Widget build(BuildContext context) {
    final targetLeft = visualIndex * (size.pixels - overlap);
    final hovered = canHover && hoveredIndex == visualIndex;
    final partOffset = !canHover || hovered
        ? 0.0
        : visualIndex < hoveredIndex!
        ? -push
        : push;
    final transition = Duration(
      milliseconds: entry.exiting
          ? 140
          : entry.initial
          ? 1
          : 180,
    );
    final targetScale = entry.exiting ? (reduce ? 1.0 : 0.6) : 1.0;
    final targetOpacity = entry.exiting ? 0.0 : 1.0;
    final avatar = BeuiAvatar(name: member.name, src: member.src, size: size);
    final scaleTransition = reduce
        ? Transform.scale(scale: 1, child: avatar)
        : SingleMotionBuilder(
            value: targetScale,
            from: entry.initial ? 1.0 : 0.6,
            motion: entry.exiting
                ? CurvedMotion(transition, beuiEaseOut)
                : motionFor(context, beuiSpringLayout, isMovement: true),
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: avatar,
          );
    final child = BeuiTooltip(
      content: Text(member.name),
      side: BeuiTooltipSide.top,
      child: MouseRegion(
        onEnter: (event) {
          if (event.kind == PointerDeviceKind.mouse) onMouseEnter(visualIndex);
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: entry.initial ? 1 : 0,
            end: targetOpacity,
          ),
          duration: transition,
          curve: beuiEaseOut,
          builder: (context, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: scaleTransition,
        ),
      ),
    );
    final hoveredTransform = reduce
        ? child
        : SingleMotionBuilder(
            value: hovered ? 1.06 : 1.0,
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            builder: (context, scale, child) => MotionBuilder<Offset>(
              value: Offset(partOffset, hovered ? -3 : 0),
              motion: motionFor(context, beuiSpringLayout, isMovement: true),
              converter: const OffsetMotionConverter(),
              builder: (context, offset, child) => Transform.translate(
                offset: offset,
                child: Transform.scale(scale: scale, child: child),
              ),
              child: child,
            ),
            child: child,
          );
    final positioned = entry.exiting
        ? entry.targetIndex * (size.pixels - overlap)
        : targetLeft;
    final guarded = ExcludeSemantics(
      excluding: entry.exiting,
      child: IgnorePointer(ignoring: entry.exiting, child: hoveredTransform),
    );
    return reduce
        ? PositionedDirectional(start: positioned, top: 0, child: guarded)
        : MotionBuilder<Offset>(
            value: Offset(positioned, 0),
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            converter: const OffsetMotionConverter(),
            builder: (context, value, child) =>
                PositionedDirectional(start: value.dx, top: 0, child: child!),
            child: guarded,
          );
  }
}

class _OverflowAvatar extends StatelessWidget {
  const _OverflowAvatar({
    required this.left,
    required this.size,
    required this.value,
    required this.expanded,
    required this.offset,
    required this.reduce,
    required this.focused,
    required this.hasFocus,
    required this.focusNode,
    required this.pressed,
    required this.colors,
    required this.onFocusChange,
    required this.onHighlightChanged,
    required this.onMouseEnter,
    required this.onTap,
  });

  final double left;
  final BeuiAvatarSize size;
  final int value;
  final bool expanded;
  final double offset;
  final bool reduce;
  final bool focused;
  final bool hasFocus;
  final FocusNode focusNode;
  final bool pressed;
  final BeuiColors colors;
  final ValueChanged<bool> onFocusChange;
  final ValueChanged<bool> onHighlightChanged;
  final VoidCallback onMouseEnter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? 'Show fewer members' : 'Show $value more members';
    final ring = focused
        ? BorderSide(color: colors.ring, width: 2)
        : BorderSide(color: colors.background, width: 2);
    final motion = motionFor(context, beuiSpringPress, isMovement: true);
    Widget button = SingleMotionBuilder(
      value: pressed && !reduce ? 0.92 : 1,
      motion: motion,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: SizedBox.square(
        dimension: size.pixels,
        child: Material(
          color: colors.foreground,
          shape: CircleBorder(side: ring),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            focusNode: focusNode,
            customBorder: const CircleBorder(),
            onTap: onTap,
            onFocusChange: onFocusChange,
            onHighlightChanged: onHighlightChanged,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: beuiEaseOut,
                switchOutCurve: beuiEaseOut,
                transitionBuilder: (child, animation) {
                  final isIncoming = child.key == ValueKey<bool>(expanded);
                  final y = reduce
                      ? 0.0
                      : isIncoming
                      ? (expanded ? 8.0 : -8.0)
                      : (expanded ? -8.0 : 8.0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, y / size.pixels),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  expanded ? '−' : '+$value',
                  key: ValueKey<bool>(expanded),
                  maxLines: 1,
                  style: TextStyle(
                    color: colors.background,
                    fontSize: size.fontSize,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final content = MouseRegion(
      onEnter: (event) {
        if (event.kind == PointerDeviceKind.mouse) onMouseEnter();
      },
      child: Semantics(
        button: true,
        expanded: expanded,
        enabled: true,
        label: label,
        focusable: true,
        focused: hasFocus,
        onFocus: focusNode.requestFocus,
        onTap: onTap,
        child: ExcludeSemantics(child: button),
      ),
    );
    // No source-specific RTL branch: directional placement inherits Flutter's
    // logical row order, while the parting offsets remain physical like source.
    return reduce
        ? PositionedDirectional(start: left + offset, top: 0, child: content)
        : MotionBuilder<Offset>(
            value: Offset(left + offset, 0),
            motion: motionFor(context, beuiSpringLayout, isMovement: true),
            converter: const OffsetMotionConverter(),
            builder: (context, position, child) => PositionedDirectional(
              start: position.dx,
              top: 0,
              child: child!,
            ),
            child: content,
          );
  }
}
