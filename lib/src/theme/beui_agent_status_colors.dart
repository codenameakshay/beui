/// Semantic status colors for the AI-agent widget family.
///
/// Before this role existed, the five agent widgets carried ~50 hardcoded
/// `Color(0xFF…)` literals between them — a consumer could not retheme agent
/// status color at all, and the literals disagreed with
/// [BeuiColors.success] / [BeuiColors.warning] / [BeuiColors.destructive].
/// This file is the single home for them.
///
/// The defaults are the Tailwind ramps the source uses, in the same roles the
/// widgets already paint: the **500** shade as an opaque mark fill and as the
/// base for the 10% tint and 30% border, the **400** shade as dark-mode
/// foreground. The one deliberate change from the previously-painted values is
/// the light-mode [BeuiAgentStatusPalette.foreground], lifted from the 600 tier
/// to a 700 tier so 11px badge text clears WCAG AA (4.5:1) — see
/// [BeuiAgentStatusColors.light].
///
/// [BeuiAgentTheme] is brightness-agnostic (it is one `const` extension shared
/// by both modes), so a full set is stored per brightness and resolved with
/// [BeuiAgentTheme.statusColorsFor].
library;

import 'package:flutter/material.dart';

import 'beui_colors.dart';

/// The semantic status tiers agent surfaces paint.
///
/// Each agent widget has its own status enum (`BeuiToolApprovalStatus`,
/// `BeuiToolResultStatus`, `BeuiApprovalCardStatus`, `BeuiTodoItemStatus`);
/// they map onto these shared tiers so one theme override retints all of them.
enum BeuiAgentStatus {
  /// Awaiting a human decision — amber. Tool approval required, question
  /// pending, changes requested.
  pending,

  /// In flight — blue. Also the general "info" tier: running, approving,
  /// submitting, streaming.
  running,

  /// Finished well — emerald. Approved, completed, answered.
  success,

  /// Finished badly — rose. Errored, failed.
  failed,

  /// Refused by the user — rose. Distinct from [failed] so a consumer can give
  /// "the user said no" its own color without also retinting crashes; the
  /// default is identical to [failed] so nothing changes until they do.
  denied,

  /// No status color — muted. Cancelled runs, idle rows, unstarted todos.
  neutral,

  /// The destructive-approval emphasis tier — a stronger rose than [failed],
  /// for irreversible actions (`rm -rf`, force-push, DROP TABLE). Carries a
  /// heavier [BeuiAgentStatusPalette.border] so a destructive card reads as
  /// different *at a glance*, before any label is read.
  destructive,
}

/// The colors one [BeuiAgentStatus] paints with, in one [Brightness].
///
/// The five slots are the roles the agent widgets actually use — no more:
///
/// | slot          | painted by                                            |
/// |---------------|-------------------------------------------------------|
/// | [foreground]  | badge label, status glyph, status text, count text     |
/// | [background]  | badge pill fill (a 10% tint of [solid])                |
/// | [border]      | badge pill edge (a 30% tint of [solid])                |
/// | [solid]       | opaque marks — the todo header disc, diff counters     |
/// | [onSolid]     | ink drawn *on* [solid] — the todo header check stroke  |
@immutable
class BeuiAgentStatusPalette {
  /// Creates a status palette. All five slots are required — there is no
  /// sensible default for one without the others. Derive variants with
  /// [copyWith].
  const BeuiAgentStatusPalette({
    required this.foreground,
    required this.background,
    required this.border,
    required this.solid,
    required this.onSolid,
  });

  /// Label and glyph color, drawn on [background]. Every default clears 4.5:1
  /// against its own composited [background].
  final Color foreground;

  /// Tinted pill fill. Translucent, so it composites over whatever card surface
  /// it sits on.
  final Color background;

  /// Pill edge. Translucent, like [background].
  final Color border;

  /// Opaque fill for painted marks (the completed-todo disc, the diff `+N`).
  final Color solid;

