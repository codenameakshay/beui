import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Gallery route for [BeuiVoiceOrb], matching the source's simulated activity.
Widget voiceOrbDemo(BuildContext context, {String? fixture}) =>
    _VoiceOrbDemo(fixture: fixture ?? Uri.base.queryParameters['orbFixture']);

class _VoiceOrbDemo extends StatelessWidget {
  const _VoiceOrbDemo({this.fixture});

  final String? fixture;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: fixture == 'renderer-error'
          ? const _OrbErrorPreview()
          : _SimulatedOrb(
              size: MediaQuery.sizeOf(context).width < 640 ? 256 : 288,
            ),
    );
  }
}

class _OrbErrorPreview extends StatefulWidget {
  const _OrbErrorPreview();

  @override
  State<_OrbErrorPreview> createState() => _OrbErrorPreviewState();
}

class _OrbErrorPreviewState extends State<_OrbErrorPreview> {
  bool _observed = false;

  @override
  void initState() {
    super.initState();
    // ignore: invalid_use_of_visible_for_testing_member
    BeuiVoiceOrb.debugLoadError = StateError(
      'Explicit renderer-error demo fixture',
    );
  }

  @override
  void dispose() {
    // ignore: invalid_use_of_visible_for_testing_member
    BeuiVoiceOrb.debugLoadError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: _observed ? 'Renderer error observed' : 'Waiting for renderer error',
    child: BeuiVoiceOrb(
      size: MediaQuery.sizeOf(context).width < 640 ? 256 : 288,
      semanticLabel: 'Voice visualization',
      onError: (_) => setState(() => _observed = true),
    ),
  );
}

class _SimulatedOrb extends StatefulWidget {
  const _SimulatedOrb({required this.size});

  final double size;

  @override
  State<_SimulatedOrb> createState() => _SimulatedOrbState();
}

class _SimulatedOrbState extends State<_SimulatedOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _activity = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce && _ticker.isActive) {
      _activity.value = 0;
      _ticker.stop();
    } else if (!reduce && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _activity.value = 0;
      return;
    }
    // Source preview: simulated syllables and pauses, no microphone.
    final t = elapsed.inMicroseconds / 1e6;
    final phrase = math.max(0.0, math.sin(t * 0.85));
    final syllable = math.max(0.0, math.sin(t * 9.3 + math.sin(t * 2.1)));
    _activity.value = phrase * (0.12 + syllable * syllable * 0.72);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BeuiVoiceOrb(
      activityListenable: _activity,
      size: widget.size,
      semanticLabel: 'Voice visualization',
    );
  }
}
