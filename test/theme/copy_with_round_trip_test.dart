// Table-driven guard for the hand-written value types under lib/src/theme/:
// beui_colors.dart (BeuiColors, BeuiGlass), beui_agent_theme.dart
// (BeuiAgentTypography, BeuiAgentShapes, BeuiAgentLayout, BeuiAgentStructure,
// BeuiAgentIcons, BeuiAgentTheme), beui_agent_strings.dart (BeuiAgentStrings),
// beui_agent_status_colors.dart (BeuiAgentStatusPalette,
// BeuiAgentStatusColors). None of them get `==`/`hashCode`/`copyWith`/`lerp`
// from codegen, so a wrong `??`, a field missing from `==`, or a swapped pair
// in `lerp` is silent without a test that walks every field.
//
// Each class gets one row per constructor field: `sample` is the distinct
// value `override` sets via copyWith, `read` extracts the field back out. See
// `runFieldTable` / `runLerpTable` below for what every row is checked
// against. When a field is added to one of these classes, add a row to its
// table here — the `table.length == expectedFieldCount` assertion fails
// loudly otherwise.
import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Harness ──────────────────────────────────────────────────────────────

/// One field's probe. [sample] is the value [override] sets via `copyWith`;
/// [read] extracts the field back out of any instance of [T].
typedef FieldProbe<T> = ({
  String name,
  Object? sample,
  T Function(T base) override,
  Object? Function(T obj) read,
});

FieldProbe<T> field<T, F>({
  required String name,
  required F sample,
  required T Function(T base, F value) set,
  required F Function(T obj) get,
}) => (
  name: name,
  sample: sample,
  override: (base) => set(base, sample),
  read: (obj) => get(obj),
);

/// Runs, for every row in [table]: (a) copyWith sets the field to its sample,
/// (b) copyWith does not bleed into any other row's field, (c) `==` and
/// `hashCode` see the change, (d) equality is structural. Also asserts
/// [table] has exactly [expectedFieldCount] rows, so an added/removed field
/// in [sourceFile] is caught here.
void runFieldTable<T>({
  required String className,
  required T base,
  required List<FieldProbe<T>> table,
  required int expectedFieldCount,
  required String sourceFile,
}) {
  group(className, () {
    test('table covers every constructor field', () {
      expect(
        table.length,
        expectedFieldCount,
        reason:
            '$className has $expectedFieldCount fields in $sourceFile — add '
            'a row to this table when a field is added or removed there.',
      );
    });

    for (final row in table) {
      test('${row.name}: copyWith sets it, does not bleed, '
          'and is seen by == / hashCode', () {
        final changed = row.override(base);

        expect(
          row.read(changed),
          row.sample,
          reason: 'copyWith(${row.name}: ...) did not set ${row.name}',
        );

        for (final other in table) {
          if (other.name == row.name) continue;
          expect(
            other.read(changed),
            other.read(base),
            reason: 'copyWith(${row.name}: ...) bled into ${other.name}',
          );
        }

        expect(
          changed == base,
          isFalse,
          reason: '${row.name} is missing from operator==',
        );
        expect(
          changed.hashCode == base.hashCode,
          isFalse,
          reason: '${row.name} is missing from hashCode',
        );
        expect(
          row.override(base) == changed,
          isTrue,
          reason: '${row.name}: equality should be structural',
        );
      });
    }
  });
}

/// Folds every row's [FieldProbe.override] over [base], producing a value
/// that differs from [base] in every field in [table] — the `b` endpoint for
/// a lerp test.
T buildFullyDifferent<T>(T base, List<FieldProbe<T>> table) =>
    table.fold(base, (acc, row) => row.override(acc));

/// Asserts `lerp(a, b, 0) == a`, `lerp(a, b, 1) == b`, and — for the field
/// names in [continuousFields] — that `lerp(a, b, 0.5)` reads as neither
/// endpoint (proof the field actually interpolates rather than snapping).
void runLerpTable<T>({
  required String className,
  required T a,
  required T b,
  required T Function(T a, T b, double t) lerp,
  required List<FieldProbe<T>> table,
  Set<String> continuousFields = const {},
}) {
  group('$className.lerp', () {
    test('t=0 returns a, t=1 returns b', () {
      expect(lerp(a, b, 0), a);
      expect(lerp(a, b, 1), b);
    });

    if (continuousFields.isNotEmpty) {
      test('t=0.5 interpolates continuous (Color/double/EdgeInsets) fields', () {
        final mid = lerp(a, b, 0.5);
        for (final row in table) {
          if (!continuousFields.contains(row.name)) continue;
          final midValue = row.read(mid);
          expect(
            midValue == row.read(a) || midValue == row.read(b),
            isFalse,
            reason:
                '${row.name} did not interpolate at t=0.5 (still an endpoint)',
          );
        }
      });
    }
  });
}

// ── Shared samples ───────────────────────────────────────────────────────

const _sampleColor = Color(0xFF123456);
const _sampleDouble = 99.0;
const _sampleEdgeInsets = EdgeInsets.all(13);
const _sampleBorderRadius = BorderRadius.all(Radius.circular(41));
const _sampleTextStyle = TextStyle(fontSize: 77, fontWeight: FontWeight.w900);
const _sampleIcon = LucideIcons.zap;
const _sampleString = 'sample';

// ── BeuiGlass ────────────────────────────────────────────────────────────

const _glassBase = BeuiGlass(bg: Color(0xFF010203), border: Color(0xFF040506));

final _glassTable = <FieldProbe<BeuiGlass>>[
  field<BeuiGlass, Color>(
    name: 'bg',
    sample: _sampleColor,
    set: (g, v) => g.copyWith(bg: v),
    get: (g) => g.bg,
  ),
  field<BeuiGlass, Color>(
    name: 'border',
    sample: _sampleColor,
    set: (g, v) => g.copyWith(border: v),
    get: (g) => g.border,
  ),
  field<BeuiGlass, double>(
    name: 'blur',
    sample: _sampleDouble,
    set: (g, v) => g.copyWith(blur: v),
    get: (g) => g.blur,
  ),
];