  /// Ink drawn on top of [solid].
  ///
  /// The stock value is white for every status because that is what
  /// `todo_list.dart` already paints on its emerald disc. White on a 500-shade
  /// fill is a ~2–3:1 pairing — acceptable for a 2.25px check stroke that is
  /// backed up by shape and position, but do not put small text on it.
  final Color onSolid;

  /// Returns a copy with the given slots replaced.
  BeuiAgentStatusPalette copyWith({
    Color? foreground,
    Color? background,
    Color? border,
    Color? solid,
    Color? onSolid,
  }) {
    return BeuiAgentStatusPalette(
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      border: border ?? this.border,
      solid: solid ?? this.solid,
      onSolid: onSolid ?? this.onSolid,
    );
  }

  /// Linearly interpolates two status palettes.
  static BeuiAgentStatusPalette lerp(
    BeuiAgentStatusPalette a,
    BeuiAgentStatusPalette b,
    double t,
  ) {
    return BeuiAgentStatusPalette(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      solid: Color.lerp(a.solid, b.solid, t)!,
      onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentStatusPalette &&
        other.foreground == foreground &&
        other.background == background &&
        other.border == border &&
        other.solid == solid &&
        other.onSolid == onSolid;
  }

  @override
  int get hashCode =>
      Object.hash(foreground, background, border, solid, onSolid);
}

// ---------------------------------------------------------------------------
// Default ramps — Tailwind shades, transcribed from the literals the five agent
// widgets already paint.
//
// The translucent slots encode their alpha in the ARGB literal rather than
// calling `withValues()`, so the whole palette stays `const` (load-bearing:
// `BeuiAgentTheme.standard` is a `static const`). 0x1A/0x4D/0x24/0xD9 are the
// 8-bit quantisations of 0.10/0.30/0.14/0.85; the composited result is
// identical to the runtime `withValues()` call to within one 8-bit step.
// ---------------------------------------------------------------------------

const Color _amber500 = Color(0xFFFE9A00);
const Color _amber400 = Color(0xFFFFB900);
const Color _blue500 = Color(0xFF2B7FFF);
const Color _blue400 = Color(0xFF51A2FF);
const Color _emerald500 = Color(0xFF00BC7D);
const Color _emerald400 = Color(0xFF00D492);
const Color _rose500 = Color(0xFFFF2056);
const Color _rose400 = Color(0xFFFF637E);

// Light-mode foregrounds — the 700 tier. The 600 tier these replace measured
// 2.74–4.29:1 on the composited badge fills; these measure 4.53–5.94:1.
const Color _amber700 = Color(0xFFB64A00);
const Color _blue700 = Color(0xFF1447E6);
const Color _emerald700 = Color(0xFF007954);
const Color _rose700 = Color(0xFFC70036);
const Color _rose800 = Color(0xFFA50029);
const Color _rose300 = Color(0xFFFF8FA3);

// Neutral tracks `BeuiColors.mutedForeground`, which is identical across all 11
// color themes (brand themes override only primary/accent/ring).
const Color _mutedForegroundLight = Color(0xFF636363);
const Color _mutedForegroundDark = Color(0xFF868686);

const Color _white = Color(0xFFFFFFFF);
const Color _backgroundLight = Color(0xFFFCFCFC);
const Color _backgroundDark = Color(0xFF151515);

/// A complete set of [BeuiAgentStatusPalette]s — one per [BeuiAgentStatus] —
/// for a single [Brightness].
///
/// Resolve one from a theme with [BeuiAgentTheme.statusColorsFor], and pick a
/// tier out of it with [palette]. Override a tier with [copyWith] on top of
/// [light] / [dark] rather than rebuilding the whole set:
///
/// ```dart
/// BeuiAgentTheme(
///   statusLight: BeuiAgentStatusColors.light.copyWith(
///     denied: BeuiAgentStatusColors.light.neutral,
///   ),
/// );
/// ```
@immutable
class BeuiAgentStatusColors {
  /// Creates a full status set. Every tier is required; start from [light] or
  /// [dark] and use [copyWith] instead of calling this directly.
  const BeuiAgentStatusColors({
    required this.pending,
    required this.running,
    required this.success,
    required this.failed,
    required this.denied,
    required this.neutral,
    required this.destructive,
  });

