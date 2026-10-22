import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiCollapsible].
Widget collapsibleDemo(BuildContext context) => const _CollapsiblePreview();

/// Mirrors the source's CollapsiblePreview ("More details").
class _CollapsiblePreview extends StatelessWidget {
  const _CollapsiblePreview();

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const BeuiCollapsible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeuiCollapsibleTrigger(
                child: Row(
                  children: [
                    Expanded(child: Text('More details')),
                    BeuiCollapsibleIndicator(),
                  ],
                ),
              ),
              BeuiCollapsibleContent(
                child: Text(
                  'Keep extra information tucked away until you need it.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
