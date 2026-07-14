import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Toolchain probe: confirms the flutter tool compiles a `.frag` in this
/// package, that it loads via [ui.FragmentProgram.fromAsset], and that its
/// uniforms can be set and the shader painted. Validates the fragment-shader
/// pipeline before the real BeuiShaderBackground variants land.
void main() {
  testWidgets('probe shader compiles, loads, and paints', (tester) async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/beui_shader_probe.frag',
    );
    final shader = program.fragmentShader();
    shader
      ..setFloat(0, 200) // u_resolution.x
      ..setFloat(1, 200) // u_resolution.y
      ..setFloat(2, 0.5); // u_time

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            size: const Size(200, 200),
            painter: _ShaderPainter(shader),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CustomPaint), findsWidgets);
    shader.dispose();
  });
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter(this.shader);
  final ui.FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) => true;
}