  /// Light-mode defaults.
  ///
  /// Tints, borders, and solids are the values the agent widgets already
  /// painted. Foregrounds are lifted one tier (600 → 700) because the 600 tier
  /// failed AA as 10–11px badge text: amber 2.74:1, blue 4.29:1, emerald
  /// 3.06:1, rose 3.60:1 on their own composited fills. The 700 tier measures
  /// 4.53 / 5.59 / 4.56 / 4.80:1 on the tightest surface in the library (a 10%
  /// tint over an opaque `muted` card), and 4.73–5.07:1 on the others.
  static const BeuiAgentStatusColors light = BeuiAgentStatusColors(
    pending: BeuiAgentStatusPalette(
      foreground: _amber700,
      background: Color(0x1AFE9A00), // amber-500 @ 0.10
      border: Color(0x4DFE9A00), // amber-500 @ 0.30
      solid: _amber500,
      onSolid: _white,
    ),
    running: BeuiAgentStatusPalette(
      foreground: _blue700,
      background: Color(0x1A2B7FFF), // blue-500 @ 0.10
      border: Color(0x4D2B7FFF), // blue-500 @ 0.30
      solid: _blue500,
      onSolid: _white,
    ),
    success: BeuiAgentStatusPalette(
      foreground: _emerald700,
      background: Color(0x1A00BC7D), // emerald-500 @ 0.10
      border: Color(0x4D00BC7D), // emerald-500 @ 0.30
      solid: _emerald500,
      onSolid: _white,
    ),
    failed: BeuiAgentStatusPalette(
      foreground: _rose700,
      background: Color(0x1AFF2056), // rose-500 @ 0.10
      border: Color(0x4DFF2056), // rose-500 @ 0.30
      solid: _rose500,
      onSolid: _white,
    ),
    denied: BeuiAgentStatusPalette(
      foreground: _rose700,
      background: Color(0x1AFF2056),
      border: Color(0x4DFF2056),
      solid: _rose500,
      onSolid: _white,
    ),
    neutral: BeuiAgentStatusPalette(
      foreground: _mutedForegroundLight,
      background: Color(0x1A636363),
      border: Color(0x4D636363),
      solid: _mutedForegroundLight,
      onSolid: _backgroundLight,
    ),
    destructive: BeuiAgentStatusPalette(
      foreground: _rose800,
      background: Color(0x24FF2056), // rose-500 @ 0.14 — heavier than `failed`
      border: Color(0xD9FF2056), // rose-500 @ 0.85 — 3.27:1, a visible edge
      solid: _rose500,
      onSolid: _white,
    ),
  );

  /// Dark-mode defaults — the 400 tier throughout, unchanged from what the
  /// agent widgets already painted (dark mode already cleared AA: 5.87–8.95:1).
  static const BeuiAgentStatusColors dark = BeuiAgentStatusColors(
    pending: BeuiAgentStatusPalette(
      foreground: _amber400,
      background: Color(0x1AFE9A00),
      border: Color(0x4DFE9A00),
      solid: _amber500,
      onSolid: _white,
    ),
    running: BeuiAgentStatusPalette(
      foreground: _blue400,
      background: Color(0x1A2B7FFF),
      border: Color(0x4D2B7FFF),
      solid: _blue500,
      onSolid: _white,
    ),
    success: BeuiAgentStatusPalette(
      foreground: _emerald400,
      background: Color(0x1A00BC7D),
      border: Color(0x4D00BC7D),
      solid: _emerald500,
      onSolid: _white,
    ),
    failed: BeuiAgentStatusPalette(
      foreground: _rose400,
      background: Color(0x1AFF2056),
      border: Color(0x4DFF2056),
      solid: _rose500,
      onSolid: _white,
    ),
    denied: BeuiAgentStatusPalette(
      foreground: _rose400,
      background: Color(0x1AFF2056),
      border: Color(0x4DFF2056),
      solid: _rose500,
      onSolid: _white,
    ),
    neutral: BeuiAgentStatusPalette(
      foreground: _mutedForegroundDark,
      background: Color(0x1A868686),
      border: Color(0x4D868686),
      solid: _mutedForegroundDark,
      onSolid: _backgroundDark,
    ),
    destructive: BeuiAgentStatusPalette(
      foreground: _rose300,
      background: Color(0x24FF2056),
      border: Color(0xD9FF2056), // 3.74:1 in dark
      solid: _rose500,
      onSolid: _white,
    ),
  );

