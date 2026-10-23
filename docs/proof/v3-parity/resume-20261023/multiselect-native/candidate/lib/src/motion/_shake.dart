/// The error-shake keyframe interpolator shared by the input, OTP, and
/// prediction-market widgets.
library;

import 'package:flutter/animation.dart';

/// Bounces x across [frames] as [t] runs 0 → 1.
///
/// [curve] shapes the motion. When [perSegment] is true (the default) the
/// curve is applied independently within each segment, matching Framer's
/// per-keyframe-segment easing expansion — used by `BeuiInput` and
/// `BeuiOtpInput`. When false the curve is applied once to `t` globally
/// before splitting into segments, then interpolation between frames is
/// linear — used by the prediction-market amount card.
double beuiShakeOffset(
  double t,
  List<double> frames,
  Curve curve, {
  bool perSegment = true,
}) {
  final segments = frames.length - 1;
  if (perSegment) {
    final pos = t.clamp(0.0, 1.0) * segments;
    final i = pos.floor().clamp(0, segments - 1);
    final local = curve.transform((pos - i).clamp(0.0, 1.0));
    return frames[i] + (frames[i + 1] - frames[i]) * local;
  }
  final eased = curve.transform(t.clamp(0.0, 1.0));
  final pos = eased * segments;
  final i = pos.floor().clamp(0, segments - 1);
  return frames[i] + (frames[i + 1] - frames[i]) * (pos - i);
}