const _glassContinuous = {'bg', 'border', 'blur'};

// ── BeuiColors ───────────────────────────────────────────────────────────

final _beuiColorsTable = <FieldProbe<BeuiColors>>[
  field<BeuiColors, Color>(
    name: 'background',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(background: v),
    get: (c) => c.background,
  ),
  field<BeuiColors, Color>(
    name: 'foreground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(foreground: v),
    get: (c) => c.foreground,
  ),
  field<BeuiColors, Color>(
    name: 'card',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(card: v),
    get: (c) => c.card,
  ),
  field<BeuiColors, Color>(
    name: 'cardForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(cardForeground: v),
    get: (c) => c.cardForeground,
  ),
  field<BeuiColors, Color>(
    name: 'popover',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(popover: v),
    get: (c) => c.popover,
  ),
  field<BeuiColors, Color>(
    name: 'popoverForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(popoverForeground: v),
    get: (c) => c.popoverForeground,
  ),
  field<BeuiColors, Color>(
    name: 'primary',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(primary: v),
    get: (c) => c.primary,
  ),
  field<BeuiColors, Color>(
    name: 'primaryForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(primaryForeground: v),
    get: (c) => c.primaryForeground,
  ),
  field<BeuiColors, Color>(
    name: 'secondary',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(secondary: v),
    get: (c) => c.secondary,
  ),
  field<BeuiColors, Color>(
    name: 'secondaryForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(secondaryForeground: v),
    get: (c) => c.secondaryForeground,
  ),
  field<BeuiColors, Color>(
    name: 'muted',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(muted: v),
    get: (c) => c.muted,
  ),
  field<BeuiColors, Color>(
    name: 'mutedForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(mutedForeground: v),
    get: (c) => c.mutedForeground,
  ),
  field<BeuiColors, Color>(
    name: 'accent',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(accent: v),
    get: (c) => c.accent,
  ),
  field<BeuiColors, Color>(
    name: 'accentForeground',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(accentForeground: v),
    get: (c) => c.accentForeground,
  ),
  field<BeuiColors, Color>(
    name: 'destructive',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(destructive: v),
    get: (c) => c.destructive,
  ),
  field<BeuiColors, Color>(
    name: 'border',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(border: v),
    get: (c) => c.border,
  ),
  field<BeuiColors, Color>(
    name: 'input',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(input: v),
    get: (c) => c.input,
  ),
  field<BeuiColors, Color>(
    name: 'ring',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(ring: v),
    get: (c) => c.ring,
  ),
  field<BeuiColors, Color>(
    name: 'borderStrong',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(borderStrong: v),
    get: (c) => c.borderStrong,
  ),
  field<BeuiColors, Color>(
    name: 'focusRing',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(focusRing: v),
    get: (c) => c.focusRing,
  ),
  field<BeuiColors, Color>(
    name: 'success',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(success: v),
    get: (c) => c.success,
  ),
  field<BeuiColors, Color>(
    name: 'warning',
    sample: _sampleColor,
    set: (c, v) => c.copyWith(warning: v),
    get: (c) => c.warning,
  ),
  field<BeuiColors, BeuiGlass>(
    name: 'glass',
    sample: _glassBase,
    set: (c, v) => c.copyWith(glass: v),
    get: (c) => c.glass,
  ),
  field<BeuiColors, BeuiColorTheme>(
    name: 'colorTheme',
    sample: BeuiColorTheme.violet,
    set: (c, v) => c.copyWith(colorTheme: v),
    get: (c) => c.colorTheme,
  ),
  field<BeuiColors, Brightness>(
    name: 'brightness',
    sample: Brightness.dark,
    set: (c, v) => c.copyWith(brightness: v),
    get: (c) => c.brightness,
  ),
];

const _beuiColorsContinuous = {
  'background',
  'foreground',
  'card',
  'cardForeground',
  'popover',
  'popoverForeground',
  'primary',
  'primaryForeground',
  'secondary',
  'secondaryForeground',
  'muted',
  'mutedForeground',
  'accent',
  'accentForeground',
  'destructive',
  'border',
  'input',
  'ring',
  'borderStrong',
  'focusRing',
  'success',
  'warning',
};

// ── BeuiAgentTypography ─────────────────────────────────────────────────

const _typographyTable = <String>[
  'assistantBody',
  'userBody',
  'title',
  'description',
  'metadata',
  'status',
  'action',
  'mono',
];

// A dedicated pair for the lerp endpoint test only (not the field table's
// `typographyBase` / folded sample): the real per-role defaults set
// different TextStyle property shapes (e.g. `status` has no height, `mono`
// has a fontFamily, `action` has a weight), and `TextStyle.lerp` does not
// hit an exact endpoint when a numeric field is null on only one side of the
// pair (see the `_sampleTypography` comment above). Setting fontSize +
// height + fontWeight on every role, on both sides, sidesteps that and lets
// `lerp(a, b, 0) == a` / `lerp(a, b, 1) == b` hold exactly.
const _typographyLerpStyleA = TextStyle(
  fontSize: 10,
  height: 1.1,
  fontWeight: FontWeight.w300,
);
const _typographyLerpStyleB = TextStyle(
  fontSize: 50,
  height: 2.2,
  fontWeight: FontWeight.w700,
);
const _typographyLerpA = BeuiAgentTypography(
  assistantBody: _typographyLerpStyleA,
  userBody: _typographyLerpStyleA,
  title: _typographyLerpStyleA,
  description: _typographyLerpStyleA,
  metadata: _typographyLerpStyleA,
  status: _typographyLerpStyleA,
  action: _typographyLerpStyleA,
  mono: _typographyLerpStyleA,
);
const _typographyLerpB = BeuiAgentTypography(
  assistantBody: _typographyLerpStyleB,
  userBody: _typographyLerpStyleB,
  title: _typographyLerpStyleB,
  description: _typographyLerpStyleB,
  metadata: _typographyLerpStyleB,
  status: _typographyLerpStyleB,
  action: _typographyLerpStyleB,
  mono: _typographyLerpStyleB,
);