  /// Awaiting a human decision (amber).
  final BeuiAgentStatusPalette pending;

  /// In flight, and the general info tier (blue).
  final BeuiAgentStatusPalette running;

  /// Finished well (emerald).
  final BeuiAgentStatusPalette success;

  /// Finished badly (rose).
  final BeuiAgentStatusPalette failed;

  /// Refused by the user (rose; defaults identical to [failed]).
  final BeuiAgentStatusPalette denied;

  /// No status color (muted).
  final BeuiAgentStatusPalette neutral;

  /// The destructive-approval emphasis tier.
  final BeuiAgentStatusPalette destructive;

  /// The stock set for [brightness].
  static BeuiAgentStatusColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The palette for [status].
  BeuiAgentStatusPalette palette(BeuiAgentStatus status) {
    switch (status) {
      case BeuiAgentStatus.pending:
        return pending;
      case BeuiAgentStatus.running:
        return running;
      case BeuiAgentStatus.success:
        return success;
      case BeuiAgentStatus.failed:
        return failed;
      case BeuiAgentStatus.denied:
        return denied;
      case BeuiAgentStatus.neutral:
        return neutral;
      case BeuiAgentStatus.destructive:
        return destructive;
    }
  }

  /// Returns a copy with the given tiers replaced.
  BeuiAgentStatusColors copyWith({
    BeuiAgentStatusPalette? pending,
    BeuiAgentStatusPalette? running,
    BeuiAgentStatusPalette? success,
    BeuiAgentStatusPalette? failed,
    BeuiAgentStatusPalette? denied,
    BeuiAgentStatusPalette? neutral,
    BeuiAgentStatusPalette? destructive,
  }) {
    return BeuiAgentStatusColors(
      pending: pending ?? this.pending,
      running: running ?? this.running,
      success: success ?? this.success,
      failed: failed ?? this.failed,
      denied: denied ?? this.denied,
      neutral: neutral ?? this.neutral,
      destructive: destructive ?? this.destructive,
    );
  }

  /// Linearly interpolates two status sets, tier by tier.
  static BeuiAgentStatusColors lerp(
    BeuiAgentStatusColors a,
    BeuiAgentStatusColors b,
    double t,
  ) {
    return BeuiAgentStatusColors(
      pending: BeuiAgentStatusPalette.lerp(a.pending, b.pending, t),
      running: BeuiAgentStatusPalette.lerp(a.running, b.running, t),
      success: BeuiAgentStatusPalette.lerp(a.success, b.success, t),
      failed: BeuiAgentStatusPalette.lerp(a.failed, b.failed, t),
      denied: BeuiAgentStatusPalette.lerp(a.denied, b.denied, t),
      neutral: BeuiAgentStatusPalette.lerp(a.neutral, b.neutral, t),
      destructive: BeuiAgentStatusPalette.lerp(a.destructive, b.destructive, t),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeuiAgentStatusColors &&
        other.pending == pending &&
        other.running == running &&
        other.success == success &&
        other.failed == failed &&
        other.denied == denied &&
        other.neutral == neutral &&
        other.destructive == destructive;
  }

  @override
  int get hashCode => Object.hash(
    pending,
    running,
    success,
    failed,
    denied,
    neutral,
    destructive,
  );
}
