import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';
import '../tokens/motion.dart';
import '_engine.dart';

/// Caller-owned time-domain sampler. The orb never opens a microphone.
///
/// Mirrors Web Audio's `AnalyserNode.getByteTimeDomainData`. Pass one to
/// [BeuiVoiceOrb.analyser] to drive the silhouette from live audio; omit it
/// and feed a normalized [BeuiVoiceOrb.activity] (or [BeuiVoiceOrb.activityListenable])
/// instead.
abstract class BeuiVoiceAnalyser {
  /// FFT size used to allocate the time-domain buffer.
  int get fftSize;

  /// Fills [destination] with unsigned 8-bit PCM, 128 = silence.
  void getByteTimeDomainData(Uint8List destination);
}

/// Source `SPRING_GLIDE` — stiffness 700 · damping 50 · mass 0.5.
///
/// Why local: `ease.ts` files this as a critically-damped follow spring for
/// dragged fills *and* the voice-orb silhouette. The slider family already
/// owns a copy as `beuiSliderGlideSpring`; this widget keeps its own named
/// const so a slider retune cannot change the orb's breath.
const _glideSpring = SpringMotion(
  SpringDescription(mass: 0.5, stiffness: 700, damping: 50),
);

/// Default pigments: base, highlight, shadow (source `#e8754d`, `#ffe0ac`,
/// `#346b52`).
const (Color, Color, Color) kBeuiVoiceOrbColors = (
  Color(0xFFE8754D),
  Color(0xFFFFE0AC),
  Color(0xFF346B52),
);

/// Source `w-64` / `aspect-square`.
const double kBeuiVoiceOrbSize = 256;

@visibleForTesting
const beuiVoiceOrbCanvasKey = ValueKey<String>('beui_voice_orb_canvas');

@visibleForTesting
const beuiVoiceOrbErrorKey = ValueKey<String>('beui_voice_orb_error');

double _level(double value) => value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

double _speedOf(double value) => value.isFinite ? math.max(0.0, value) : 1.0;

/// A breathing liquid voice visualization — the Flutter port of beUI's
/// `VoiceOrb`.
///
/// The surface is a fragment shader with three custom pigments. Activity
/// (0..1) springs the silhouette up and slightly wider via [_glideSpring];
/// the same smoothed value ripples the shader. Pass a number, a
/// [ValueListenable] (the MotionValue analog — updates without rebuilding
/// the configuration), or a caller-owned [BeuiVoiceAnalyser]. The orb never
/// requests a microphone.
///
/// Pauses when offscreen, when the app is hidden, or when [active] is false.
/// Reduced motion freezes the material and drops the silhouette reaction.
class BeuiVoiceOrb extends StatefulWidget {
  /// Creates a voice orb.
  const BeuiVoiceOrb({
    this.activity = 0,
    this.activityListenable,
    this.analyser,
    this.colors = kBeuiVoiceOrbColors,
    this.active = true,
    this.speed = 1,
    this.onError,
    this.semanticLabel,
    super.key,
  });

  /// Normalized activity, 0 to 1. Ignored while [activityListenable] or a
  /// live [analyser] is driving the level.
  final double activity;

  /// High-frequency activity source. The analog of a Framer `MotionValue`
  /// — changing it does not rebuild this widget's configuration.
  final ValueListenable<double>? activityListenable;

  /// Optional caller-owned analyser. Sampled each frame while [active] and
  /// motion is enabled; never retained past dispose.
  final BeuiVoiceAnalyser? analyser;

  /// Base pigment, highlight and shadow.
  final (Color, Color, Color) colors;

  /// Pause the material while keeping the current surface visible.
  final bool active;

  /// Shader clock multiplier. Non-finite values fall back to 1; negatives
  /// clamp to 0.
  final double speed;

  /// Called if the fragment program fails to load or paint.
  final ValueChanged<Object>? onError;

  /// Accessible name. When null the orb is hidden from assistive
  /// technology (source `aria-hidden` when no `aria-label`).
  final String? semanticLabel;

  /// Test hook: when non-null, [_BeuiVoiceOrbState] fails to load the
  /// program and shows the error fallback. Reset in `addTearDown`.
  @visibleForTesting
  static Object? debugLoadError;

  @override
  State<BeuiVoiceOrb> createState() => _BeuiVoiceOrbState();
}

