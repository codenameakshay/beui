import 'package:flutter/material.dart';

import '../theme/beui_agent_theme.dart';
import '../theme/beui_colors.dart';

// ---------------------------------------------------------------------------
// BeuiChatApp
// ---------------------------------------------------------------------------

/// A complete agent conversation workspace shell — the Flutter port of
/// beUI's `chat-app`.
///
/// Source `ChatApp` is a thin `AnimatedSidebarProvider` wrapper with a
/// rounded bordered surface and a CSS `--sidebar-width` token. This port is a
/// reusable high-level layout that composes:
///
/// * optional [sidebar] (typically [BeuiAiSidebar] or a nav column)
/// * optional [header] (title, status, sidebar trigger)
/// * required [body] (typically [BeuiMessageScroller] with messages)
/// * optional [prompt] (typically [BeuiPromptInput])
///
/// The shell owns chrome only — border, radius, column flex, and the optional
/// sidebar column. Conversation content, streaming, tools, and input state
/// stay with the consumer (see the gallery demo for a full agent turn).
///
/// ```dart
/// BeuiChatApp(
///   sidebar: BeuiAiSidebar(...),
///   header: Text('Checkout release'),
///   body: BeuiMessageScroller(child: BeuiMessageGroup(...)),
///   prompt: BeuiPromptInput(onSubmit: ...),
/// )
/// ```
class BeuiChatApp extends StatelessWidget {
  /// Creates an agent workspace shell.
  const BeuiChatApp({
    required this.body,
    this.sidebar,
    this.header,
    this.prompt,
    this.sidebarWidth = kBeuiChatAppSidebarWidth,
    this.borderRadius,
    this.showBorder = true,
    this.backgroundColor,
    this.semanticLabel = 'Agent workspace',
    super.key,
  }) : assert(sidebarWidth > 0);

  /// Source default sidebar width — `17rem` ≈ 272 logical px.
  static const double kBeuiChatAppSidebarWidth = 272;

  /// Main conversation region (source `AnimatedSidebarInset` body).
  ///
  /// Typically a [BeuiMessageScroller] wrapping a [BeuiMessageGroup]. Takes
  /// all remaining vertical space between [header] and [prompt].
  final Widget body;

  /// Optional left rail (source `AnimatedSidebar` panel).
  ///
  /// Pass a [BeuiAiSidebar], a custom nav column, or any widget. When null the
  /// shell is a single-column chat surface.
  final Widget? sidebar;

  /// Optional top chrome above [body] (title, status chip, triggers).
  final Widget? header;

  /// Optional composer pinned under [body] (source prompt footer).
  final Widget? prompt;

  /// Width of [sidebar] when present (source `--sidebar-width`, default
  /// [kBeuiChatAppSidebarWidth]).
  final double sidebarWidth;

  /// Corner radius of the outer shell. Null uses [BeuiAgentShapes.cardRadius]
  /// (source `rounded-2xl` = 16).
  final double? borderRadius;

  /// Whether to paint the hairline outer border (source `border border-border`).
  final bool showBorder;

  /// Shell fill. Defaults to [BeuiColors.background].
  final Color? backgroundColor;

  /// Accessible label for the workspace region.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    final agent = BeuiAgentTheme.of(context);
    final bg = backgroundColor ?? colors.background;
    final radius = borderRadius ?? agent.shapes.cardRadius;
    final borderSide = BorderSide(
      color: colors.border,
      width: agent.structure.borderWidth,
    );

    final mainColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null) ...[
          header!,
          Divider(
            height: 1,
            thickness: agent.structure.borderWidth,
            color: colors.border,
          ),
        ],
        Expanded(child: body),
        if (prompt != null) ...[
          Divider(
            height: 1,
            thickness: agent.structure.borderWidth,
            color: colors.border,
          ),
          prompt!,
        ],
      ],
    );

    final content = sidebar == null
        ? mainColumn
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: sidebarWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(right: borderSide)),
                  child: sidebar,
                ),
              ),
              Expanded(child: mainColumn),
            ],
          );

    return Semantics(
      container: true,
      label: semanticLabel,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: showBorder
              ? Border.all(
                  color: colors.border,
                  width: agent.structure.borderWidth,
                )
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}
