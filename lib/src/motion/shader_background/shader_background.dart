import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'specs/dot_grid.dart';
import 'specs/mesh_gradient.dart';
import 'specs/metaballs.dart';
import 'specs/neuro_noise.dart';
import 'specs/perlin_noise.dart';
import 'specs/smoke_ring.dart';
import 'specs/simplex_noise.dart';
import 'specs/spiral.dart';
import 'specs/static_mesh_gradient.dart';
import 'specs/static_radial_gradient.dart';
import 'specs/swirl.dart';
import 'specs/voronoi.dart';
import 'specs/waves.dart';
import 'uniforms.dart';

/// The 21 shader effects ported from `@paper-design/shaders`, mirroring the
/// source `shader-background` variant set. Each maps to a compiled fragment
/// shader under `shaders/` and a [ShaderSpec] in [beuiShaderRegistry].
enum BeuiShaderVariant {
  /// Animated flowing mesh gradient.
  meshGradient,

  /// Grainy multi-stop gradient.
  grainGradient,

  /// Static grid of shapes.
  dotGrid,

  /// Dots orbiting a grid.
  dotOrbit,

  /// Warping domain distortion.
  warp,

  /// Flowing waves.
  waves,

  /// Rippling water.
  water,

  /// Voronoi cells.
  voronoi,

  /// Swirling vortex.
  swirl,

  /// Concentric smoke ring.
  smokeRing,

  /// Static radial gradient.
  staticRadialGradient,

  /// Organic neuro-noise field.
  neuroNoise,

  /// Merging metaballs.
  metaballs,

  /// Volumetric god rays.
  godRays,

  /// Rotating spiral.
  spiral,

  /// Ordered dithering.
  dithering,

  /// Pulsing gradient border.
  pulsingBorder,

  /// Rotating color panels.
  colorPanels,

  /// Static mesh gradient.
  staticMeshGradient,

  /// Stepped simplex-noise gradient.
  simplexNoise,

  /// Perlin-noise gradient.
  perlinNoise,
}

/// Maps each [BeuiShaderVariant] to its [ShaderSpec]. Variants absent from the
/// map are not yet ported and throw [UnimplementedError] when constructed.
final Map<BeuiShaderVariant, ShaderSpec> beuiShaderRegistry = {
  BeuiShaderVariant.simplexNoise: beuiSimplexNoiseSpec,
  BeuiShaderVariant.dotGrid: beuiDotGridSpec,
  BeuiShaderVariant.meshGradient: beuiMeshGradientSpec,
  BeuiShaderVariant.staticMeshGradient: beuiStaticMeshGradientSpec,
  BeuiShaderVariant.perlinNoise: beuiPerlinNoiseSpec,
  BeuiShaderVariant.swirl: beuiSwirlSpec,
  BeuiShaderVariant.waves: beuiWavesSpec,
  BeuiShaderVariant.spiral: beuiSpiralSpec,
  BeuiShaderVariant.staticRadialGradient: beuiStaticRadialGradientSpec,
  BeuiShaderVariant.neuroNoise: beuiNeuroNoiseSpec,
  BeuiShaderVariant.voronoi: beuiVoronoiSpec,
  BeuiShaderVariant.metaballs: beuiMetaballsSpec,
  BeuiShaderVariant.smokeRing: beuiSmokeRingSpec,
};

/// A full-bleed animated GPU shader background — the Flutter port of beUI's
/// `shader-background`, backed by fragment shaders ported from
/// `@paper-design/shaders`.
///
/// Pick an effect with [variant]; supply [colors] (falling back to the
/// variant's defaults) and per-variant scalar [params]. Animated variants run a
/// continuous clock scaled by [speed]; under reduced motion (or [speed] 0) the
/// clock freezes to a static frame — matching the source, which zeroes `speed`
/// for `useReducedMotion`. Static variants ignore [speed].
///
/// The widget fills its constraints; wrap it in a `SizedBox`/`Positioned.fill`.
class BeuiShaderBackground extends StatefulWidget {
  /// Creates a shader background for [variant].
  const BeuiShaderBackground({
    required this.variant,
    this.colors,
    this.speed = 1,
    this.scale = 1,
    this.params = const {},
    super.key,
  });

  /// Which effect to render.
  final BeuiShaderVariant variant;

  /// Colors fed to the shader (capped at [kBeuiShaderMaxColors]). Null uses the
  /// variant's [ShaderSpec.defaultColors].
  final List<Color>? colors;

  /// Animation speed multiplier (animated variants only). 0 freezes.
  final double speed;

  /// Overall zoom of the effect (`u_scale`).
  final double scale;

