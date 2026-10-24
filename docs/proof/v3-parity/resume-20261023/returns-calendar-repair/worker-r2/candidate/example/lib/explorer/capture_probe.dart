import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'capture_probe_stub.dart'
    if (dart.library.js_interop) 'capture_probe_web.dart';

/// Opt-in observation of the settings and layout delivered to a demo.
/// This does not set accessibility preferences or change child constraints.
class CaptureProbe extends StatelessWidget {
  const CaptureProbe({
    super.key,
    required this.child,
    required this.background,
    required this.enabled,
  });

  final Widget child;
  final Color background;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return _Probe(
      values: {
        'disableAnimations': MediaQuery.disableAnimationsOf(context),
        'platformDisableAnimations': View.of(
          context,
        ).platformDispatcher.accessibilityFeatures.disableAnimations,
        'motionOverride': null,
        'backgroundArgb': background.toARGB32(),
      },
      child: child,
    );
  }
}

class _Probe extends SingleChildRenderObjectWidget {
  const _Probe({required this.values, required super.child});

  final Map<String, Object?> values;

  @override
  RenderObject createRenderObject(BuildContext context) => _ProbeBox(values);

  @override
  void updateRenderObject(BuildContext context, _ProbeBox renderObject) {
    renderObject.values = values;
    renderObject.markNeedsPaint();
  }
}

class _ProbeBox extends RenderProxyBox {
  _ProbeBox(this.values);

  Map<String, Object?> values;

  @override
  void paint(PaintingContext context, Offset offset) {
    final position = localToGlobal(Offset.zero);
    publishCaptureProbe({
      ...values,
      'constraints': {
        'minWidth': constraints.minWidth,
        'maxWidth': constraints.maxWidth.isFinite ? constraints.maxWidth : null,
        'minHeight': constraints.minHeight,
        'maxHeight': constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null,
      },
      'rect': {
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
      },
    });
    super.paint(context, offset);
  }
}
