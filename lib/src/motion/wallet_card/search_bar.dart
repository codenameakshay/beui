import 'package:flutter/material.dart';

import '../../theme/beui_colors.dart';
import '../../tokens/icons.dart';
import '../_engine.dart' show SingleMotionBuilder;
import '_constants.dart';
import '_morph.dart';

/// Search icon that morphs into a full-width search bar via the shared morph,
/// growing leftward across the header row — the Flutter port of the source's
/// `SearchBar`. The recent-searches results render below the bar; filtering
/// resizes only that list, never re-firing the box morph.
///
/// The box keeps the bouncy [kWalletMorph]; the leading icon + input travel on
/// the critically-damped [kWalletGlide] so they glide to place without the box's
/// overshoot (source `glide`).
class WalletSearchBar extends StatefulWidget {
  /// Creates the search bar.
  const WalletSearchBar({
    this.placeholder = 'Search',
    this.recent = const [],
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// Input hint (source `placeholder`).
  final String placeholder;

  /// Recent searches listed in the open panel.
  final List<String> recent;

  /// Called on every keystroke.
  final ValueChanged<String>? onChanged;

  /// Called on Enter / recent tap.
  final ValueChanged<String>? onSubmitted;

  @override
  State<WalletSearchBar> createState() => _WalletSearchBarState();
}

class _WalletSearchBarState extends State<WalletSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _open = false;
  String _value = '';

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _openBar() {
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open) _inputFocus.requestFocus();
    });
  }

  void _close() {
    if (_open) setState(() => _open = false);
  }

  void _submit(String next) {
    widget.onSubmitted?.call(next);
    _close();
  }

  List<String> get _filtered {
    final q = _value.trim().toLowerCase();
    if (q.isEmpty) return widget.recent;
    return widget.recent
        .where((r) => r.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);

    return MorphPanel(
      open: _open,
      onOpen: _openBar,
      onDismiss: _close,
      armDelayMs: 260,
      trigger: _trigger(colors),
      panelBuilder: (context, info) => _panel(context, colors, info),
    );
  }

  Widget _trigger(BeuiColors colors) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Center(
        child: Icon(
          LucideIcons.search,
          size: 16,
          color: colors.mutedForeground,
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, BeuiColors colors, WalletMorphInfo info) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final filtered = _filtered;
    final contentOpacity = ((info.progress - 0.15) / 0.85).clamp(0.0, 1.0);
    // Icon+input glide from where the trigger sat toward their final position.
    final startShift = (info.triggerLeft - 12).clamp(0.0, double.infinity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Input row (search icon + field), gliding in from the trigger.
        SingleMotionBuilder(
          value: info.open ? 0.0 : startShift,
          from: startShift,
          motion: reduce ? kWalletMorph : kWalletGlide,
          builder: (context, dx, child) =>
              Transform.translate(offset: Offset(dx, 0), child: child),
          child: SizedBox(
            height: 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: 16,
                    color: colors.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Opacity(
                      opacity: contentOpacity,
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.foreground,
                        ),
                        cursorColor: colors.foreground,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: widget.placeholder,
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: colors.mutedForeground,
                          ),
                        ),
                        onChanged: (v) {
                          setState(() => _value = v);
                          widget.onChanged?.call(v);
                        },
                        onSubmitted: (v) {
                          if (v.trim().isNotEmpty) _submit(v.trim());
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Opacity(
          opacity: contentOpacity,
          child: Container(
            height: 1,
            color: colors.border.withValues(alpha: colors.border.a * 0.4),
          ),
        ),
        // Results / empty state.
        Opacity(
          opacity: contentOpacity,
          child: IgnorePointer(
            ignoring: !info.armed,
            child: filtered.isEmpty
                ? _empty(colors)
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 224),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < filtered.length; i++)
                            WalletRevealItem(
                              index: i,
                              child: _RecentRow(
                                term: filtered[i],
                                armed: info.armed,
                                onTap: () {
                                  _controller.text = filtered[i];
                                  setState(() => _value = filtered[i]);
                                  widget.onChanged?.call(filtered[i]);
                                  _submit(filtered[i]);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _empty(BeuiColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 20,
            color: colors.mutedForeground.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            _value.trim().isNotEmpty ? 'No matches' : 'No recent searches',
            style: TextStyle(fontSize: 14, color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.term,
    required this.armed,
    required this.onTap,
  });

  final String term;
  final bool armed;
  final VoidCallback onTap;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final hoverActive = widget.armed && _hovered;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: hoverActive ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                LucideIcons.rotate_ccw_clock,
                size: 16,
                color: hoverActive ? colors.foreground : colors.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.term,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hoverActive
                        ? colors.foreground
                        : colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
