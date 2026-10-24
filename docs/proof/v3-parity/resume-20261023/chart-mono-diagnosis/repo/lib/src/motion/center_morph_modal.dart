import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../overlay/beui_overlay.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';

/// Source unfold easing `cubic-bezier(0.2, 0, 0.2, 1)` — deliberately not a
/// spring: complex inset clip-paths can snap when a spring settles its last
/// distance, so the source keeps a fixed-radius cubic over 430ms.
const _centerUnfoldEase = Cubic(0.2, 0, 0.2, 1);

/// Folded clip: `inset(48% 48% 48% 48% round 30px)` — a 4% sliver at center.
const _foldedInset = 0.48;

/// Panel corner radius (source `rounded-[30px]` / clip-path `round 30px`).
const _panelRadius = 30.0;

/// Max panel width (source `max-w-[26rem]`).
const _maxPanelWidth = 26 * 16.0; // 416

/// A modal whose full-size surface **unfolds outward from its exact center**
/// toward every edge, then folds back the same way with an inset close control
/// — the Flutter port of beUI's `center-morph-modal`, built on [BeuiOverlay].
///
/// Driven by controlled [open] + [onOpenChange]. The panel rides a 430ms
/// `cubic-bezier(0.2, 0, 0.2, 1)` inset clip-path morph (not a spring — see
/// [_centerUnfoldEase]); the frosted backdrop fades 280ms [beuiEaseOut].
/// Reduced motion drops the clip morph and fades opacity only (140ms panel,
/// 100ms barrier).
///
/// Close on backdrop tap / Esc when [dismissible]; the inset close button
/// always calls [onOpenChange] with `false`.
class BeuiCenterMorphModal extends StatelessWidget {
  /// Creates a center-morph modal whose [child] is the panel content.
  const BeuiCenterMorphModal({
    required this.open,
    required this.onOpenChange,
    required this.child,
    this.label,
    this.dismissible = true,
    this.showCloseButton = true,
    this.closeButtonLabel = 'Close modal',
    this.closeIcon,
    super.key,
  });

  /// Whether the modal is open (controlled by the consumer).
  final bool open;

  /// Called when the modal requests open-state change (backdrop / Esc / close).
  final ValueChanged<bool> onOpenChange;

  /// The panel body content (padding is the caller's responsibility).
  final Widget child;

  /// Accessibility name for the dialog (`aria-label` in the source).
  final String? label;

  /// Close on Escape or backdrop press. Default `true`.
  final bool dismissible;

  /// Render the inset close control in the panel's top-right. Default `true`.
  final bool showCloseButton;

  /// Semantics label for the close control.
  final String closeButtonLabel;

  /// Glyph for the close control. Defaults to [LucideIcons.x].
  final IconData? closeIcon;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final colors = BeuiColors.resolve(context);

    return BeuiOverlay(
      open: open,
      barrier: true,
      // source: bg-background/10 + backdrop-blur-sm
      barrierColor: colors.background.withValues(alpha: 0.10),
      barrierBlur: beuiBlurSigma(4), // blur-sm (4px) → σ2
      barrierDismissible: dismissible,
      barrierEnterDuration: Duration(milliseconds: reduce ? 100 : 280),
      barrierExitDuration: Duration(milliseconds: reduce ? 100 : 280),
      barrierCurve: beuiEaseOut,
      onDismiss: dismissible ? () => onOpenChange(false) : null,
      // Panel envelope matches CENTER_UNFOLD_TRANSITION (430ms) so exit keeps
      // the portal mounted until the fold has finished. Reduced: 140ms fade.
      enterDuration: Duration(milliseconds: reduce ? 140 : 430),
      exitDuration: Duration(milliseconds: reduce ? 140 : 430),
      overlayBuilder: (context, animation, link) => _CenterMorphPanel(
        animation: animation,
        colors: colors,
        label: label,
        showCloseButton: showCloseButton,
        closeButtonLabel: closeButtonLabel,
        closeIcon: closeIcon ?? LucideIcons.x,
        onClose: () => onOpenChange(false),
        child: child,
      ),
      child: const SizedBox.shrink(),
    );
  }
}

class _CenterMorphPanel extends StatelessWidget {
  const _CenterMorphPanel({
    required this.animation,
    required this.colors,
    required this.label,
    required this.showCloseButton,
    required this.closeButtonLabel,
    required this.closeIcon,
    required this.onClose,
    required this.child,
  });

