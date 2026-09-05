import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/icons.dart';
import '../tokens/motion.dart';
import '_engine.dart';
import '_focus_ring.dart';
import '_hit_target.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Lifecycle of a [BeuiImageGeneration] surface
/// (source `ImageGenerationStatus`).
enum BeuiImageGenerationStatus {
  /// Waiting in queue before generation starts.
  queued,

  /// Model is generating the first image.
  generating,

  /// Progressive refinement / detail pass.
  refining,

  /// Final media is ready.
  complete,

  /// Generation failed.
  error,
}

/// Width behavior for the image frame (source `size`).
enum BeuiImageGenerationSize {
  /// Centered, capped at 208px (`max-w-52`).
  compact,

  /// Fills the parent width.
  fluid,
}

// ---------------------------------------------------------------------------
// Media / overlay tables (source MEDIA_STATE / OVERLAY_OPACITY / STATUS_TEXT)
// ---------------------------------------------------------------------------

@immutable
class _MediaState {
  const _MediaState({
    required this.blurPx,
    required this.saturate,
    required this.opacity,
    required this.scale,
  });

  /// CSS blur radius in px (converted via [beuiBlurSigma]).
  final double blurPx;
  final double saturate;
  final double opacity;
  final double scale;
}

const Map<BeuiImageGenerationStatus, _MediaState> _kMediaState = {
  BeuiImageGenerationStatus.queued: _MediaState(
    blurPx: 4,
    saturate: 0.75,
    opacity: 0,
    scale: 1.02,
  ),
  BeuiImageGenerationStatus.generating: _MediaState(
    blurPx: 3,
    saturate: 0.85,
    opacity: 0,
    scale: 1.015,
  ),
  BeuiImageGenerationStatus.refining: _MediaState(
    blurPx: 1.5,
    saturate: 0.95,
    opacity: 0.62,
    scale: 1.005,
  ),
  BeuiImageGenerationStatus.complete: _MediaState(
    blurPx: 0,
    saturate: 1,
    opacity: 1,
    scale: 1,
  ),
  BeuiImageGenerationStatus.error: _MediaState(
    blurPx: 2,
    saturate: 0.5,
    opacity: 0.28,
    scale: 1,
  ),
};

const Map<BeuiImageGenerationStatus, double> _kOverlayOpacity = {
  BeuiImageGenerationStatus.queued: 1,
  BeuiImageGenerationStatus.generating: 1,
  BeuiImageGenerationStatus.refining: 0.48,
  BeuiImageGenerationStatus.complete: 0,
  BeuiImageGenerationStatus.error: 0,
};

const Map<BeuiImageGenerationStatus, String> _kStatusText = {
  BeuiImageGenerationStatus.queued: 'Waiting to generate',
  BeuiImageGenerationStatus.generating: 'Generating image',
  BeuiImageGenerationStatus.refining: 'Refining details',
  BeuiImageGenerationStatus.complete: 'Image ready',
  BeuiImageGenerationStatus.error: 'Generation failed',
};

// ---------------------------------------------------------------------------
// Motion tokens (local curves mirroring source timings)
// ---------------------------------------------------------------------------

/// Media filter / opacity / scale — 400ms EASE_OUT.
const _mediaMotion = CurvedMotion(Duration(milliseconds: 400), beuiEaseOut);

/// Dither-field enter / exit opacity — 250ms EASE_OUT.
const _ditherPresenceMotion = CurvedMotion(
  Duration(milliseconds: 250),
  beuiEaseOut,
);

/// Overlay opacity while active — 400ms EASE_OUT.
const _overlayOpacityMotion = CurvedMotion(
  Duration(milliseconds: 400),
  beuiEaseOut,
);

/// Determinate progress fill — 300ms EASE_OUT.
const _progressMotion = CurvedMotion(Duration(milliseconds: 300), beuiEaseOut);

/// Dither-mark spin period (source `duration: 2.4`).
const _ditherSpinPeriod = Duration(milliseconds: 2400);

