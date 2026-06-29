/// beUI — a one-to-one Flutter port of beUI v2 motion components.
///
/// Single public entrypoint: `import 'package:beui/beui.dart';`.
/// Components, theme, and motion tokens are re-exported here.
///
/// See `docs/PORTING_SPEC.md` for the catalog and conventions.
library;

export 'src/version.dart';

// Motion tokens (port first — everything depends on these).
export 'src/tokens/motion.dart';

// Default Lucide icon set (consumer-facing transitive dependency — see README).
export 'src/tokens/icons.dart';

// Theme (BeuiColors ThemeExtension + typography).
export 'src/theme/beui_colors.dart';
export 'src/theme/beui_text_theme.dart';

// Components (lib/src/motion/...). Exported as they are ported.
export 'src/motion/action_swap.dart'
    show
        BeuiActionSwapButton,
        BeuiActionSwapIcon,
        BeuiActionSwapItem,
        BeuiActionSwapText,
        BeuiActionSwapVariant;
export 'src/motion/animated_number.dart' show BeuiAnimatedNumber;
export 'src/motion/button/base.dart'
    show BeuiButton, BeuiButtonSize, BeuiButtonVariant;
export 'src/motion/button/magnetic.dart' show BeuiMagneticButton;
export 'src/motion/button/stateful.dart'
    show BeuiButtonState, BeuiStatefulButton;
export 'src/motion/checkbox.dart' show BeuiCheckbox, BeuiCheckboxStyle;
export 'src/motion/dock.dart' show BeuiDock, BeuiDockItem;
export 'src/motion/drawer.dart' show BeuiDrawer, BeuiDrawerSide;
export 'src/motion/magnetic.dart' show BeuiMagnetic;
export 'src/motion/marquee.dart' show BeuiMarquee, BeuiMarqueeDirection;
export 'src/motion/morphing_modal.dart'
    show BeuiModalPlacement, BeuiMorphingModal;
export 'src/motion/number_ticker.dart' show BeuiNumberTicker;

// Overlay foundation (tooltip, drawer, sheet, modal, command-palette, …).
export 'src/overlay/beui_overlay.dart' show BeuiOverlay, BeuiOverlayBuilder;
export 'src/motion/radio.dart' show BeuiRadioGroup, BeuiRadioItem;
export 'src/motion/shared_layout_bg.dart' show BeuiSharedLayoutBg;
export 'src/motion/switch.dart' show BeuiSwitch, BeuiSwitchStyle;
export 'src/motion/tabs.dart' show BeuiTab, BeuiTabs, BeuiTabsVariant;
export 'src/motion/text_cascade.dart' show BeuiTextCascade;
export 'src/motion/text_reveal.dart' show BeuiTextReveal, BeuiTextRevealSplit;
export 'src/motion/text_shimmer.dart' show BeuiTextShimmer;
export 'src/motion/tilt_card.dart' show BeuiTiltCard;
export 'src/motion/tooltip.dart' show BeuiTooltip, BeuiTooltipSide;