  /// Per-variant scalar overrides, merged over [ShaderSpec.defaultParams].
  final Map<String, double> params;

  @override
  State<BeuiShaderBackground> createState() => _BeuiShaderBackgroundState();
}

class _BeuiShaderBackgroundState extends State<BeuiShaderBackground>
    with SingleTickerProviderStateMixin {
  static final Map<String, ui.FragmentProgram> _programCache = {};
  // The shared noise texture is loaded once for the whole app.
  static ui.Image? _noiseImage;
  static Future<ui.Image>? _noiseFuture;

  late Ticker _ticker;
  ui.FragmentShader? _shader;
  double _time = 0;

  ShaderSpec? get _spec => beuiShaderRegistry[widget.variant];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (_spec != null) _load();
  }

  /// Lazily loads the shared noise PNG (tries the consumer-facing
  /// `packages/beui/` asset key first, falling back to the bare key used by the
  /// package's own tests / example).
  Future<void> _ensureNoise() async {
    if (_noiseImage != null) return;
    _noiseFuture ??= _loadNoise();
    final img = await _noiseFuture!;
    _noiseImage = img;
    if (mounted) setState(() {});
  }

  static Future<ui.Image> _loadNoise() async {
    ByteData data;
    try {
      data = await rootBundle.load('packages/beui/assets/beui_shader_noise.png');
    } on Exception {
      data = await rootBundle.load('assets/beui_shader_noise.png');
    }
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _load() async {
    final spec = _spec!;
    if (spec.needsNoise) _ensureNoise();
    var program = _programCache[spec.asset];
    program ??= _programCache[spec.asset] = await _loadProgram(spec.asset);
    if (!mounted) return;
    // Not _syncTicker() here: on a warm program cache _load runs synchronously
    // inside initState, and _syncTicker reads MediaQuery (an inherited-widget
    // dependency, illegal before initState completes). The post-frame callback
    // in build() owns ticker syncing.
    setState(() => _shader = program!.fragmentShader());
  }

  /// Loads the compiled shader, trying the consumer-facing `packages/beui/`
  /// key first and falling back to the bare key used inside the package's own
  /// tests and example app.
  static Future<ui.FragmentProgram> _loadProgram(String bare) async {
    try {
      return await ui.FragmentProgram.fromAsset('packages/beui/$bare');
    } on Exception {
      return ui.FragmentProgram.fromAsset(bare);
    }
  }

  @override
  void didUpdateWidget(BeuiShaderBackground old) {
    super.didUpdateWidget(old);
    if (old.variant != widget.variant) {
      _shader = null;
      if (_spec != null) _load();
    } else {
      _syncTicker();
    }
  }

  /// Runs the clock only for animated variants with non-zero speed and motion
  /// enabled; otherwise freezes (static frame at the current time).
  void _syncTicker() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final shouldRun =
        _shader != null &&
        (_spec?.animated ?? false) &&
        widget.speed != 0 &&
        !reduce;
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    setState(() => _time = elapsed.inMicroseconds / 1e6 * widget.speed);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-evaluate the clock against the current reduced-motion setting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
    final spec = _spec;
    assert(
      spec != null,
      'BeuiShaderVariant.${widget.variant.name} is not yet ported.',
    );
    final shader = _shader;
    if (shader == null || spec == null) return const SizedBox.expand();
    // Texture variants can't paint until the noise image is decoded.
    if (spec.needsNoise && _noiseImage == null) return const SizedBox.expand();
    final colors = (widget.colors ?? spec.defaultColors)
        .take(kBeuiShaderMaxColors)
        .toList(growable: false);
    final params = {...spec.defaultParams, ...widget.params, 'scale': widget.scale};
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ShaderPainter(
          shader: shader,
          spec: spec,
          colors: colors,
          params: params,
          time: _time,
          noise: spec.needsNoise ? _noiseImage : null,
        ),
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.shader,
    required this.spec,
    required this.colors,
    required this.params,
    required this.time,
    this.noise,
  });

  final ui.FragmentShader shader;
  final ShaderSpec spec;
  final List<Color> colors;
  final Map<String, double> params;
  final double time;
  final ui.Image? noise;

  @override
  void paint(Canvas canvas, Size size) {
    spec.setUniforms(
      ShaderUniformCtx(
        shader: shader,
        size: size,
        time: time,
        colors: colors,
        params: params,
      ),
    );
    // Bind the shared noise texture at sampler index 0 for texture variants.
    if (noise != null) shader.setImageSampler(0, noise!);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.time != time ||
      old.colors != colors ||
      old.params != params ||
      old.shader != shader ||
      old.noise != noise;
}