final _agentTypographyTable = <FieldProbe<BeuiAgentTypography>>[
  field<BeuiAgentTypography, TextStyle>(
    name: 'assistantBody',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(assistantBody: v),
    get: (t) => t.assistantBody,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'userBody',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(userBody: v),
    get: (t) => t.userBody,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'title',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(title: v),
    get: (t) => t.title,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'description',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(description: v),
    get: (t) => t.description,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'metadata',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(metadata: v),
    get: (t) => t.metadata,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'status',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(status: v),
    get: (t) => t.status,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'action',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(action: v),
    get: (t) => t.action,
  ),
  field<BeuiAgentTypography, TextStyle>(
    name: 'mono',
    sample: _sampleTextStyle,
    set: (t, v) => t.copyWith(mono: v),
    get: (t) => t.mono,
  ),
];

// ── BeuiAgentShapes ──────────────────────────────────────────────────────

final _agentShapesTable = <FieldProbe<BeuiAgentShapes>>[
  field<BeuiAgentShapes, BorderRadius>(
    name: 'userBubble',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(userBubble: v),
    get: (s) => s.userBubble,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'assistantBubble',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(assistantBubble: v),
    get: (s) => s.assistantBubble,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'card',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(card: v),
    get: (s) => s.card,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'nested',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(nested: v),
    get: (s) => s.nested,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'control',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(control: v),
    get: (s) => s.control,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'chip',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(chip: v),
    get: (s) => s.chip,
  ),
  field<BeuiAgentShapes, BorderRadius>(
    name: 'pill',
    sample: _sampleBorderRadius,
    set: (s, v) => s.copyWith(pill: v),
    get: (s) => s.pill,
  ),
];

// ── BeuiAgentLayout ──────────────────────────────────────────────────────

final _agentLayoutTable = <FieldProbe<BeuiAgentLayout>>[
  field<BeuiAgentLayout, EdgeInsets>(
    name: 'conversationGutter',
    sample: _sampleEdgeInsets,
    set: (l, v) => l.copyWith(conversationGutter: v),
    get: (l) => l.conversationGutter,
  ),
  field<BeuiAgentLayout, double>(
    name: 'turnSpacing',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(turnSpacing: v),
    get: (l) => l.turnSpacing,
  ),
  field<BeuiAgentLayout, double>(
    name: 'groupedMessageSpacing',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(groupedMessageSpacing: v),
    get: (l) => l.groupedMessageSpacing,
  ),
  field<BeuiAgentLayout, double>(
    name: 'groupedMessageSpacingRelaxed',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(groupedMessageSpacingRelaxed: v),
    get: (l) => l.groupedMessageSpacingRelaxed,
  ),
  field<BeuiAgentLayout, EdgeInsets>(
    name: 'bubblePadding',
    sample: _sampleEdgeInsets,
    set: (l, v) => l.copyWith(bubblePadding: v),
    get: (l) => l.bubblePadding,
  ),
  field<BeuiAgentLayout, EdgeInsets>(
    name: 'cardPadding',
    sample: _sampleEdgeInsets,
    set: (l, v) => l.copyWith(cardPadding: v),
    get: (l) => l.cardPadding,
  ),
  field<BeuiAgentLayout, double>(
    name: 'sectionSpacing',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(sectionSpacing: v),
    get: (l) => l.sectionSpacing,
  ),
  field<BeuiAgentLayout, double>(
    name: 'actionSpacing',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(actionSpacing: v),
    get: (l) => l.actionSpacing,
  ),
  field<BeuiAgentLayout, double>(
    name: 'maxBubbleWidthFactor',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(maxBubbleWidthFactor: v),
    get: (l) => l.maxBubbleWidthFactor,
  ),
  field<BeuiAgentLayout, double>(
    name: 'avatarSize',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(avatarSize: v),
    get: (l) => l.avatarSize,
  ),
  field<BeuiAgentLayout, double>(
    name: 'iconSize',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(iconSize: v),
    get: (l) => l.iconSize,
  ),
  field<BeuiAgentLayout, double>(
    name: 'rowGap',
    sample: _sampleDouble,
    set: (l, v) => l.copyWith(rowGap: v),
    get: (l) => l.rowGap,
  ),
];

const _agentLayoutContinuous = {
  'conversationGutter',
  'turnSpacing',
  'groupedMessageSpacing',
  'groupedMessageSpacingRelaxed',
  'bubblePadding',
  'cardPadding',
  'sectionSpacing',
  'actionSpacing',
  'maxBubbleWidthFactor',
  'avatarSize',
  'iconSize',
  'rowGap',
};

// ── BeuiAgentStructure ───────────────────────────────────────────────────

final _agentStructureTable = <FieldProbe<BeuiAgentStructure>>[
  field<BeuiAgentStructure, double>(
    name: 'borderWidth',
    sample: _sampleDouble,
    set: (s, v) => s.copyWith(borderWidth: v),
    get: (s) => s.borderWidth,
  ),
  field<BeuiAgentStructure, double>(
    name: 'emphasisBorderWidth',
    sample: _sampleDouble,
    set: (s, v) => s.copyWith(emphasisBorderWidth: v),
    get: (s) => s.emphasisBorderWidth,
  ),
  field<BeuiAgentStructure, bool>(
    name: 'useGlassSurfaces',
    sample: true,
    set: (s, v) => s.copyWith(useGlassSurfaces: v),
    get: (s) => s.useGlassSurfaces,
  ),
];

const _agentStructureContinuous = {'borderWidth', 'emphasisBorderWidth'};

// ── BeuiAgentIcons ───────────────────────────────────────────────────────