const _dotGap = 10.0;
const _compactMaxWidth = 208.0; // max-w-52

/// Height reserved under the status block for the error retry control.
///
/// 40px control + the 12px gap above it. Reserved on *every* status, not just
/// `error`, so arriving at a failure does not shove the rest of the transcript
/// down by 52px at the moment the reader is trying to read it. This component
/// already solves the same problem for the media itself with `AspectRatio`;
/// the error branch was the one place it forgot.
const double _retrySlotHeight = 52;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// CSS `saturate(s)` as a color-matrix filter (Rec. 709 luma weights).
ImageFilter _saturationFilter(double s) {
  final inv = 1 - s;
  final r = 0.2126 * inv;
  final g = 0.7152 * inv;
  final b = 0.0722 * inv;
  return ColorFilter.matrix(<double>[
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0, //
    r, g, b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

bool _isActive(BeuiImageGenerationStatus status) =>
    status == BeuiImageGenerationStatus.queued ||
    status == BeuiImageGenerationStatus.generating ||
    status == BeuiImageGenerationStatus.refining;

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Darkens (or lightens) [foreground] until it clears [target] against
/// [background].
///
/// `BeuiColors.destructive` is tuned as a *fill* — as 12px text on the light
/// surface it measures 3.94:1, under the 4.5:1 that body-sized copy needs, and
/// "Generation failed" is the one line in this widget a reader must not miss.
/// A dedicated `destructiveForeground`-for-text role in `BeuiColors` would be
/// the real fix; until that exists this walks the token's own hue to a legible
/// lightness rather than inventing a second red.
Color _legibleOn(Color foreground, Color background, {double target = 4.5}) {
  if (_contrastRatio(foreground, background) >= target) return foreground;
  final darken = background.computeLuminance() > 0.5;
  var current = foreground;
  for (var step = 0; step < 16; step++) {
    final hsl = HSLColor.fromColor(current);
    final next = (darken ? hsl.lightness - 0.04 : hsl.lightness + 0.04).clamp(
      0.0,
      1.0,
    );
    if (next == hsl.lightness) break;
    current = hsl.withLightness(next).toColor();
    if (_contrastRatio(current, background) >= target) return current;
  }
  return current;
}

// ---------------------------------------------------------------------------
// BeuiImageGeneration
// ---------------------------------------------------------------------------

/// A stable generated-image surface that moves from queued work through
/// progressive refinement to a completed result without layout shift — the
/// Flutter port of beUI's `image-generation`.
///
/// The frame size is reserved via [aspectRatio] so status changes never
/// reflow surrounding content. While active, a dither-dot field overlays the
/// media; on complete/error the media settles (blur/saturate/opacity/scale)
/// and the overlay exits. Pass completed media as [child] (e.g. [Image.network]
/// or a custom preview widget).
///
/// ## Telling the reader how long
///
/// Image generation runs 10–60 seconds. Four words and a 2.4s spinner is the
/// canonical "is it frozen?" surface, so pass [progress] to drive a determinate
/// hairline under the frame, and [onCancel] to give the reader a way out. Both
/// are optional and the widget is unchanged without them.
class BeuiImageGeneration extends StatelessWidget {
  /// Creates a generated-image surface.
  const BeuiImageGeneration({
    this.child,
    this.status = BeuiImageGenerationStatus.generating,
    this.label,
    this.prompt,
    this.resolution = '1024 × 1024',
    this.aspectRatio = 1,
    this.size = BeuiImageGenerationSize.compact,
    this.interactive = true,
    this.statusText,
    this.showStatus = true,
    this.progress,
    this.onCancel,
    this.cancelLabel,
    this.onRetry,
    this.reserveErrorSlot = true,
    super.key,
  });

  /// The completed media. Pass an [Image], custom paint, video placeholder, or
  /// any preview widget (source `children`). Sized to fill the frame.
  final Widget? child;

  /// Lifecycle stage driving media + overlay presentation
  /// (source `status`, default `generating`).
  final BeuiImageGenerationStatus status;

  /// Accessible description. Defaults to status text, optionally including
  /// [prompt] and [progress] (source `label`).
  final String? label;

  /// User prompt shown under the status row (source `prompt`).
  final String? prompt;

  /// Resolution badge in the frame corner. Pass `null` to hide
  /// (source `resolution`, default `"1024 × 1024"`).
  final String? resolution;

  /// Width / height ratio reserved before media is available
  /// (source `aspectRatio`, default `1`).
  final double aspectRatio;

  /// Compact (max 208px centered) or fluid width (source `size`).
  final BeuiImageGenerationSize size;

  /// When true and the pointer can hover, the dither cluster follows the
  /// cursor (source `interactive`, gated by [MouseRegion]).
  final bool interactive;

  /// Override the default status label (source `statusText`).
  final String? statusText;

  /// Whether to show the status mark + label row (source `showStatus`).
  final bool showStatus;

  /// Completion fraction in `0..1`, or null for an indeterminate run.
  ///
  /// Drives a 2px determinate hairline along the bottom of the frame while the
  /// status is active, and is folded into the accessible label and the status
  /// row's live region as a percentage, so the progress is available to a
  /// screen reader and not only to the eye. Values outside `0..1` are clamped.
  final double? progress;

  /// Cancels the run. Shows a stop control inside the frame while active.
  ///
  /// A long generation the reader cannot stop is a surface that owns them
  /// rather than the other way round. Null hides the control entirely.
  final VoidCallback? onCancel;

  /// Accessible name for the stop control. Defaults to
  /// [BeuiAgentStrings.stopGenerating].
  final String? cancelLabel;

  /// Retry action shown on [BeuiImageGenerationStatus.error]
  /// (source `onRetry`).
  final VoidCallback? onRetry;

  /// Whether the retry control's height is held open on every status, so that
  /// arriving at [BeuiImageGenerationStatus.error] costs no layout shift.
  ///
  /// Only has an effect when [onRetry] is set. Defaults to true; pass false if
  /// you would rather have the 52px back on the happy path.
  final bool reserveErrorSlot;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final mediaState = _kMediaState[status]!;
    final resolvedStatusText = statusText ?? _kStatusText[status]!;
    final active = _isActive(status);
    final clampedProgress = progress?.clamp(0.0, 1.0);
    final percent = clampedProgress == null
        ? null
        : (clampedProgress * 100).round();

    // "Generating image, 42%: a quiet mountain landscape at sunset".
    final progressSuffix = (percent != null && active) ? ', $percent%' : '';
    final resolvedLabel =
        label ??
        (prompt != null
            ? '$resolvedStatusText$progressSuffix: $prompt'
            : '$resolvedStatusText$progressSuffix');

    final frame = _ImageFrame(
      colors: colors,
      reduce: reduce,
      status: status,
      mediaState: mediaState,
      active: active,
      aspectRatio: aspectRatio,
      interactive: interactive,
      resolution: resolution,
      label: resolvedLabel,
      progress: clampedProgress,
      onCancel: onCancel,
      // The last hardcoded literal on this surface.
      cancelLabel:
          cancelLabel ?? BeuiAgentTheme.of(context).strings.stopGenerating,
      child: child,
    );

    final showRetryNow =
        status == BeuiImageGenerationStatus.error && onRetry != null;
    final reserveRetry = onRetry != null && reserveErrorSlot;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        frame,
        if (showStatus || prompt != null) ...[
          const SizedBox(height: 12), // mt-3
          _StatusBlock(
            colors: colors,
            reduce: reduce,
            status: status,
            showStatus: showStatus,
            statusText: resolvedStatusText,
            percent: active ? percent : null,
            prompt: prompt,
          ),
        ],
        if (reserveRetry)
          // The slot exists in every status; only its contents fade.
          SizedBox(
            height: _retrySlotHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              curve: beuiEaseOut,
              opacity: showRetryNow ? 1 : 0,
              child: IgnorePointer(
                ignoring: !showRetryNow,
                child: ExcludeSemantics(
                  excluding: !showRetryNow,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12), // mt-3
                    child: _RetryButton(
                      colors: colors,
                      reduce: reduce,
                      onRetry: onRetry!,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (showRetryNow) ...[
          const SizedBox(height: 12), // mt-3
          _RetryButton(colors: colors, reduce: reduce, onRetry: onRetry!),
        ],
      ],
    );

    Widget sized = body;
    if (size == BeuiImageGenerationSize.compact) {
      sized = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _compactMaxWidth),
          child: body,
        ),
      );
    }

    return sized;
  }
}