  final Animation<double> animation;
  final BeuiColors colors;
  final String? label;
  final bool showCloseButton;
  final String closeButtonLabel;
  final IconData closeIcon;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final width = math.min(
      _maxPanelWidth,
      MediaQuery.sizeOf(context).width - 32, // p-4 gutters
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final raw = animation.value.clamp(0.0, 1.0);
        final t = reduce
            ? beuiEaseOut.transform(raw)
            : _centerUnfoldEase.transform(raw);

        final interactive =
            animation.status == AnimationStatus.forward ||
            animation.status == AnimationStatus.completed;

        // Close button: delay 160ms / 200ms of the 430ms envelope
        // (source delay 0.16, duration 0.2). Exit fades faster (100ms).
        final double closeOpacity;
        final double closeScale;
        if (reduce) {
          closeOpacity = beuiEaseOut.transform(raw);
          closeScale = 1.0;
        } else if (animation.status == AnimationStatus.reverse ||
            animation.status == AnimationStatus.dismissed) {
          // Exit: opacity 0 + scale 0.88 over ~100ms of the reverse.
          final p = (1 - raw).clamp(0.0, 1.0);
          final e = beuiEaseOut.transform(math.min(1.0, p / (100 / 430)));
          closeOpacity = 1 - e;
          closeScale = 1 - 0.12 * e; // → 0.88
        } else {
          // Enter: idle until 160ms, then 200ms ease to full.
          const start = 160 / 430;
          const end = (160 + 200) / 430;
          final local = ((raw - start) / (end - start)).clamp(0.0, 1.0);
          final e = beuiEaseOut.transform(local);
          closeOpacity = e;
          closeScale = 0.8 + 0.2 * e;
        }

        final panel = Material(
          key: const ValueKey('beui_center_morph_modal_panel'),
          type: MaterialType.transparency,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: label,
            explicitChildNodes: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(_panelRadius),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: colors.foreground),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child,
                    if (showCloseButton)
                      Positioned(
                        top: 16, // top-4
                        right: 16, // right-4
                        child: Opacity(
                          opacity: closeOpacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: closeScale,
                            child: _CloseButton(
                              label: closeButtonLabel,
                              icon: closeIcon,
                              colors: colors,
                              onPressed: onClose,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        // Clip-path unfold (source inset 48% → 0%, constant 30px radius).
        // Drop-shadow-2xl rides the panel; under motion the clip hides most of
        // the panel so the soft shadow reads as following the silhouette.
        Widget surface = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_panelRadius),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25 * (reduce ? t : 1.0)),
                blurRadius: 50,
                spreadRadius: -12,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: reduce
              ? panel
              : ClipPath(
                  clipper: _CenterInsetClipper(
                    progress: t,
                    radius: _panelRadius,
                  ),
                  child: panel,
                ),
        );
        if (reduce) {
          surface = Opacity(opacity: t.clamp(0.0, 1.0), child: surface);
        }

        return Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: IgnorePointer(
              ignoring: !interactive,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width),
                child: surface,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Inset close control — 32×32 circle, muted glyph, soft hover fill.
class _CloseButton extends StatefulWidget {
  const _CloseButton({
    required this.label,
    required this.icon,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: colors.foreground.withValues(alpha: _hover ? 0.08 : 0.05),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onPressed,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                widget.icon,
                size: 16,
                color: _hover ? colors.foreground : colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Center-outward `inset(48%…) → inset(0%… round radius)` clip-path morph.
/// Radius stays constant so the whole duration reads as surface unfolding
/// rather than finishing early on corner rounding (source comment).
class _CenterInsetClipper extends CustomClipper<Path> {
  const _CenterInsetClipper({required this.progress, required this.radius});

  /// 0 = fully folded (4% center sliver), 1 = fully open.
  final double progress;
  final double radius;

  @override
  Path getClip(Size size) {
    final inset = _foldedInset * (1.0 - progress.clamp(0.0, 1.0));
    final rect = Rect.fromLTRB(
      size.width * inset,
      size.height * inset,
      size.width * (1 - inset),
      size.height * (1 - inset),
    );
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  }

  @override
  bool shouldReclip(_CenterInsetClipper old) =>
      old.progress != progress || old.radius != radius;
}
