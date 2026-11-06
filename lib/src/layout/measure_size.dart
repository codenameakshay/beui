import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports changes to the child's laid-out local size after the frame.
class BeuiMeasureSize extends SingleChildRenderObjectWidget {
  const BeuiMeasureSize({
    required this.onChanged,
    required super.child,
    super.key,
  });

  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBeuiMeasureSize(onChanged);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderBeuiMeasureSize).onChanged = onChanged;
  }
}

class _RenderBeuiMeasureSize extends RenderProxyBox {
  _RenderBeuiMeasureSize(this._onChanged);

  ValueChanged<Size> _onChanged;
  Size? _lastDeliveredSize;
  Size? _pendingSize;
  int _attachmentGeneration = 0;
  bool _deliveryScheduled = false;

  set onChanged(ValueChanged<Size> value) {
    _onChanged = value;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    markNeedsLayout();
  }

  @override
  void detach() {
    _attachmentGeneration++;
    _pendingSize = null;
    _deliveryScheduled = false;
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();

    if (size == _lastDeliveredSize) {
      _pendingSize = null;
      return;
    }

    _pendingSize = size;
    if (_deliveryScheduled) return;

    _deliveryScheduled = true;
    final generation = _attachmentGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || generation != _attachmentGeneration) return;

      final changedSize = _pendingSize;
      _pendingSize = null;
      _deliveryScheduled = false;
      if (changedSize == null || changedSize == _lastDeliveredSize) return;

      _lastDeliveredSize = changedSize;
      _onChanged(changedSize);
    });
  }
}
