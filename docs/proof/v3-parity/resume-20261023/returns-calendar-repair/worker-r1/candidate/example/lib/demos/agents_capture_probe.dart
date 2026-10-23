import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'agents_capture_publish.dart'
    if (dart.library.js_interop) 'agents_capture_publish_web.dart';

/// Observes the demo without overriding browser accessibility preferences.
class AgentsCaptureProbe extends StatelessWidget {
  const AgentsCaptureProbe({
    super.key,
    required this.child,
    required this.background,
  });

  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) => _Probe(
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
