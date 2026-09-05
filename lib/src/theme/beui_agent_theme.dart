/// Semantic theming for the AI-agent widget family.
///
/// [BeuiAgentTheme] is a [ThemeExtension] that owns typography, shape, layout,
/// structure, and default iconography for conversational surfaces. It
/// complements [BeuiColors] (palette) and [ThemeData.fontFamily] /
/// [BeuiTextTheme] (global typefaces) — it does **not** duplicate those.
///
/// Install once on [ThemeData.extensions] and ordinary agent widgets pick the
/// values up. Omitting the extension preserves the source-fidelity defaults
/// used by the published gallery and goldens.
///
/// ```dart
/// ThemeData(
///   fontFamily: 'General Sans',
///   extensions: [
///     BeuiColors.of(BeuiColorTheme.green, Brightness.light),
///     BeuiAgentTheme(
///       shapes: BeuiAgentShapes(
///         userBubble: BorderRadius.circular(20),
///         assistantBubble: BorderRadius.circular(12),
///         card: BorderRadius.circular(18),
///       ),
///       layout: BeuiAgentLayout(
///         density: BeuiAgentDensity.compact,
///         turnSpacing: 12,
///         bubblePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
///       ),
///       icons: BeuiAgentIcons(edit: Icons.edit_outlined),
///     ),
///   ],
/// );
/// ```
library;

import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';

import '../tokens/icons.dart';
import '../tokens/motion.dart';
import 'beui_agent_status_colors.dart';
import 'beui_agent_strings.dart';
import 'beui_colors.dart';

/// Compact versus standard content density for agent surfaces.
enum BeuiAgentDensity {
  /// Tighter paddings and gaps — a consumer choice, not the source default.
  compact,

  /// Source-fidelity spacing (the default).
  standard,
}

