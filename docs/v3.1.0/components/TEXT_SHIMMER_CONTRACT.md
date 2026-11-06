# Additive TextShimmer child contract

Root approved this exact child-only additive contract after the owner reviewed
TextShimmer's own normal and reduced source and unchanged-Flutter acquisitions.
See [shared baseline evidence](SHARED_BASELINE_EVIDENCE.md). Agents'
ThinkingShimmer acquisition was not substituted for this component's baseline.
No animation-phase or reduced-motion retune is approved.

## Caller contract

The existing positional string constructor and every public parameter type
remain unchanged. The additive constructor accepts one widget.

```dart
const BeuiTextShimmer.child(
	Widget child, {
	Duration duration = const Duration(milliseconds: 2500),
	TextStyle? style,
	TextAlign? textAlign,
	Color? baseColor,
	Color? highlightColor,
	Key? key,
});
```

Agents can compose its source-style ThinkingShimmer through the shared widget.

```dart
BeuiTextShimmer.child(
	child,
	duration: duration,
	style: const TextStyle(fontWeight: FontWeight.w500),
)
```

The ThinkingShimmer owner supplies its source default of 1800ms. TextShimmer's
default remains 2500ms. The source React `as` prop has no separate Flutter
parameter because the caller supplies the widget tree directly.

## Content, style, and ownership

The existing `String text` field remains non-nullable. The child constructor
sets it to the empty string and stores the supplied widget privately. The
empty string is a compatibility value, not a textual representation of the
child. Existing `BeuiTextShimmer('Loading')` calls retain their current value.

The string constructor builds its existing Text. The child constructor passes
its widget through DefaultTextStyle.merge with the supplied style and
textAlign. Unspecified values inherit the caller's defaults. Explicit styles
inside the child retain Flutter's normal precedence. No padding, alignment,
fixed dimensions, additional semantics, or interaction handler is introduced.

Both constructors use the same state class, controller, shader calculation,
ShaderMask, and RepaintBoundary. There is no Agents-owned animation controller
or mask. Child layout, focus nodes, semantics, and callbacks remain owned by
the child. Changes to constructor, child, duration, style, or colors must not
create a second ticker or retain a disposed child.

The mask colors remain baseColor and highlightColor, falling back to
BeuiColors.mutedForeground and BeuiColors.foreground. Child text colors do not
override the final mask colors. A widget child is masked through all its
painted alpha, including icons and painted backgrounds. The source CSS uses
background-clip:text, so arbitrary non-text paint is not a proven equivalent.
Rich textual children are the immediate shared consumer requirement. Mixed
paint needs its own visual comparison and must not be called certified parity
from an API test.

## Source evidence and baseline gates

Pinned source revision is `1ab921e62283e788a686bc4bafa1de5ff56104ea`.
`components/motion/text-shimmer.tsx` accepts ReactNode children and duration,
defaults duration to 2.5 seconds, and renders one inline-block element.
`components/agents/loading-states/thinking-shimmer.tsx` composes it with
font-medium, arbitrary children, and a 1.8-second default.

`lib/text-shimmer.ts` defines a linear infinite CSS animation and disables it
under prefers-reduced-motion. The current Flutter implementation holds a
centered highlight under reduced motion. Its exact static phase and source
background-position must be measured after acquisition, not assumed equal.
The additive constructor does not authorize a separate animation retune.

The accepted acquisition retains normal and reduced canonical endpoints,
original durations and strings, effective theme, viewport, served JavaScript
hashes, font limitations, and cadence limits. The source reduced highlight
differs visibly from the centered Flutter highlight. That drift is recorded,
but this child-only change must not retune it.

## Required verification

Compatibility checks exercise existing const string calls, public String text,
duration, style, textAlign, and color parameters through the public barrel.
Child checks exercise rich TextSpan content, composed text, inherited and
explicit styles, constraints, semantics, and an interactive child callback.
Lifecycle checks cover string-to-child and child-to-string updates, keyed child
replacement, duration changes, reduced-motion changes, and disposal during a
sweep. Shader samples compare both constructors at matched bounds and elapsed
times. They assert literal raster outcomes, not merely that a ShaderMask exists.

Root and Agents receive this contract before any implementation worker starts.
Source, before, and after comparisons, current-SDK tests, and native proof stay
separate gates. No code, capture, or parity result is claimed here.
