import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiShaderBackground] — a tile per ported shader variant.
Widget shaderBackgroundDemo(BuildContext context) => const _ShaderDemo();

class _ShaderDemo extends StatelessWidget {
  const _ShaderDemo();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    // Only the variants wired into beuiShaderRegistry render; the rest arrive as
    // the port progresses.
    const ported = <BeuiShaderVariant>[BeuiShaderVariant.simplexNoise];
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final v in ported)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 220,
                  height: 160,
                  child: BeuiShaderBackground(variant: v),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                v.name,
                style: TextStyle(fontSize: 12, color: colors.mutedForeground),
              ),
            ],
          ),
      ],
    );
  }
}