final _agentIconsTable = <FieldProbe<BeuiAgentIcons>>[
  field<BeuiAgentIcons, IconData>(
    name: 'pendingApproval',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(pendingApproval: v),
    get: (i) => i.pendingApproval,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'pendingQuestion',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(pendingQuestion: v),
    get: (i) => i.pendingQuestion,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'approved',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(approved: v),
    get: (i) => i.approved,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'rejected',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(rejected: v),
    get: (i) => i.rejected,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'copy',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(copy: v),
    get: (i) => i.copy,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'copied',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(copied: v),
    get: (i) => i.copied,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'retry',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(retry: v),
    get: (i) => i.retry,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'expand',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(expand: v),
    get: (i) => i.expand,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'send',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(send: v),
    get: (i) => i.send,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'add',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(add: v),
    get: (i) => i.add,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'edit',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(edit: v),
    get: (i) => i.edit,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'close',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(close: v),
    get: (i) => i.close,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'warning',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(warning: v),
    get: (i) => i.warning,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'shield',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(shield: v),
    get: (i) => i.shield,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'tool',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(tool: v),
    get: (i) => i.tool,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'terminal',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(terminal: v),
    get: (i) => i.terminal,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'request',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(request: v),
    get: (i) => i.request,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'spinner',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(spinner: v),
    get: (i) => i.spinner,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'search',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(search: v),
    get: (i) => i.search,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'web',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(web: v),
    get: (i) => i.web,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'file',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(file: v),
    get: (i) => i.file,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'todo',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(todo: v),
    get: (i) => i.todo,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'citations',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(citations: v),
    get: (i) => i.citations,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'externalLink',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(externalLink: v),
    get: (i) => i.externalLink,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'thumbsUp',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(thumbsUp: v),
    get: (i) => i.thumbsUp,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'thumbsDown',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(thumbsDown: v),
    get: (i) => i.thumbsDown,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'thinking',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(thinking: v),
    get: (i) => i.thinking,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'message',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(message: v),
    get: (i) => i.message,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'folder',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(folder: v),
    get: (i) => i.folder,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'folderOpen',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(folderOpen: v),
    get: (i) => i.folderOpen,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'bookmark',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(bookmark: v),
    get: (i) => i.bookmark,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'document',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(document: v),
    get: (i) => i.document,
  ),
  field<BeuiAgentIcons, IconData>(
    name: 'more',
    sample: _sampleIcon,
    set: (i, v) => i.copyWith(more: v),
    get: (i) => i.more,
  ),
];

// ── BeuiAgentStatusPalette ───────────────────────────────────────────────

const _paletteBase = BeuiAgentStatusPalette(
  foreground: Color(0xFF010203),
  background: Color(0xFF040506),
  border: Color(0xFF070809),
  solid: Color(0xFF0A0B0C),
  onSolid: Color(0xFF0D0E0F),
);

final _statusPaletteTable = <FieldProbe<BeuiAgentStatusPalette>>[
  field<BeuiAgentStatusPalette, Color>(
    name: 'foreground',
    sample: _sampleColor,
    set: (p, v) => p.copyWith(foreground: v),
    get: (p) => p.foreground,
  ),
  field<BeuiAgentStatusPalette, Color>(
    name: 'background',
    sample: _sampleColor,
    set: (p, v) => p.copyWith(background: v),
    get: (p) => p.background,
  ),
  field<BeuiAgentStatusPalette, Color>(
    name: 'border',
    sample: _sampleColor,
    set: (p, v) => p.copyWith(border: v),
    get: (p) => p.border,
  ),
  field<BeuiAgentStatusPalette, Color>(
    name: 'solid',
    sample: _sampleColor,
    set: (p, v) => p.copyWith(solid: v),
    get: (p) => p.solid,
  ),
  field<BeuiAgentStatusPalette, Color>(
    name: 'onSolid',
    sample: _sampleColor,
    set: (p, v) => p.copyWith(onSolid: v),
    get: (p) => p.onSolid,
  ),
];

const _statusPaletteContinuous = {
  'foreground',
  'background',
  'border',
  'solid',
  'onSolid',
};

// ── BeuiAgentStatusColors ────────────────────────────────────────────────

const _samplePalette = BeuiAgentStatusPalette(
  foreground: Color(0xFF111213),
  background: Color(0xFF141516),
  border: Color(0xFF171819),
  solid: Color(0xFF1A1B1C),
  onSolid: Color(0xFF1D1E1F),
);

final _statusColorsTable = <FieldProbe<BeuiAgentStatusColors>>[
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'pending',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(pending: v),
    get: (c) => c.pending,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'running',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(running: v),
    get: (c) => c.running,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'success',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(success: v),
    get: (c) => c.success,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'failed',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(failed: v),
    get: (c) => c.failed,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'denied',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(denied: v),
    get: (c) => c.denied,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'neutral',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(neutral: v),
    get: (c) => c.neutral,
  ),
  field<BeuiAgentStatusColors, BeuiAgentStatusPalette>(
    name: 'destructive',
    sample: _samplePalette,
    set: (c, v) => c.copyWith(destructive: v),
    get: (c) => c.destructive,
  ),
];

// ── BeuiAgentTheme ───────────────────────────────────────────────────────

// The default `mono` role sets only fontSize + fontFamily(Fallback) (no
// height, no weight). `TextStyle.lerp` treats a numeric field that is null on
// exactly one side as a *constant* at the non-null side's value for every t
// (not a blend, and not null-preserving) — so a sample that introduces
// fontWeight/height here, which the default lacks, would make
// `BeuiAgentTheme.lerp(a, b, 0)` and `(..., 1)` land on neither endpoint.
// Matching the default's field shape (fontSize + fontFamily only) keeps the
// interpolation exact.
const _sampleTypography = BeuiAgentTypography(
  mono: TextStyle(
    fontSize: 77,
    fontFamily: 'sample-mono',
    fontFamilyFallback: ['sample-mono'],
  ),
);
const _sampleShapes = BeuiAgentShapes(pill: _sampleBorderRadius);
const _sampleLayout = BeuiAgentLayout(rowGap: _sampleDouble);
const _sampleStructure = BeuiAgentStructure(useGlassSurfaces: true);
const _sampleIcons = BeuiAgentIcons(more: _sampleIcon);
final _sampleStrings = const BeuiAgentStrings().copyWith(
  deny: 'sample-strings',
);

