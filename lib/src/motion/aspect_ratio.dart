import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '_engine.dart';

/// Test handle on an aspect-ratio frame.
@visibleForTesting
const beuiAspectRatioFrameKey = ValueKey<String>('beui_aspect_ratio_frame');

/// A responsive frame whose width-to-height ratio can morph with a spring.
///
/// [ratio] is width divided by height and must be finite and positive. The
/// frame fills its available width (or fits its available height when width is
/// unbounded). Reduced motion and [animated] false apply ratio changes at once.
class BeuiAspectRatio extends StatelessWidget {
  /// Creates an aspect-ratio frame, defaulting to a square.
  const BeuiAspectRatio({
    this.ratio = 1,
    this.animated = true,
    this.child,
    super.key,
  });

  /// Width divided by height. Must be finite and positive.
  final double ratio;

  /// Whether frame size changes spring to the new ratio.
  final bool animated;

  /// Content clipped to the frame.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!ratio.isFinite || ratio <= 0) {
      throw RangeError.value(ratio, 'ratio', 'Must be finite and positive');
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : constraints.hasBoundedHeight
            ? constraints.maxHeight * ratio
            : ratio;
        final size = Size(width, width / ratio);
        final content = ClipRect(
          child: Stack(fit: StackFit.expand, children: [?child]),
        );

        if (!animated || reduce) {
          return SizedBox(
            key: beuiAspectRatioFrameKey,
            width: size.width,
            height: size.height,
            child: content,
          );
        }

        return MotionBuilder<Size>(
          value: size,
          converter: const SizeMotionConverter(),
          motion: motionFor(context, beuiSpringLayout, isMovement: true),
          builder: (context, current, child) => SizedBox(
            key: beuiAspectRatioFrameKey,
            width: current.width,
            height: current.height,
            child: child,
          ),
          child: content,
        );
      },
    );
  }
}

/// An image that fills and cover-crops its enclosing [BeuiAspectRatio].
///
/// Supply an [ImageProvider] to keep loading policy under the caller's control;
/// tests can use [MemoryImage] without making network requests. [width] and
/// [height] describe the positive intrinsic dimensions of the source image.
class BeuiAspectRatioImage extends StatelessWidget {
  /// Creates a cover-cropped image with an accessibility description.
  const BeuiAspectRatioImage({
    required this.image,
    required this.alt,
    required this.width,
    required this.height,
    super.key,
  });

  /// The image source.
  final ImageProvider image;

  /// Text alternative announced by accessibility services.
  final String alt;

  /// Intrinsic image width in pixels.
  final double width;

  /// Intrinsic image height in pixels.
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!width.isFinite || width <= 0 || !height.isFinite || height <= 0) {
      throw RangeError('Image width and height must be finite and positive.');
    }
    return Semantics(
      image: true,
      label: alt,
      child: ExcludeSemantics(
        child: Image(
          image: image,
          width: width,
          height: height,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