// ---------------------------------------------------------------------------
// Image frame
// ---------------------------------------------------------------------------

class _ImageFrame extends StatelessWidget {
  const _ImageFrame({
    required this.colors,
    required this.reduce,
    required this.status,
    required this.mediaState,
    required this.active,
    required this.aspectRatio,
    required this.interactive,
    required this.resolution,
    required this.label,
    required this.progress,
    required this.onCancel,
    required this.cancelLabel,
    required this.child,
  });

  final BeuiColors colors;
  final bool reduce;
  final BeuiImageGenerationStatus status;
  final _MediaState mediaState;
  final bool active;
  final double aspectRatio;
  final bool interactive;
  final String? resolution;
  final String label;
  final double? progress;
  final VoidCallback? onCancel;
  final String cancelLabel;
  final Widget? child;

  /// One frame of the media: the four channels resolved to plain numbers.
  ///
  /// Split out so the reduced-motion path can supply snapped values for scale
  /// and blur without duplicating the filter composition.
  Widget _mediaLayer({
    required double opacity,
    required double saturate,
    required double scale,
    required double blurPx,
  }) {
    final sigma = beuiBlurSigma(blurPx);
    // Force children to fill the frame
    // (source `[&>*]:size-full object-cover`).
    Widget media = SizedBox.expand(child: child ?? const SizedBox.shrink());
    if (sigma > 0.05 || (saturate - 1).abs() > 0.01) {
      ImageFilter filter = _saturationFilter(saturate);
      if (sigma > 0.05) {
        filter = ImageFilter.compose(
          outer: filter,
          inner: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
        );
      }
      media = ImageFiltered(imageFilter: filter, child: media);
    }
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        filterQuality: FilterQuality.medium,
        child: media,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The channel split the project rule asks for, not one switch for all four.
    // Opacity and saturation are colour transitions and survive reduced motion;
    // scale and blur are movement and snap. Previously every channel was cut,
    // so the whole reveal hard-swapped.
    final colourMotion = motionFor(context, _mediaMotion, isMovement: false);
    final movementMotion = motionFor(context, _mediaMotion, isMovement: true);
    // NoMotion *holds*; it does not jump. Routing scale and blur through it
    // would freeze them at whatever value the previous status left behind, so
    // the reduced-motion path snaps them to their target explicitly.
    final snapMovement = movementMotion is NoMotion;
    final showCancel = active && onCancel != null;

    return Semantics(
      image: true,
      label: label,
      child: AspectRatio(
        aspectRatio: aspectRatio <= 0 ? 1 : aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.muted,
            borderRadius: BeuiAgentTheme.of(
              context,
            ).shapes.nested, // rounded-xl
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media layer — blur / saturate / opacity / scale.
                SingleMotionBuilder(
                  value: mediaState.opacity,
                  motion: colourMotion,
                  builder: (context, opacity, _) {
                    return SingleMotionBuilder(
                      value: mediaState.saturate,
                      motion: colourMotion,
                      builder: (context, saturate, _) {
                        if (snapMovement) {
                          return _mediaLayer(
                            opacity: opacity,
                            saturate: saturate,
                            scale: mediaState.scale,
                            blurPx: mediaState.blurPx,
                          );
                        }
                        return SingleMotionBuilder(
                          value: mediaState.scale,
                          motion: movementMotion,
                          builder: (context, scale, _) {
                            return SingleMotionBuilder(
                              value: mediaState.blurPx,
                              motion: movementMotion,
                              builder: (context, blurPx, _) => _mediaLayer(
                                opacity: opacity,
                                saturate: saturate,
                                scale: scale,
                                blurPx: blurPx,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),

                // Dither overlay while active (enter/exit 250ms).
                _DitherPresence(
                  active: active,
                  reduce: reduce,
                  status: status,
                  interactive: interactive,
                  colors: colors,
                ),

                // Resolution badge (decorative — excluded so it does not
                // merge into the image semantics label).
                if (resolution != null && resolution!.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            resolution!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              height: 1.4,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Stop control — in-frame, and only while there is something
                // to stop.
                if (showCancel)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _CancelButton(
                      colors: colors,
                      label: cancelLabel,
                      onCancel: onCancel!,
                    ),
                  ),

                // Determinate hairline. 2px, flush to the bottom edge, inside
                // the frame's own clip so it costs no layout.
                if (progress != null && active)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ProgressHairline(value: progress!, colors: colors),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2px determinate fill under an active frame.
class _ProgressHairline extends StatelessWidget {
  const _ProgressHairline({required this.value, required this.colors});

  final double value;
  final BeuiColors colors;

  static Widget _fill(double t, BeuiColors colors) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FractionallySizedBox(
      widthFactor: t.clamp(0.0, 1.0),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.foreground),
        child: const SizedBox(height: 2),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.foreground.withValues(alpha: 0.12),
          ),
          child: Builder(
            builder: (context) {
              final motion = motionFor(
                context,
                _progressMotion,
                isMovement: true,
              );
              // The fill's width is movement, so reduced motion drops the
              // slide — but it has to *snap to the new fraction*, not hold the
              // old one. NoMotion holds, so this branches rather than driving
              // the builder with it and freezing the bar at zero.
              if (motion is NoMotion) return _fill(value, colors);
              return SingleMotionBuilder(
                value: value,
                motion: motion,
                builder: (context, t, _) => _fill(t, colors),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// In-frame stop control, with the full interactive contract.
class _CancelButton extends StatefulWidget {
  const _CancelButton({
    required this.colors,
    required this.label,
    required this.onCancel,
  });

  final BeuiColors colors;
  final String label;
  final VoidCallback onCancel;

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final reduce = MediaQuery.disableAnimationsOf(context);

    // Outermost: a proxy ancestor sized to the 24px paint would clip the slop.
    return BeuiMinHitTarget(
      child: Semantics(
        container: true,
        button: true,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) {
              if (mounted) setState(() => _focused = v);
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onCancel();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onCancel,
              child: SingleMotionBuilder(
                value: (_pressed && !reduce) ? 0.97 : 1.0,
                motion: motionFor(context, beuiSpringPress, isMovement: true),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: BeuiFocusRing(
                  focused: _focused,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: beuiEaseOut,
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? colors.foreground
                          : colors.background.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.square,
                      size: 10,
                      color: _hovered
                          ? colors.background
                          : colors.mutedForeground,
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
// Dither presence (mount while active)
// ---------------------------------------------------------------------------

class _DitherPresence extends StatefulWidget {
  const _DitherPresence({
    required this.active,
    required this.reduce,
    required this.status,
    required this.interactive,
    required this.colors,
  });

  final bool active;
  final bool reduce;
  final BeuiImageGenerationStatus status;
  final bool interactive;
  final BeuiColors colors;

  @override
  State<_DitherPresence> createState() => _DitherPresenceState();
}

class _DitherPresenceState extends State<_DitherPresence> {
  /// Keep the field mounted through the exit fade.
  late bool _mounted = widget.active;

  @override
  void didUpdateWidget(_DitherPresence old) {
    super.didUpdateWidget(old);
    if (widget.active && !_mounted) {
      setState(() => _mounted = true);
    }
  }

  void _onExitComplete() {
    if (!widget.active && mounted) {
      setState(() => _mounted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();

    final presenceTarget = widget.active ? 1.0 : 0.0;
    final overlayTarget = widget.active
        ? (_kOverlayOpacity[widget.status] ?? 0.0)
        : 0.0;
    // Both channels here are opacity, so both survive reduced motion.
    final presenceMotion = motionFor(
      context,
      _ditherPresenceMotion,
      isMovement: false,
    );
    final overlayMotion = motionFor(
      context,
      _overlayOpacityMotion,
      isMovement: false,
    );

    return SingleMotionBuilder(
      value: presenceTarget,
      motion: presenceMotion,
      onAnimationStatusChanged: (status) {
        if (status == AnimationStatus.completed && !widget.active) {
          _onExitComplete();
        }
      },
      builder: (context, presence, child) {
        if (presence <= 0.001 && !widget.active) {
          // Ensure unmount after exit when NoMotion (reduce) or instant settle.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !widget.active) _onExitComplete();
          });
        }
        return Opacity(opacity: presence.clamp(0.0, 1.0), child: child);
      },
      child: SingleMotionBuilder(
        value: overlayTarget,
        motion: overlayMotion,
        builder: (context, overlayOpacity, child) {
          return Opacity(opacity: overlayOpacity.clamp(0.0, 1.0), child: child);
        },
        child: _DitherField(
          interactive: widget.interactive,
          reduce: widget.reduce,
          colors: widget.colors,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dither field (canvas dots)
// ---------------------------------------------------------------------------

class _DitherField extends StatefulWidget {
  const _DitherField({
    required this.interactive,
    required this.reduce,
    required this.colors,
  });

  final bool interactive;
  final bool reduce;
  final BeuiColors colors;

  @override
  State<_DitherField> createState() => _DitherFieldState();
}

class _DitherFieldState extends State<_DitherField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  /// The painter's repaint signal.
  ///
  /// The field used to `setState` on every tick, rebuilding the widget subtree
  /// 60 times a second to move a few hundred circles — and at 500px square that
  /// is ~2,700 circles, so a handful of concurrent generations janked. Driving
  /// the painter from a [ValueNotifier] repaints the canvas without rebuilding
  /// or re-laying-out anything, and the [RepaintBoundary] keeps those repaints
  /// off the rest of the frame.
  final ValueNotifier<Offset> _pointer = ValueNotifier<Offset>(Offset.zero);

  Offset _target = Offset.zero;
  bool _inside = false;
  Size _size = Size.zero;
  bool _sized = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (!widget.reduce) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(_DitherField old) {
    super.didUpdateWidget(old);
    if (widget.reduce != old.reduce) {
      if (widget.reduce) {
        _ticker.stop();
      } else if (!_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pointer.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    _elapsed = elapsed;
    if (!_sized) return;
    _stepPointer();
  }

  void _stepPointer() {
    final w = _size.width;
    final h = _size.height;
    if (!_inside) {
      final t = _elapsed.inMilliseconds.toDouble();
      final ox = widget.reduce ? 0.0 : math.sin(t / 1700) * w * 0.12;
      final oy = widget.reduce ? 0.0 : math.cos(t / 2100) * h * 0.1;
      _target = Offset(w / 2 + ox, h / 2 + oy);
    }
    final follow = widget.reduce ? 1.0 : (_inside ? 0.16 : 0.045);
    final current = _pointer.value;
    _pointer.value = Offset(
      current.dx + (_target.dx - current.dx) * follow,
      current.dy + (_target.dy - current.dy) * follow,
    );
  }

  void _ensureSize(Size size) {
    if (_size == size) return;
    _size = size;
    if (!_sized) {
      _pointer.value = Offset(size.width / 2, size.height / 2);
      _target = _pointer.value;
      _sized = true;
      if (widget.reduce) {
        // One static draw after layout.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _stepPointer();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointerEnabled = widget.interactive && !widget.reduce;

    return ColoredBox(
      color: widget.colors.muted,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _ensureSize(size);
          Widget field = RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _DitherPainter(
                pointer: _pointer,
                color: widget.colors.foreground,
              ),
            ),
          );
          if (pointerEnabled) {
            field = MouseRegion(
              onHover: (event) {
                _inside = true;
                _target = event.localPosition;
              },
              onExit: (_) {
                _inside = false;
              },
              child: field,
            );
          }
          return field;
        },
      ),
    );
  }
}

class _DitherPainter extends CustomPainter {
  _DitherPainter({required this.pointer, required this.color})
    : super(repaint: pointer);

  /// Repaint signal *and* data source — read at paint time, never through a
  /// rebuild.
  final ValueListenable<Offset> pointer;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (width <= 0 || height <= 0) return;

    final origin = pointer.value;
    final radius = math.min(width, height) * 0.38;
    final columns = (width / _dotGap).ceil() + 1;
    final rows = (height / _dotGap).ceil() + 1;
    final offsetX = (width - (columns - 1) * _dotGap) / 2;
    final offsetY = (height - (rows - 1) * _dotGap) / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final anchorX = offsetX + column * _dotGap;
        final anchorY = offsetY + row * _dotGap;
        final deltaX = anchorX - origin.dx;
        final deltaY = anchorY - origin.dy;
        final distance = math.sqrt(deltaX * deltaX + deltaY * deltaY);
        final proximity = math.max(0.0, 1 - distance / radius);
        // smoothstep
        final influence = proximity * proximity * (3 - 2 * proximity);
        final displacement = influence * influence * 9;
        final directionX = distance > 0 ? deltaX / distance : 0.0;
        final directionY = distance > 0 ? deltaY / distance : 0.0;
        final x = anchorX + directionX * displacement;
        final y = anchorY + directionY * displacement;
        final dotRadius = 0.65 + influence * 0.85;
        final alpha = (0.17 + influence * 0.72).clamp(0.0, 1.0);
        paint.color = color.withValues(alpha: alpha);
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DitherPainter old) =>
      old.pointer != pointer || old.color != color;
}

// ---------------------------------------------------------------------------
// Status block
// ---------------------------------------------------------------------------

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.colors,
    required this.reduce,
    required this.status,
    required this.showStatus,
    required this.statusText,
    required this.percent,
    required this.prompt,
  });

  final BeuiColors colors;
  final bool reduce;
  final BeuiImageGenerationStatus status;
  final bool showStatus;
  final String statusText;
  final int? percent;
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final isError = status == BeuiImageGenerationStatus.error;
    // The failure line has to be readable, not merely tinted.
    final statusColor = isError
        ? _legibleOn(colors.destructive, colors.background)
        : colors.foreground;
    final line = percent == null ? statusText : '$statusText · $percent%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showStatus)
          Semantics(
            liveRegion: true,
            label: line,
            child: ExcludeSemantics(
              child: Row(
                children: [
                  _DitherMark(
                    status: status,
                    reduce: reduce,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusLabel(
                      text: line,
                      reduce: reduce,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (prompt != null) ...[
          if (showStatus) const SizedBox(height: 2), // mt-0.5
          Text(
            '“$prompt”',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.text,
    required this.reduce,
    required this.color,
  });

  final String text;
  final bool reduce;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 20 / 14, // text-sm / leading-5
      color: color,
    );

    // Cross-fade + 4px vertical travel on status change (popLayout). Under
    // reduced motion the fade is kept and only the travel is dropped — the
    // label used to hard-swap.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: beuiEaseOut,
      switchOutCurve: beuiEaseOut,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: <Widget>[...previous, ?current],
        );
      },
      transitionBuilder: (child, animation) {
        final fade = FadeTransition(opacity: animation, child: child);
        if (reduce) return fade;
        final isIncoming = (child.key as ValueKey<String>?)?.value == text;
        return FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = beuiEaseOut.transform(animation.value);
              // Incoming: y 4 → 0; outgoing: y 0 → -4 (source popLayout).
              final dy = isIncoming
                  ? lerpDouble(4, 0, t)!
                  : lerpDouble(0, -4, 1 - animation.value)!;
              return Transform.translate(offset: Offset(0, dy), child: child);
            },
            child: child,
          ),
        );
      },
      child: Text(text, key: ValueKey<String>(text), style: style),
    );
  }
}

// ---------------------------------------------------------------------------
// Dither mark (status icon)
// ---------------------------------------------------------------------------

class _DitherMark extends StatefulWidget {
  const _DitherMark({
    required this.status,
    required this.reduce,
    required this.color,
  });

  final BeuiImageGenerationStatus status;
  final bool reduce;
  final Color color;

  @override
  State<_DitherMark> createState() => _DitherMarkState();
}

class _DitherMarkState extends State<_DitherMark>
    with SingleTickerProviderStateMixin {
  // Created in initState so dispose never lazy-inits a ticker against a
  // deactivated ancestor (see bloom_menu / SingleTickerProviderStateMixin).
  late final AnimationController _spin;

  bool get _shouldSpin =>
      !widget.reduce &&
      widget.status != BeuiImageGenerationStatus.complete &&
      widget.status != BeuiImageGenerationStatus.error;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: _ditherSpinPeriod);
    if (_shouldSpin) _spin.repeat();
  }

  @override
  void didUpdateWidget(_DitherMark old) {
    super.didUpdateWidget(old);
    if (_shouldSpin) {
      if (!_spin.isAnimating) _spin.repeat();
    } else if (_spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == BeuiImageGenerationStatus.complete) {
      return Icon(LucideIcons.check, size: 14, color: widget.color);
    }
    if (widget.status == BeuiImageGenerationStatus.error) {
      return Icon(LucideIcons.circle_alert, size: 14, color: widget.color);
    }

    // 2×2 dither cluster (size-3.5 / gap-0.5 / size-1 dots).
    Widget cluster = SizedBox(
      width: 14,
      height: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_dot(1), _dot(0.55)],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_dot(0.55), _dot(1)],
          ),
        ],
      ),
    );

    if (!_shouldSpin) return cluster;

    return AnimatedBuilder(
      animation: _spin,
      builder: (context, child) {
        // EASE_IN_OUT over full turns (source ease: EASE_IN_OUT, rotate 360).
        final turns = beuiEaseInOut.transform(_spin.value);
        return Transform.rotate(angle: turns * math.pi * 2, child: child);
      },
      child: cluster,
    );
  }

  Widget _dot(double opacity) {
    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(1),
        ),
        child: const SizedBox(width: 4, height: 4),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retry button
// ---------------------------------------------------------------------------

class _RetryButton extends StatefulWidget {
  const _RetryButton({
    required this.colors,
    required this.reduce,
    required this.onRetry,
  });

  final BeuiColors colors;
  final bool reduce;
  final VoidCallback onRetry;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scale = (!widget.reduce && _pressed) ? 0.97 : 1.0;
    final bg = _hovered ? widget.colors.muted : Colors.transparent;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Try again',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            onShowFocusHighlight: (v) {
              if (mounted) setState(() => _focused = v);
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onRetry();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onRetry,
              child: SingleMotionBuilder(
                value: scale,
                motion: motionFor(context, beuiSpringPress, isMovement: true),
                builder: (context, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: BeuiFocusRing(
                  focused: _focused,
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.rotate_ccw,
                          size: 16,
                          color: widget.colors.foreground,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try again',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: widget.colors.foreground,
                          ),
                        ),
                      ],
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