final _agentThemeTable = <FieldProbe<BeuiAgentTheme>>[
  field<BeuiAgentTheme, BeuiAgentTypography>(
    name: 'typography',
    sample: _sampleTypography,
    set: (t, v) => t.copyWith(typography: v),
    get: (t) => t.typography,
  ),
  field<BeuiAgentTheme, BeuiAgentShapes>(
    name: 'shapes',
    sample: _sampleShapes,
    set: (t, v) => t.copyWith(shapes: v),
    get: (t) => t.shapes,
  ),
  field<BeuiAgentTheme, BeuiAgentLayout>(
    name: 'layout',
    sample: _sampleLayout,
    set: (t, v) => t.copyWith(layout: v),
    get: (t) => t.layout,
  ),
  field<BeuiAgentTheme, BeuiAgentStructure>(
    name: 'structure',
    sample: _sampleStructure,
    set: (t, v) => t.copyWith(structure: v),
    get: (t) => t.structure,
  ),
  field<BeuiAgentTheme, BeuiAgentIcons>(
    name: 'icons',
    sample: _sampleIcons,
    set: (t, v) => t.copyWith(icons: v),
    get: (t) => t.icons,
  ),
  field<BeuiAgentTheme, BeuiAgentStatusColors>(
    name: 'statusLight',
    // Default is BeuiAgentStatusColors.light — dark is a distinct value.
    sample: BeuiAgentStatusColors.dark,
    set: (t, v) => t.copyWith(statusLight: v),
    get: (t) => t.statusLight,
  ),
  field<BeuiAgentTheme, BeuiAgentStatusColors>(
    name: 'statusDark',
    // Default is BeuiAgentStatusColors.dark — light is a distinct value.
    sample: BeuiAgentStatusColors.light,
    set: (t, v) => t.copyWith(statusDark: v),
    get: (t) => t.statusDark,
  ),
  field<BeuiAgentTheme, BeuiAgentStrings>(
    name: 'strings',
    sample: _sampleStrings,
    set: (t, v) => t.copyWith(strings: v),
    get: (t) => t.strings,
  ),
];

// ── BeuiAgentStrings ─────────────────────────────────────────────────────

String _fnInt(int a) => 'sample';
String _fnIntInt(int a, int b) => 'sample';
String _fnIntIntBool(int a, int b, bool c) => 'sample';
String _fnString(String a) => 'sample';

