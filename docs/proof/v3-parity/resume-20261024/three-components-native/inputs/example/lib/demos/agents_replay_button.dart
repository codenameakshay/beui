import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// The 24px replay action used by the pinned agent previews.
class AgentReplayButton extends StatelessWidget {
  const AgentReplayButton({
    required this.onPressed,
    this.pill = true,
    super.key,
  });

  final VoidCallback onPressed;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final colors = BeuiColors.resolve(context);
    return TextButton(
      onPressed: onPressed,
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? colors.muted
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? colors.foreground
              : colors.mutedForeground,
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pill ? 999 : 6),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.rotate_ccw, size: 12),
          SizedBox(width: 6),
          Text('Replay'),
        ],
      ),
    );
  }
}