class _BeuiVoiceOrbState extends State<BeuiVoiceOrb>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final Map<String, ui.FragmentProgram> _programCache = {};

  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  ui.FragmentShader? _shader;
  Object? _error;

  double _target = 0;
  double _smoothActivity = 0;
  double _shaderTime = 0;
  Duration? _previousTick;
  Uint8List? _sample;
  bool _visible = true;
  bool _appResumed = true;
  bool? _tickerModeEnabled;
  bool _visibilityCheckScheduled = false;
  bool _paintErrorPending = false;
  Set<ScrollPosition> _scrollPositions = {};

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  bool get _live => widget.active && !_reduced;

  bool get _animated =>
      _live && (_speedOf(widget.speed) > 0 || widget.analyser != null);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _target = _level(widget.activityListenable?.value ?? widget.activity);
    widget.activityListenable?.addListener(_onListenable);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    if (_tickerModeEnabled != null && _tickerModeEnabled != tickerModeEnabled) {
      _previousTick = null;
    }
    _tickerModeEnabled = tickerModeEnabled;
    _appResumed = _lifecycleResumed(WidgetsBinding.instance.lifecycleState);
    _attachScroll();
    _syncTargetFromInputs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkVisibility();
        _syncTicker();
      }
    });
  }

  @override
  void didUpdateWidget(BeuiVoiceOrb old) {
    super.didUpdateWidget(old);
    if (old.activityListenable != widget.activityListenable) {
      old.activityListenable?.removeListener(_onListenable);
      widget.activityListenable?.addListener(_onListenable);
    }
    _syncTargetFromInputs();
    _syncTicker();
  }

  void _syncTargetFromInputs() {
    if (!_live) {
      _setTarget(0);
      return;
    }
    if (widget.analyser != null) return;
    _setTarget(_level(widget.activityListenable?.value ?? widget.activity));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = _lifecycleResumed(state);
    if (!_appResumed) {
      _previousTick = null;
      _ticker.stop();
    } else {
      _syncTicker();
    }
  }

  static bool _lifecycleResumed(AppLifecycleState? state) =>
      state != AppLifecycleState.paused &&
      state != AppLifecycleState.hidden &&
      state != AppLifecycleState.detached;

  void _onListenable() {
    if (!_live || widget.analyser != null) return;
    _setTarget(_level(widget.activityListenable!.value));
  }

  void _setTarget(double next) {
    if (!_live) {
      if (_target != 0) setState(() => _target = 0);
      return;
    }
    if (next == _target) return;
    setState(() => _target = next);
  }

  Future<void> _load() async {
    try {
      // Yield so setState never runs inside initState. A zero-delay timer
      // would stall in widget tests (they do not elapse timers on pump()).
      await Future<void>.value();
      if (!mounted) return;
      final injected = BeuiVoiceOrb.debugLoadError;
      if (injected != null) throw injected;
      var program = _programCache['shaders/beui_voice_orb.frag'];
      program ??= _programCache['shaders/beui_voice_orb.frag'] =
          await _loadProgram('shaders/beui_voice_orb.frag');
      if (!mounted) return;
      _shader?.dispose();
      // Not _syncTicker() here: MediaQuery is illegal before the first
      // build. The post-frame callback in build() owns ticker syncing.
      setState(() {
        _shader = program!.fragmentShader();
        _error = null;
      });
    } catch (error) {
      _fail(error);
    }
  }

  static Future<ui.FragmentProgram> _loadProgram(String bare) async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/beui/$bare');
    } on Exception {
      return ui.FragmentProgram.fromAsset(bare);
    } on FlutterError {
      return ui.FragmentProgram.fromAsset(bare);
    }
  }

  void _fail(Object error) {
    final wrapped = error is Error || error is Exception
        ? error
        : Exception(error.toString());
    if (!mounted || _error != null) return;
    setState(() => _error = wrapped);
    _previousTick = null;
    _ticker.stop();
    widget.onError?.call(wrapped);
  }

  void _attachScroll() {
    final next = <ScrollPosition>{};
    final nearestPosition = Scrollable.maybeOf(context)?.position;
    if (nearestPosition != null) next.add(nearestPosition);
    context.visitAncestorElements((element) {
      if (element is StatefulElement) {
        final state = element.state;
        if (state is ScrollableState) next.add(state.position);
      }
      return true;
    });
    for (final position in _scrollPositions.difference(next)) {
      position.removeListener(_scheduleVisibilityCheck);
    }
    for (final position in next.difference(_scrollPositions)) {
      position.addListener(_scheduleVisibilityCheck);
    }
    _scrollPositions = next;
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (mounted) _checkVisibility();
    });
  }

  void _checkVisibility() {
    final box = context.findRenderObject() as RenderBox?;
    var visible = true;
    if (box != null && box.hasSize && box.attached) {
      var visibleRect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      final size = MediaQuery.sizeOf(context);
      final screenRect = Offset.zero & size;
      visible = visibleRect.overlaps(screenRect);
      if (visible) visibleRect = visibleRect.intersect(screenRect);

      RenderObject child = box;
      RenderObject? ancestor = child.parent;
      while (visible && ancestor != null) {
        final clip = ancestor.describeApproximatePaintClip(child);
        if (clip != null) {
          final clipRect = MatrixUtils.transformRect(
            ancestor.getTransformTo(null),
            clip,
          );
          visible = visibleRect.overlaps(clipRect);
          if (visible) visibleRect = visibleRect.intersect(clipRect);
        }
        child = ancestor;
        ancestor = ancestor.parent;
      }
    }
    if (visible == _visible) return;
    _visible = visible;
    if (!visible) _previousTick = null;
    _syncTicker();
  }

  void _syncTicker() {
    if (!mounted) return;
    final shouldRun =
        _shader != null &&
        _error == null &&
        _animated &&
        _visible &&
        _appResumed &&
        (_tickerModeEnabled ?? true);
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _previousTick = null;
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    if (!_visible || !_appResumed || _error != null) {
      _previousTick = null;
      return;
    }
    if (widget.analyser != null && _live) {
      _sampleAnalyser();
    }
    if (_animated && _previousTick != null) {
      final dt = math.min(
        0.05,
        (elapsed - _previousTick!).inMicroseconds / 1e6,
      );
      _shaderTime += dt * _speedOf(widget.speed) * (1 + _smoothActivity * 0.6);
    }
    _previousTick = _animated ? elapsed : null;
    _time.value = _shaderTime;
  }

  void _sampleAnalyser() {
    final analyser = widget.analyser!;
    if (_sample == null || _sample!.length != analyser.fftSize) {
      _sample = Uint8List(analyser.fftSize);
    }
    analyser.getByteTimeDomainData(_sample!);
    var sum = 0.0;
    for (final byte in _sample!) {
      final n = (byte - 128) / 128.0;
      sum += n * n;
    }
    _setTarget(_level(math.sqrt(sum / _sample!.length) * 3));
  }

  void _onPaintError(Object error) {
    if (!mounted || _paintErrorPending || _error != null) return;
    _paintErrorPending = true;
    _previousTick = null;
    _ticker.stop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paintErrorPending = false;
      if (!mounted || _error != null) return;
      _fail(error);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.activityListenable?.removeListener(_onListenable);
    for (final position in _scrollPositions) {
      position.removeListener(_scheduleVisibilityCheck);
    }
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScroll();
      _checkVisibility();
      _syncTicker();
    });

    final reduce = _reduced;
    final live = widget.active && !reduce;

    Widget shell(double smooth) {
      final activity = live ? _level(smooth) : 0.0;
      _smoothActivity = activity;
      Widget surface;
      if (_error != null) {
        surface = _ErrorFallback(key: beuiVoiceOrbErrorKey);
      } else {
        final shader = _shader;
        surface = CustomPaint(
          key: beuiVoiceOrbCanvasKey,
          painter: shader == null
              ? null
              : _OrbPainter(
                  shader: shader,
                  time: _time,
                  activity: activity,
                  colors: widget.colors,
                  onError: _onPaintError,
                ),
          child: const SizedBox.expand(),
        );
      }

      if (reduce) return surface;
      return Transform.translate(
        offset: Offset(0, -smooth * 2),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            1 + smooth * 0.04,
            1 - smooth * 0.018,
            1,
          ),
          child: surface,
        ),
      );
    }

    final child = reduce
        ? shell(0)
        : SingleMotionBuilder(
            value: live ? _target : 0,
            motion: motionFor(context, _glideSpring, isMovement: true),
            builder: (context, smooth, _) => shell(smooth),
          );

    Widget box = SizedBox.square(dimension: kBeuiVoiceOrbSize, child: child);

    final label = widget.semanticLabel;
    if (label == null || label.isEmpty) {
      box = ExcludeSemantics(child: box);
    } else {
      // aria-label on role=img replaces contents; keep fallback copy visual.
      box = Semantics(
        container: true,
        image: true,
        label: label,
        excludeSemantics: true,
        child: box,
      );
    }
    return box;
  }
}

class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    final strings = BeuiAgentTheme.of(context).strings;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.card,
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              strings.orbUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 16 / 12,
                color: colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.shader,
    required this.time,
    required this.activity,
    required this.colors,
    required this.onError,
  }) : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double activity;
  final (Color, Color, Color) colors;
  final ValueChanged<Object> onError;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    try {
      var i = 0;
      void f(double v) => shader.setFloat(i++, v);
      void rgb(Color c) {
        f(c.r);
        f(c.g);
        f(c.b);
      }

      f(size.width);
      f(size.height);
      f(time.value);
      f(activity);
      rgb(colors.$1);
      rgb(colors.$2);
      rgb(colors.$3);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    } catch (error) {
      onError(error);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.shader != shader || old.activity != activity || old.colors != colors;
}