final _agentStringsTable = <FieldProbe<BeuiAgentStrings>>[
  field<BeuiAgentStrings, String>(
    name: 'toolApprovalTitle',
    sample: _sampleString,
    set: (s, v) => s.copyWith(toolApprovalTitle: v),
    get: (s) => s.toolApprovalTitle,
  ),
  field<BeuiAgentStrings, String>(
    name: 'allowOnce',
    sample: _sampleString,
    set: (s, v) => s.copyWith(allowOnce: v),
    get: (s) => s.allowOnce,
  ),
  field<BeuiAgentStrings, String>(
    name: 'alwaysAllow',
    sample: _sampleString,
    set: (s, v) => s.copyWith(alwaysAllow: v),
    get: (s) => s.alwaysAllow,
  ),
  field<BeuiAgentStrings, String>(
    name: 'deny',
    sample: _sampleString,
    set: (s, v) => s.copyWith(deny: v),
    get: (s) => s.deny,
  ),
  field<BeuiAgentStrings, String>(
    name: 'viewDetails',
    sample: _sampleString,
    set: (s, v) => s.copyWith(viewDetails: v),
    get: (s) => s.viewDetails,
  ),
  field<BeuiAgentStrings, String>(
    name: 'revoke',
    sample: _sampleString,
    set: (s, v) => s.copyWith(revoke: v),
    get: (s) => s.revoke,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusApprovalRequired',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusApprovalRequired: v),
    get: (s) => s.statusApprovalRequired,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusApproving',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusApproving: v),
    get: (s) => s.statusApproving,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusApproved',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusApproved: v),
    get: (s) => s.statusApproved,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusDenied',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusDenied: v),
    get: (s) => s.statusDenied,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusRunning',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusRunning: v),
    get: (s) => s.statusRunning,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusCompleted',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusCompleted: v),
    get: (s) => s.statusCompleted,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusFailed',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusFailed: v),
    get: (s) => s.statusFailed,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusCancelled',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusCancelled: v),
    get: (s) => s.statusCancelled,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusSubmitting',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusSubmitting: v),
    get: (s) => s.statusSubmitting,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusRejected',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusRejected: v),
    get: (s) => s.statusRejected,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusChangesRequested',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusChangesRequested: v),
    get: (s) => s.statusChangesRequested,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusResponseSubmitted',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusResponseSubmitted: v),
    get: (s) => s.statusResponseSubmitted,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusInputRequired',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusInputRequired: v),
    get: (s) => s.statusInputRequired,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusExpired',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusExpired: v),
    get: (s) => s.statusExpired,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusTimedOut',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusTimedOut: v),
    get: (s) => s.statusTimedOut,
  ),
  field<BeuiAgentStrings, String>(
    name: 'statusAlwaysAllowed',
    sample: _sampleString,
    set: (s, v) => s.copyWith(statusAlwaysAllowed: v),
    get: (s) => s.statusAlwaysAllowed,
  ),
  field<BeuiAgentStrings, String>(
    name: 'approvalCardTitle',
    sample: _sampleString,
    set: (s, v) => s.copyWith(approvalCardTitle: v),
    get: (s) => s.approvalCardTitle,
  ),
  field<BeuiAgentStrings, String>(
    name: 'approve',
    sample: _sampleString,
    set: (s, v) => s.copyWith(approve: v),
    get: (s) => s.approve,
  ),
  field<BeuiAgentStrings, String>(
    name: 'requestChanges',
    sample: _sampleString,
    set: (s, v) => s.copyWith(requestChanges: v),
    get: (s) => s.requestChanges,
  ),
  field<BeuiAgentStrings, String>(
    name: 'reject',
    sample: _sampleString,
    set: (s, v) => s.copyWith(reject: v),
    get: (s) => s.reject,
  ),
  field<BeuiAgentStrings, String>(
    name: 'submitResponse',
    sample: _sampleString,
    set: (s, v) => s.copyWith(submitResponse: v),
    get: (s) => s.submitResponse,
  ),
  field<BeuiAgentStrings, String>(
    name: 'dismiss',
    sample: _sampleString,
    set: (s, v) => s.copyWith(dismiss: v),
    get: (s) => s.dismiss,
  ),
  field<BeuiAgentStrings, String>(
    name: 'showDetails',
    sample: _sampleString,
    set: (s, v) => s.copyWith(showDetails: v),
    get: (s) => s.showDetails,
  ),
  field<BeuiAgentStrings, String>(
    name: 'hideDetails',
    sample: _sampleString,
    set: (s, v) => s.copyWith(hideDetails: v),
    get: (s) => s.hideDetails,
  ),
  field<BeuiAgentStrings, String>(
    name: 'previousQuestion',
    sample: _sampleString,
    set: (s, v) => s.copyWith(previousQuestion: v),
    get: (s) => s.previousQuestion,
  ),
  field<BeuiAgentStrings, String>(
    name: 'nextQuestion',
    sample: _sampleString,
    set: (s, v) => s.copyWith(nextQuestion: v),
    get: (s) => s.nextQuestion,
  ),
  field<BeuiAgentStrings, String>(
    name: 'customAnswerPlaceholder',
    sample: _sampleString,
    set: (s, v) => s.copyWith(customAnswerPlaceholder: v),
    get: (s) => s.customAnswerPlaceholder,
  ),
  field<BeuiAgentStrings, String Function(int, int)>(
    name: 'stepCounter',
    sample: _fnIntInt,
    set: (s, v) => s.copyWith(stepCounter: v),
    get: (s) => s.stepCounter,
  ),
  field<BeuiAgentStrings, String Function(int, int)>(
    name: 'questionProgress',
    sample: _fnIntInt,
    set: (s, v) => s.copyWith(questionProgress: v),
    get: (s) => s.questionProgress,
  ),
  field<BeuiAgentStrings, String>(
    name: 'copyResult',
    sample: _sampleString,
    set: (s, v) => s.copyWith(copyResult: v),
    get: (s) => s.copyResult,
  ),
  field<BeuiAgentStrings, String>(
    name: 'copied',
    sample: _sampleString,
    set: (s, v) => s.copyWith(copied: v),
    get: (s) => s.copied,
  ),
  field<BeuiAgentStrings, String>(
    name: 'runAgain',
    sample: _sampleString,
    set: (s, v) => s.copyWith(runAgain: v),
    get: (s) => s.runAgain,
  ),
  field<BeuiAgentStrings, String>(
    name: 'copyCode',
    sample: _sampleString,
    set: (s, v) => s.copyWith(copyCode: v),
    get: (s) => s.copyCode,
  ),
  field<BeuiAgentStrings, String>(
    name: 'copyDiff',
    sample: _sampleString,
    set: (s, v) => s.copyWith(copyDiff: v),
    get: (s) => s.copyDiff,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'hiddenLines',
    sample: _fnInt,
    set: (s, v) => s.copyWith(hiddenLines: v),
    get: (s) => s.hiddenLines,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'hiddenLinesCollapsed',
    sample: _fnInt,
    set: (s, v) => s.copyWith(hiddenLinesCollapsed: v),
    get: (s) => s.hiddenLinesCollapsed,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'expandHiddenLines',
    sample: _fnInt,
    set: (s, v) => s.copyWith(expandHiddenLines: v),
    get: (s) => s.expandHiddenLines,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoListLabel',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoListLabel: v),
    get: (s) => s.todoListLabel,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoListTitle',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoListTitle: v),
    get: (s) => s.todoListTitle,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoEmpty',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoEmpty: v),
    get: (s) => s.todoEmpty,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoEmptyDescription',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoEmptyDescription: v),
    get: (s) => s.todoEmptyDescription,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoStatusPending',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoStatusPending: v),
    get: (s) => s.todoStatusPending,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoStatusInProgress',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoStatusInProgress: v),
    get: (s) => s.todoStatusInProgress,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoStatusCompleted',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoStatusCompleted: v),
    get: (s) => s.todoStatusCompleted,
  ),
  field<BeuiAgentStrings, String>(
    name: 'todoStatusCancelled',
    sample: _sampleString,
    set: (s, v) => s.copyWith(todoStatusCancelled: v),
    get: (s) => s.todoStatusCancelled,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'todoCountDenominator',
    sample: _fnInt,
    set: (s, v) => s.copyWith(todoCountDenominator: v),
    get: (s) => s.todoCountDenominator,
  ),
  field<BeuiAgentStrings, String Function(int, int, bool)>(
    name: 'todoHeaderLabel',
    sample: _fnIntIntBool,
    set: (s, v) => s.copyWith(todoHeaderLabel: v),
    get: (s) => s.todoHeaderLabel,
  ),
  field<BeuiAgentStrings, String Function(String)>(
    name: 'todoRowLabel',
    sample: _fnString,
    set: (s, v) => s.copyWith(todoRowLabel: v),
    get: (s) => s.todoRowLabel,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activitySearching',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activitySearching: v),
    get: (s) => s.activitySearching,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activityRunningTools',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activityRunningTools: v),
    get: (s) => s.activityRunningTools,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activityWorkingThroughRun',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activityWorkingThroughRun: v),
    get: (s) => s.activityWorkingThroughRun,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activityWorking',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activityWorking: v),
    get: (s) => s.activityWorking,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activityThinking',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activityThinking: v),
    get: (s) => s.activityThinking,
  ),
  field<BeuiAgentStrings, String>(
    name: 'activitySearchedWeb',
    sample: _sampleString,
    set: (s, v) => s.copyWith(activitySearchedWeb: v),
    get: (s) => s.activitySearchedWeb,
  ),
  field<BeuiAgentStrings, String Function(String)>(
    name: 'activityThoughtFor',
    sample: _fnString,
    set: (s, v) => s.copyWith(activityThoughtFor: v),
    get: (s) => s.activityThoughtFor,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'activityRanTools',
    sample: _fnInt,
    set: (s, v) => s.copyWith(activityRanTools: v),
    get: (s) => s.activityRanTools,
  ),
  field<BeuiAgentStrings, String Function(int, int)>(
    name: 'activityToolCallsAndMessages',
    sample: _fnIntInt,
    set: (s, v) => s.copyWith(activityToolCallsAndMessages: v),
    get: (s) => s.activityToolCallsAndMessages,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'activityCompletedSteps',
    sample: _fnInt,
    set: (s, v) => s.copyWith(activityCompletedSteps: v),
    get: (s) => s.activityCompletedSteps,
  ),
  field<BeuiAgentStrings, String Function(String)>(
    name: 'activityFailedSummary',
    sample: _fnString,
    set: (s, v) => s.copyWith(activityFailedSummary: v),
    get: (s) => s.activityFailedSummary,
  ),
  field<BeuiAgentStrings, String Function(String)>(
    name: 'activityCancelledSummary',
    sample: _fnString,
    set: (s, v) => s.copyWith(activityCancelledSummary: v),
    get: (s) => s.activityCancelledSummary,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'activityMoreResults',
    sample: _fnInt,
    set: (s, v) => s.copyWith(activityMoreResults: v),
    get: (s) => s.activityMoreResults,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'durationSeconds',
    sample: _fnInt,
    set: (s, v) => s.copyWith(durationSeconds: v),
    get: (s) => s.durationSeconds,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'durationMinutes',
    sample: _fnInt,
    set: (s, v) => s.copyWith(durationMinutes: v),
    get: (s) => s.durationMinutes,
  ),
  field<BeuiAgentStrings, String Function(int, int)>(
    name: 'durationMinutesSeconds',
    sample: _fnIntInt,
    set: (s, v) => s.copyWith(durationMinutesSeconds: v),
    get: (s) => s.durationMinutesSeconds,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'diffAdditions',
    sample: _fnInt,
    set: (s, v) => s.copyWith(diffAdditions: v),
    get: (s) => s.diffAdditions,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'diffDeletions',
    sample: _fnInt,
    set: (s, v) => s.copyWith(diffDeletions: v),
    get: (s) => s.diffDeletions,
  ),
  field<BeuiAgentStrings, String>(
    name: 'copy',
    sample: _sampleString,
    set: (s, v) => s.copyWith(copy: v),
    get: (s) => s.copy,
  ),
  field<BeuiAgentStrings, String>(
    name: 'retry',
    sample: _sampleString,
    set: (s, v) => s.copyWith(retry: v),
    get: (s) => s.retry,
  ),
  field<BeuiAgentStrings, String>(
    name: 'continueAction',
    sample: _sampleString,
    set: (s, v) => s.copyWith(continueAction: v),
    get: (s) => s.continueAction,
  ),
  field<BeuiAgentStrings, String>(
    name: 'helpful',
    sample: _sampleString,
    set: (s, v) => s.copyWith(helpful: v),
    get: (s) => s.helpful,
  ),
  field<BeuiAgentStrings, String>(
    name: 'notHelpful',
    sample: _sampleString,
    set: (s, v) => s.copyWith(notHelpful: v),
    get: (s) => s.notHelpful,
  ),
  field<BeuiAgentStrings, String Function(int)>(
    name: 'showSources',
    sample: _fnInt,
    set: (s, v) => s.copyWith(showSources: v),
    get: (s) => s.showSources,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseFailed',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseFailed: v),
    get: (s) => s.responseFailed,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseStopped',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseStopped: v),
    get: (s) => s.responseStopped,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseSemantics',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseSemantics: v),
    get: (s) => s.responseSemantics,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseBusySemantics',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseBusySemantics: v),
    get: (s) => s.responseBusySemantics,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseFailedSemantics',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseFailedSemantics: v),
    get: (s) => s.responseFailedSemantics,
  ),
  field<BeuiAgentStrings, String>(
    name: 'responseStoppedSemantics',
    sample: _sampleString,
    set: (s, v) => s.copyWith(responseStoppedSemantics: v),
    get: (s) => s.responseStoppedSemantics,
  ),
  field<BeuiAgentStrings, String>(
    name: 'jumpToLatest',
    sample: _sampleString,
    set: (s, v) => s.copyWith(jumpToLatest: v),
    get: (s) => s.jumpToLatest,
  ),
  field<BeuiAgentStrings, String>(
    name: 'conversation',
    sample: _sampleString,
    set: (s, v) => s.copyWith(conversation: v),
    get: (s) => s.conversation,
  ),
  field<BeuiAgentStrings, String>(
    name: 'messageNavigation',
    sample: _sampleString,
    set: (s, v) => s.copyWith(messageNavigation: v),
    get: (s) => s.messageNavigation,
  ),
  field<BeuiAgentStrings, String>(
    name: 'stopGenerating',
    sample: _sampleString,
    set: (s, v) => s.copyWith(stopGenerating: v),
    get: (s) => s.stopGenerating,
  ),
  field<BeuiAgentStrings, String>(
    name: 'promptPlaceholder',
    sample: _sampleString,
    set: (s, v) => s.copyWith(promptPlaceholder: v),
    get: (s) => s.promptPlaceholder,
  ),
  field<BeuiAgentStrings, String>(
    name: 'promptSemanticLabel',
    sample: _sampleString,
    set: (s, v) => s.copyWith(promptSemanticLabel: v),
    get: (s) => s.promptSemanticLabel,
  ),
];