/// Type roles used by agent widgets. Colors are applied by the widget from
/// [BeuiColors]; these styles carry size, weight, height, and (for [mono])
/// family. Sans styles leave [TextStyle.fontFamily] unset so
/// [ThemeData.fontFamily] inherits through.
@immutable
class BeuiAgentTypography {
  /// Creates agent type roles. Defaults match the current source-fidelity
  /// sizes (`text-sm` 14, `text-base` 16, `text-xs` 12, `text-[11px]` 11).
  const BeuiAgentTypography({
    this.assistantBody = const TextStyle(
      fontSize: 14,
      height: 24 / 14, // leading-6
    ),
    this.userBody = const TextStyle(
      fontSize: 14,
      height: 24 / 14, // leading-6
    ),
    this.title = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 20 / 16, // leading-5
    ),
    this.description = const TextStyle(fontSize: 14, height: 20 / 14),
    this.metadata = const TextStyle(fontSize: 11, height: 1),
    this.status = const TextStyle(fontSize: 12),
    this.action = const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    this.mono = const TextStyle(
      fontSize: 12,
      fontFamily: 'monospace',
      fontFamilyFallback: ['monospace'],
    ),
  });

  /// Assistant / agent message body (`text-sm` + `leading-6`).
  final TextStyle assistantBody;

  /// User message body (same metrics as [assistantBody] unless overridden).
  final TextStyle userBody;

  /// Card / question titles (`text-base` + `font-medium`).
  final TextStyle title;

  /// Supporting copy under a title.
  final TextStyle description;

  /// Timestamps, names, tiny chrome (`text-[11px]`).
  final TextStyle metadata;

  /// Status labels, counters, activity (`text-xs`).
  final TextStyle status;

  /// Button / chip / "show more" labels.
  final TextStyle action;

  /// Code, terminal, and other monospaced result content.
  final TextStyle mono;

  /// Returns a copy with the given roles replaced.
  BeuiAgentTypography copyWith({
    TextStyle? assistantBody,
    TextStyle? userBody,
    TextStyle? title,
    TextStyle? description,
    TextStyle? metadata,
    TextStyle? status,
    TextStyle? action,
    TextStyle? mono,
  }) {
    return BeuiAgentTypography(
      assistantBody: assistantBody ?? this.assistantBody,
      userBody: userBody ?? this.userBody,
      title: title ?? this.title,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      action: action ?? this.action,
      mono: mono ?? this.mono,
    );
  }

  /// Linearly interpolates two typography contracts.
  static BeuiAgentTypography lerp(
    BeuiAgentTypography a,
    BeuiAgentTypography b,
    double t,
  ) {
    return BeuiAgentTypography(
      assistantBody: TextStyle.lerp(a.assistantBody, b.assistantBody, t)!,
      userBody: TextStyle.lerp(a.userBody, b.userBody, t)!,
      title: TextStyle.lerp(a.title, b.title, t)!,
      description: TextStyle.lerp(a.description, b.description, t)!,
      metadata: TextStyle.lerp(a.metadata, b.metadata, t)!,
      status: TextStyle.lerp(a.status, b.status, t)!,
      action: TextStyle.lerp(a.action, b.action, t)!,
      mono: TextStyle.lerp(a.mono, b.mono, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentTypography &&
        other.assistantBody == assistantBody &&
        other.userBody == userBody &&
        other.title == title &&
        other.description == description &&
        other.metadata == metadata &&
        other.status == status &&
        other.action == action &&
        other.mono == mono;
  }

  @override
  int get hashCode => Object.hash(
    assistantBody,
    userBody,
    title,
    description,
    metadata,
    status,
    action,
    mono,
  );
}

/// Corner radii for agent surfaces.
@immutable
class BeuiAgentShapes {
  /// Creates agent shape tokens. Defaults match source `rounded-2xl` (16),
  /// `rounded-xl` (12), `rounded-lg` (8), `rounded-md` (6), and pills (999).
  const BeuiAgentShapes({
    this.userBubble = const BorderRadius.all(Radius.circular(16)),
    this.assistantBubble = const BorderRadius.all(Radius.circular(16)),
    this.card = const BorderRadius.all(Radius.circular(16)),
    this.nested = const BorderRadius.all(Radius.circular(12)),
    this.control = const BorderRadius.all(Radius.circular(8)),
    this.chip = const BorderRadius.all(Radius.circular(6)),
    this.pill = const BorderRadius.all(Radius.circular(999)),
  });

  /// User (trailing) message-bubble corners (`rounded-2xl`).
  final BorderRadius userBubble;

  /// Assistant (leading) message-bubble corners (`rounded-2xl`).
  final BorderRadius assistantBubble;

  /// Approval, tool, todo, and other card shells (`rounded-2xl`).
  final BorderRadius card;

  /// Nested panels inside a card (`rounded-xl`).
  final BorderRadius nested;

  /// Buttons, inputs, and compact controls (`rounded-lg`).
  final BorderRadius control;

  /// Small chips and icon buttons (`rounded-md`).
  final BorderRadius chip;

  /// Status pills and fully-round chips.
  final BorderRadius pill;

  /// The circular radius of [card], for widgets that take a single `double`.
  double get cardRadius => card.topLeft.x;

  /// Returns a copy with the given radii replaced.
  BeuiAgentShapes copyWith({
    BorderRadius? userBubble,
    BorderRadius? assistantBubble,
    BorderRadius? card,
    BorderRadius? nested,
    BorderRadius? control,
    BorderRadius? chip,
    BorderRadius? pill,
  }) {
    return BeuiAgentShapes(
      userBubble: userBubble ?? this.userBubble,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      card: card ?? this.card,
      nested: nested ?? this.nested,
      control: control ?? this.control,
      chip: chip ?? this.chip,
      pill: pill ?? this.pill,
    );
  }

  /// Linearly interpolates two shape contracts.
  static BeuiAgentShapes lerp(BeuiAgentShapes a, BeuiAgentShapes b, double t) {
    return BeuiAgentShapes(
      userBubble: BorderRadius.lerp(a.userBubble, b.userBubble, t)!,
      assistantBubble: BorderRadius.lerp(
        a.assistantBubble,
        b.assistantBubble,
        t,
      )!,
      card: BorderRadius.lerp(a.card, b.card, t)!,
      nested: BorderRadius.lerp(a.nested, b.nested, t)!,
      control: BorderRadius.lerp(a.control, b.control, t)!,
      chip: BorderRadius.lerp(a.chip, b.chip, t)!,
      pill: BorderRadius.lerp(a.pill, b.pill, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentShapes &&
        other.userBubble == userBubble &&
        other.assistantBubble == assistantBubble &&
        other.card == card &&
        other.nested == nested &&
        other.control == control &&
        other.chip == chip &&
        other.pill == pill;
  }

  @override
  int get hashCode => Object.hash(
    userBubble,
    assistantBubble,
    card,
    nested,
    control,
    chip,
    pill,
  );
}

/// Spacing, padding, and width behaviour for agent conversations.
@immutable
class BeuiAgentLayout {
  /// Creates agent layout tokens. Defaults match the source Tailwind gaps
  /// (`gap-4` 16, `gap-1.5` 6, bubble `px-3.5 py-2.5`, card `p-4`).
  const BeuiAgentLayout({
    this.density = BeuiAgentDensity.standard,
    this.conversationGutter = EdgeInsets.zero,
    this.turnSpacing = 16,
    this.groupedMessageSpacing = 6,
    this.groupedMessageSpacingRelaxed = 12,
    this.bubblePadding = const EdgeInsets.symmetric(
      horizontal: 14, // px-3.5
      vertical: 10, // py-2.5
    ),
    this.cardPadding = const EdgeInsets.all(16), // p-4
    this.sectionSpacing = 16,
    this.actionSpacing = 8,
    this.maxBubbleWidthFactor = 0.82,
    this.avatarSize = 28,
    this.iconSize = 16,
    this.rowGap = 8,
  });

  /// Compact versus standard density hint. Widgets with their own spacing
  /// enums still honour those enums; this flag is for surfaces that only
  /// expose one density and for [BeuiAgentTheme.compact].
  final BeuiAgentDensity density;

  /// Horizontal (and optional vertical) inset of a conversation viewport.
  /// Defaults to zero so [BeuiMessageScroller.padding] remains the opt-in
  /// override it is today.
  final EdgeInsets conversationGutter;

  /// Vertical gap between conversation turns ([BeuiMessageSpacing.standard],
  /// source `gap-4`).
  final double turnSpacing;

  /// Tight gap between grouped same-author bubbles / compact message rows
  /// (source `gap-1.5`).
  final double groupedMessageSpacing;

  /// Relaxed gap for [BeuiMessageBubbleSpacing.standard] (source `gap-3`).
  final double groupedMessageSpacingRelaxed;

  /// Inner padding of a non-ghost message bubble.
  final EdgeInsets bubblePadding;

  /// Inner padding of approval / tool / todo cards.
  final EdgeInsets cardPadding;

  /// Gap between major sections inside a card (source `mt-4`).
  final double sectionSpacing;

  /// Gap between action buttons / chips (source `gap-2`).
  final double actionSpacing;

  /// Max bubble width as a fraction of the parent (source `max-w-[82%]`).
  final double maxBubbleWidthFactor;

  /// Message avatar box (source `size-7` = 28).
  final double avatarSize;

  /// Default glyph size on agent chrome (source `size-4` = 16).
  final double iconSize;

  /// Gap between avatar and content in a message row (source `gap-2`).
  final double rowGap;

  /// Returns a copy with the given fields replaced.
  BeuiAgentLayout copyWith({
    BeuiAgentDensity? density,
    EdgeInsets? conversationGutter,
    double? turnSpacing,
    double? groupedMessageSpacing,
    double? groupedMessageSpacingRelaxed,
    EdgeInsets? bubblePadding,
    EdgeInsets? cardPadding,
    double? sectionSpacing,
    double? actionSpacing,
    double? maxBubbleWidthFactor,
    double? avatarSize,
    double? iconSize,
    double? rowGap,
  }) {
    return BeuiAgentLayout(
      density: density ?? this.density,
      conversationGutter: conversationGutter ?? this.conversationGutter,
      turnSpacing: turnSpacing ?? this.turnSpacing,
      groupedMessageSpacing:
          groupedMessageSpacing ?? this.groupedMessageSpacing,
      groupedMessageSpacingRelaxed:
          groupedMessageSpacingRelaxed ?? this.groupedMessageSpacingRelaxed,
      bubblePadding: bubblePadding ?? this.bubblePadding,
      cardPadding: cardPadding ?? this.cardPadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      actionSpacing: actionSpacing ?? this.actionSpacing,
      maxBubbleWidthFactor: maxBubbleWidthFactor ?? this.maxBubbleWidthFactor,
      avatarSize: avatarSize ?? this.avatarSize,
      iconSize: iconSize ?? this.iconSize,
      rowGap: rowGap ?? this.rowGap,
    );
  }

  /// Linearly interpolates two layout contracts. [density] snaps at 0.5.
  static BeuiAgentLayout lerp(BeuiAgentLayout a, BeuiAgentLayout b, double t) {
    return BeuiAgentLayout(
      density: t < 0.5 ? a.density : b.density,
      conversationGutter: EdgeInsets.lerp(
        a.conversationGutter,
        b.conversationGutter,
        t,
      )!,
      turnSpacing: lerpDouble(a.turnSpacing, b.turnSpacing, t)!,
      groupedMessageSpacing: lerpDouble(
        a.groupedMessageSpacing,
        b.groupedMessageSpacing,
        t,
      )!,
      groupedMessageSpacingRelaxed: lerpDouble(
        a.groupedMessageSpacingRelaxed,
        b.groupedMessageSpacingRelaxed,
        t,
      )!,
      bubblePadding: EdgeInsets.lerp(a.bubblePadding, b.bubblePadding, t)!,
      cardPadding: EdgeInsets.lerp(a.cardPadding, b.cardPadding, t)!,
      sectionSpacing: lerpDouble(a.sectionSpacing, b.sectionSpacing, t)!,
      actionSpacing: lerpDouble(a.actionSpacing, b.actionSpacing, t)!,
      maxBubbleWidthFactor: lerpDouble(
        a.maxBubbleWidthFactor,
        b.maxBubbleWidthFactor,
        t,
      )!,
      avatarSize: lerpDouble(a.avatarSize, b.avatarSize, t)!,
      iconSize: lerpDouble(a.iconSize, b.iconSize, t)!,
      rowGap: lerpDouble(a.rowGap, b.rowGap, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentLayout &&
        other.density == density &&
        other.conversationGutter == conversationGutter &&
        other.turnSpacing == turnSpacing &&
        other.groupedMessageSpacing == groupedMessageSpacing &&
        other.groupedMessageSpacingRelaxed == groupedMessageSpacingRelaxed &&
        other.bubblePadding == bubblePadding &&
        other.cardPadding == cardPadding &&
        other.sectionSpacing == sectionSpacing &&
        other.actionSpacing == actionSpacing &&
        other.maxBubbleWidthFactor == maxBubbleWidthFactor &&
        other.avatarSize == avatarSize &&
        other.iconSize == iconSize &&
        other.rowGap == rowGap;
  }

  @override
  int get hashCode => Object.hash(
    density,
    conversationGutter,
    turnSpacing,
    groupedMessageSpacing,
    groupedMessageSpacingRelaxed,
    bubblePadding,
    cardPadding,
    sectionSpacing,
    actionSpacing,
    maxBubbleWidthFactor,
    avatarSize,
    iconSize,
    rowGap,
  );
}

/// Hairline borders, density-independent emphasis, and glass treatment.
@immutable
class BeuiAgentStructure {
  /// Creates structure tokens. Defaults match source hairlines (1px) and
  /// focus rings (2px), with glass off so cards keep their muted fill.
  const BeuiAgentStructure({
    this.borderWidth = 1,
    this.emphasisBorderWidth = 2,
    this.useGlassSurfaces = false,
  });

  /// Hairline border width on outlined bubbles, cards, and chips.
  final double borderWidth;

  /// Focus-ring width (source `ring-2`).
  final double emphasisBorderWidth;

  /// When true, agent cards use [BeuiColors.glass] fill + backdrop blur
  /// instead of the muted solid. Default `false` preserves current fidelity.
  final bool useGlassSurfaces;

  /// Returns a copy with the given fields replaced.
  BeuiAgentStructure copyWith({
    double? borderWidth,
    double? emphasisBorderWidth,
    bool? useGlassSurfaces,
  }) {
    return BeuiAgentStructure(
      borderWidth: borderWidth ?? this.borderWidth,
      emphasisBorderWidth: emphasisBorderWidth ?? this.emphasisBorderWidth,
      useGlassSurfaces: useGlassSurfaces ?? this.useGlassSurfaces,
    );
  }

  /// Linearly interpolates two structure contracts. [useGlassSurfaces] snaps
  /// at 0.5.
  static BeuiAgentStructure lerp(
    BeuiAgentStructure a,
    BeuiAgentStructure b,
    double t,
  ) {
    return BeuiAgentStructure(
      borderWidth: lerpDouble(a.borderWidth, b.borderWidth, t)!,
      emphasisBorderWidth: lerpDouble(
        a.emphasisBorderWidth,
        b.emphasisBorderWidth,
        t,
      )!,
      useGlassSurfaces: t < 0.5 ? a.useGlassSurfaces : b.useGlassSurfaces,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentStructure &&
        other.borderWidth == borderWidth &&
        other.emphasisBorderWidth == emphasisBorderWidth &&
        other.useGlassSurfaces == useGlassSurfaces;
  }

  @override
  int get hashCode =>
      Object.hash(borderWidth, emphasisBorderWidth, useGlassSurfaces);
}

/// Semantic icon slots for the agent family. Defaults are Lucide glyphs;
/// consumers pass any [IconData] (Material, Cupertino, custom) — the package
/// never requires a consumer icon font.
@immutable
class BeuiAgentIcons {
  /// Creates agent icon slots.
  const BeuiAgentIcons({
    this.pendingApproval = LucideIcons.message_square_text,
    this.pendingQuestion = LucideIcons.circle_question_mark,
    this.approved = LucideIcons.check,
    this.rejected = LucideIcons.x,
    this.copy = LucideIcons.copy,
    this.copied = LucideIcons.check,
    this.retry = LucideIcons.rotate_ccw,
    this.expand = LucideIcons.chevron_down,
    this.send = LucideIcons.arrow_up,
    this.add = LucideIcons.plus,
    this.edit = LucideIcons.pencil,
    this.close = LucideIcons.x,
    this.warning = LucideIcons.circle_alert,
    this.shield = LucideIcons.shield_check,
    this.tool = LucideIcons.wrench,
    this.terminal = LucideIcons.square_terminal,
    this.request = LucideIcons.braces,
    this.spinner = LucideIcons.loader_circle,
    this.search = LucideIcons.search,
    this.web = LucideIcons.earth,
    this.file = LucideIcons.file_code,
    this.todo = LucideIcons.list_todo,
    this.citations = LucideIcons.book_open_text,
    this.externalLink = LucideIcons.external_link,
    this.thumbsUp = LucideIcons.thumbs_up,
    this.thumbsDown = LucideIcons.thumbs_down,
    this.thinking = LucideIcons.sparkles,
    this.message = LucideIcons.message_square,
    this.folder = LucideIcons.folder,
    this.folderOpen = LucideIcons.folder_open,
    this.bookmark = LucideIcons.bookmark,
    this.document = LucideIcons.file_text,
    this.more = LucideIcons.ellipsis,
  });

  /// Simple-approval pending state.
  final IconData pendingApproval;

  /// Question-flow pending state.
  final IconData pendingQuestion;

  /// Approved / success / copied-alternative check.
  final IconData approved;

  /// Rejected / deny.
  final IconData rejected;

  /// Copy-to-clipboard.
  final IconData copy;

  /// Copy succeeded.
  final IconData copied;

  /// Retry / regenerate.
  final IconData retry;

  /// Expand / collapse chevron (pointing down; widgets rotate when open).
  final IconData expand;

  /// Prompt send.
  final IconData send;

  /// Add / attach.
  final IconData add;

  /// Header edit action (pencil).
  final IconData edit;

  /// Dismiss / close.
  final IconData close;

  /// Warning / error alert.
  final IconData warning;

  /// Tool-approval shield.
  final IconData shield;

  /// Generic tool.
  final IconData tool;

  /// Terminal / shell.
  final IconData terminal;

  /// HTTP / request payload.
  final IconData request;

  /// In-flight spinner glyph (widgets still spin it).
  final IconData spinner;

  /// Search.
  final IconData search;

  /// Web / globe.
  final IconData web;

  /// File / code file.
  final IconData file;

  /// Todo list.
  final IconData todo;

  /// Citations / sources.
  final IconData citations;

  /// External link.
  final IconData externalLink;

  /// Positive feedback.
  final IconData thumbsUp;

  /// Negative feedback.
  final IconData thumbsDown;

  /// Thinking / sparkles.
  final IconData thinking;

  /// Message bubble glyph (activity traces).
  final IconData message;

  /// Collapsed folder (sidebar).
  final IconData folder;

  /// Expanded folder (sidebar).
  final IconData folderOpen;

  /// Bookmark resource.
  final IconData bookmark;

  /// Document / file resource (distinct from [file], the code-file glyph).
  final IconData document;

  /// Overflow / more-actions ellipsis.
  final IconData more;

  /// Returns a copy with the given slots replaced.
  BeuiAgentIcons copyWith({
    IconData? pendingApproval,
    IconData? pendingQuestion,
    IconData? approved,
    IconData? rejected,
    IconData? copy,
    IconData? copied,
    IconData? retry,
    IconData? expand,
    IconData? send,
    IconData? add,
    IconData? edit,
    IconData? close,
    IconData? warning,
    IconData? shield,
    IconData? tool,
    IconData? terminal,
    IconData? request,
    IconData? spinner,
    IconData? search,
    IconData? web,
    IconData? file,
    IconData? todo,
    IconData? citations,
    IconData? externalLink,
    IconData? thumbsUp,
    IconData? thumbsDown,
    IconData? thinking,
    IconData? message,
    IconData? folder,
    IconData? folderOpen,
    IconData? bookmark,
    IconData? document,
    IconData? more,
  }) {
    return BeuiAgentIcons(
      pendingApproval: pendingApproval ?? this.pendingApproval,
      pendingQuestion: pendingQuestion ?? this.pendingQuestion,
      approved: approved ?? this.approved,
      rejected: rejected ?? this.rejected,
      copy: copy ?? this.copy,
      copied: copied ?? this.copied,
      retry: retry ?? this.retry,
      expand: expand ?? this.expand,
      send: send ?? this.send,
      add: add ?? this.add,
      edit: edit ?? this.edit,
      close: close ?? this.close,
      warning: warning ?? this.warning,
      shield: shield ?? this.shield,
      tool: tool ?? this.tool,
      terminal: terminal ?? this.terminal,
      request: request ?? this.request,
      spinner: spinner ?? this.spinner,
      search: search ?? this.search,
      web: web ?? this.web,
      file: file ?? this.file,
      todo: todo ?? this.todo,
      citations: citations ?? this.citations,
      externalLink: externalLink ?? this.externalLink,
      thumbsUp: thumbsUp ?? this.thumbsUp,
      thumbsDown: thumbsDown ?? this.thumbsDown,
      thinking: thinking ?? this.thinking,
      message: message ?? this.message,
      folder: folder ?? this.folder,
      folderOpen: folderOpen ?? this.folderOpen,
      bookmark: bookmark ?? this.bookmark,
      document: document ?? this.document,
      more: more ?? this.more,
    );
  }

  /// Discrete slots snap at the midpoint — icons cannot interpolate.
  static BeuiAgentIcons lerp(BeuiAgentIcons a, BeuiAgentIcons b, double t) {
    return t < 0.5 ? a : b;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentIcons &&
        other.pendingApproval == pendingApproval &&
        other.pendingQuestion == pendingQuestion &&
        other.approved == approved &&
        other.rejected == rejected &&
        other.copy == copy &&
        other.copied == copied &&
        other.retry == retry &&
        other.expand == expand &&
        other.send == send &&
        other.add == add &&
        other.edit == edit &&
        other.close == close &&
        other.warning == warning &&
        other.shield == shield &&
        other.tool == tool &&
        other.terminal == terminal &&
        other.request == request &&
        other.spinner == spinner &&
        other.search == search &&
        other.web == web &&
        other.file == file &&
        other.todo == todo &&
        other.citations == citations &&
        other.externalLink == externalLink &&
        other.thumbsUp == thumbsUp &&
        other.thumbsDown == thumbsDown &&
        other.thinking == thinking &&
        other.message == message &&
        other.folder == folder &&
        other.folderOpen == folderOpen &&
        other.bookmark == bookmark &&
        other.document == document &&
        other.more == more;
  }

  @override
  int get hashCode => Object.hashAll([
    pendingApproval,
    pendingQuestion,
    approved,
    rejected,
    copy,
    copied,
    retry,
    expand,
    send,
    add,
    edit,
    close,
    warning,
    shield,
    tool,
    terminal,
    request,
    spinner,
    search,
    web,
    file,
    todo,
    citations,
    externalLink,
    thumbsUp,
    thumbsDown,
    thinking,
    message,
    folder,
    folderOpen,
    bookmark,
    document,
    more,
  ]);
}

/// The resolved agent visual contract, installed as a [ThemeExtension].
///
/// Resolve with [BeuiAgentTheme.of] — missing extensions fall back to
/// [BeuiAgentTheme.standard], which matches the current default appearance.
@immutable
class BeuiAgentTheme extends ThemeExtension<BeuiAgentTheme> {
  /// Creates a fully specified agent theme. Every nested contract defaults
  /// to source-fidelity values, so `const BeuiAgentTheme()` is the standard
  /// look.
  const BeuiAgentTheme({
    this.typography = const BeuiAgentTypography(),
    this.shapes = const BeuiAgentShapes(),
    this.layout = const BeuiAgentLayout(),
    this.structure = const BeuiAgentStructure(),
    this.icons = const BeuiAgentIcons(),
    this.statusLight = BeuiAgentStatusColors.light,
    this.statusDark = BeuiAgentStatusColors.dark,
    this.strings = const BeuiAgentStrings(),
  });

  /// Source-fidelity defaults. Identical to the unnamed constructor.
  static const standard = BeuiAgentTheme();

  /// A tighter layout preset. Type, shape, and icons stay at source defaults;
  /// paddings and gaps shrink. Useful as a starting point, not a second look.
  static const compact = BeuiAgentTheme(
    layout: BeuiAgentLayout(
      density: BeuiAgentDensity.compact,
      turnSpacing: 10,
      groupedMessageSpacing: 4,
      groupedMessageSpacingRelaxed: 8,
      bubblePadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      cardPadding: EdgeInsets.all(12),
      sectionSpacing: 10,
      actionSpacing: 6,
      rowGap: 6,
    ),
  );

  /// Type roles.
  final BeuiAgentTypography typography;

  /// Corner radii.
  final BeuiAgentShapes shapes;

  /// Spacing and padding.
  final BeuiAgentLayout layout;

  /// Borders and glass.
  final BeuiAgentStructure structure;

  /// Default glyphs.
  final BeuiAgentIcons icons;

  /// Status colors for light mode. See [statusColorsFor].
  final BeuiAgentStatusColors statusLight;

  /// Status colors for dark mode. See [statusColorsFor].
  final BeuiAgentStatusColors statusDark;

  /// User-facing copy for the agent family — the localization surface.
  final BeuiAgentStrings strings;

  /// The nearest [BeuiAgentTheme], or [standard] when none is installed.
  static BeuiAgentTheme of(BuildContext context) {
    return Theme.of(context).extension<BeuiAgentTheme>() ?? standard;
  }

  /// The status set for [brightness].
  ///
  /// [BeuiAgentTheme] is one `const` extension shared by both modes (unlike
  /// [BeuiColors], which is resolved per brightness), so both sets are carried
  /// and picked here. Widgets should pass the brightness they already resolved:
  ///
  /// ```dart
  /// final palette = agent
  ///     .statusColorsFor(Theme.of(context).brightness)
  ///     .palette(BeuiAgentStatus.pending);
  /// ```
  BeuiAgentStatusColors statusColorsFor(Brightness brightness) =>
      brightness == Brightness.dark ? statusDark : statusLight;

  /// Shorthand for `statusColorsFor(brightness).palette(status)`.
  BeuiAgentStatusPalette statusPalette(
    BeuiAgentStatus status,
    Brightness brightness,
  ) => statusColorsFor(brightness).palette(status);

  /// Bubble radius for a trailing (user) versus leading (assistant) surface.
  BorderRadius bubbleRadius({required bool user}) =>
      user ? shapes.userBubble : shapes.assistantBubble;

  /// Body style for a user versus assistant turn.
  TextStyle bodyStyle({required bool user}) =>
      user ? typography.userBody : typography.assistantBody;

  /// Fill + radius (+ optional glass border) for an agent card shell.
  BoxDecoration cardDecoration(BeuiColors colors) {
    if (structure.useGlassSurfaces) {
      return BoxDecoration(
        color: colors.glass.bg,
        borderRadius: shapes.card,
        border: Border.all(
          color: colors.glass.border,
          width: structure.borderWidth,
        ),
      );
    }
    return BoxDecoration(color: colors.muted, borderRadius: shapes.card);
  }

  /// Wraps [child] in the card shell, adding backdrop blur when
  /// [BeuiAgentStructure.useGlassSurfaces] is set.
  Widget decorateCard({required BeuiColors colors, required Widget child}) {
    Widget surface = DecoratedBox(
      decoration: cardDecoration(colors),
      child: child,
    );
    if (structure.useGlassSurfaces) {
      surface = ClipRRect(
        borderRadius: shapes.card,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: beuiBlurSigma(colors.glass.blur),
            sigmaY: beuiBlurSigma(colors.glass.blur),
          ),
          child: surface,
        ),
      );
    }
    return surface;
  }

  @override
  BeuiAgentTheme copyWith({
    BeuiAgentTypography? typography,
    BeuiAgentShapes? shapes,
    BeuiAgentLayout? layout,
    BeuiAgentStructure? structure,
    BeuiAgentIcons? icons,
    BeuiAgentStatusColors? statusLight,
    BeuiAgentStatusColors? statusDark,
    BeuiAgentStrings? strings,
  }) {
    return BeuiAgentTheme(
      typography: typography ?? this.typography,
      shapes: shapes ?? this.shapes,
      layout: layout ?? this.layout,
      structure: structure ?? this.structure,
      icons: icons ?? this.icons,
      statusLight: statusLight ?? this.statusLight,
      statusDark: statusDark ?? this.statusDark,
      strings: strings ?? this.strings,
    );
  }

  @override
  BeuiAgentTheme lerp(
    covariant ThemeExtension<BeuiAgentTheme>? other,
    double t,
  ) {
    if (other is! BeuiAgentTheme) return this;
    return BeuiAgentTheme(
      typography: BeuiAgentTypography.lerp(typography, other.typography, t),
      shapes: BeuiAgentShapes.lerp(shapes, other.shapes, t),
      layout: BeuiAgentLayout.lerp(layout, other.layout, t),
      structure: BeuiAgentStructure.lerp(structure, other.structure, t),
      icons: BeuiAgentIcons.lerp(icons, other.icons, t),
      statusLight: BeuiAgentStatusColors.lerp(
        statusLight,
        other.statusLight,
        t,
      ),
      statusDark: BeuiAgentStatusColors.lerp(statusDark, other.statusDark, t),
      strings: BeuiAgentStrings.lerp(strings, other.strings, t),
    );
  }

  // Value equality is load-bearing: [ThemeData] compares extensions by value,
  // so two structurally identical themes must compare equal. See
  // [BeuiColors] for the same constraint.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentTheme &&
        other.typography == typography &&
        other.shapes == shapes &&
        other.layout == layout &&
        other.structure == structure &&
        other.icons == icons &&
        other.statusLight == statusLight &&
        other.statusDark == statusDark &&
        other.strings == strings;
  }

  @override
  int get hashCode => Object.hash(
    typography,
    shapes,
    layout,
    structure,
    icons,
    statusLight,
    statusDark,
    strings,
  );
}