// ── main ─────────────────────────────────────────────────────────────────

void main() {
  runFieldTable(
    className: 'BeuiGlass',
    base: _glassBase,
    table: _glassTable,
    expectedFieldCount: 3,
    sourceFile: 'lib/src/theme/beui_colors.dart',
  );
  runLerpTable(
    className: 'BeuiGlass',
    a: _glassBase,
    b: buildFullyDifferent(_glassBase, _glassTable),
    lerp: BeuiGlass.lerp,
    table: _glassTable,
    continuousFields: _glassContinuous,
  );

  final colorsBase = BeuiColors.light();
  runFieldTable(
    className: 'BeuiColors',
    base: colorsBase,
    table: _beuiColorsTable,
    expectedFieldCount: 25,
    sourceFile: 'lib/src/theme/beui_colors.dart',
  );
  runLerpTable(
    className: 'BeuiColors',
    a: colorsBase,
    b: buildFullyDifferent(colorsBase, _beuiColorsTable),
    lerp: (a, b, t) => a.lerp(b, t),
    table: _beuiColorsTable,
    continuousFields: _beuiColorsContinuous,
  );

  const typographyBase = BeuiAgentTypography();
  runFieldTable(
    className: 'BeuiAgentTypography',
    base: typographyBase,
    table: _agentTypographyTable,
    expectedFieldCount: _typographyTable.length,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentTypography',
    a: _typographyLerpA,
    b: _typographyLerpB,
    lerp: BeuiAgentTypography.lerp,
    table: _agentTypographyTable,
  );

  const shapesBase = BeuiAgentShapes();
  runFieldTable(
    className: 'BeuiAgentShapes',
    base: shapesBase,
    table: _agentShapesTable,
    expectedFieldCount: 7,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentShapes',
    a: shapesBase,
    b: buildFullyDifferent(shapesBase, _agentShapesTable),
    lerp: BeuiAgentShapes.lerp,
    table: _agentShapesTable,
  );

  const layoutBase = BeuiAgentLayout();
  runFieldTable(
    className: 'BeuiAgentLayout',
    base: layoutBase,
    table: _agentLayoutTable,
    expectedFieldCount: 12,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentLayout',
    a: layoutBase,
    b: buildFullyDifferent(layoutBase, _agentLayoutTable),
    lerp: BeuiAgentLayout.lerp,
    table: _agentLayoutTable,
    continuousFields: _agentLayoutContinuous,
  );

  const structureBase = BeuiAgentStructure();
  runFieldTable(
    className: 'BeuiAgentStructure',
    base: structureBase,
    table: _agentStructureTable,
    expectedFieldCount: 3,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentStructure',
    a: structureBase,
    b: buildFullyDifferent(structureBase, _agentStructureTable),
    lerp: BeuiAgentStructure.lerp,
    table: _agentStructureTable,
    continuousFields: _agentStructureContinuous,
  );

  const iconsBase = BeuiAgentIcons();
  runFieldTable(
    className: 'BeuiAgentIcons',
    base: iconsBase,
    table: _agentIconsTable,
    expectedFieldCount: 33,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentIcons',
    a: iconsBase,
    b: buildFullyDifferent(iconsBase, _agentIconsTable),
    lerp: BeuiAgentIcons.lerp,
    table: _agentIconsTable,
  );

  runFieldTable(
    className: 'BeuiAgentStatusPalette',
    base: _paletteBase,
    table: _statusPaletteTable,
    expectedFieldCount: 5,
    sourceFile: 'lib/src/theme/beui_agent_status_colors.dart',
  );
  runLerpTable(
    className: 'BeuiAgentStatusPalette',
    a: _paletteBase,
    b: buildFullyDifferent(_paletteBase, _statusPaletteTable),
    lerp: BeuiAgentStatusPalette.lerp,
    table: _statusPaletteTable,
    continuousFields: _statusPaletteContinuous,
  );

  runFieldTable(
    className: 'BeuiAgentStatusColors',
    base: BeuiAgentStatusColors.light,
    table: _statusColorsTable,
    expectedFieldCount: 7,
    sourceFile: 'lib/src/theme/beui_agent_status_colors.dart',
  );
  runLerpTable(
    className: 'BeuiAgentStatusColors',
    a: BeuiAgentStatusColors.light,
    b: buildFullyDifferent(BeuiAgentStatusColors.light, _statusColorsTable),
    lerp: BeuiAgentStatusColors.lerp,
    table: _statusColorsTable,
  );

  runFieldTable(
    className: 'BeuiAgentStrings',
    base: const BeuiAgentStrings(),
    table: _agentStringsTable,
    expectedFieldCount: 90,
    sourceFile: 'lib/src/theme/beui_agent_strings.dart',
  );
  runLerpTable(
    className: 'BeuiAgentStrings',
    a: const BeuiAgentStrings(),
    b: buildFullyDifferent(const BeuiAgentStrings(), _agentStringsTable),
    lerp: BeuiAgentStrings.lerp,
    table: _agentStringsTable,
  );

  runFieldTable(
    className: 'BeuiAgentTheme',
    base: BeuiAgentTheme.standard,
    table: _agentThemeTable,
    expectedFieldCount: 8,
    sourceFile: 'lib/src/theme/beui_agent_theme.dart',
  );
  runLerpTable(
    className: 'BeuiAgentTheme',
    a: BeuiAgentTheme.standard,
    b: buildFullyDifferent(BeuiAgentTheme.standard, _agentThemeTable),
    lerp: (a, b, t) => a.lerp(b, t),
    table: _agentThemeTable,
  );
}
