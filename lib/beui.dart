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
export 'src/motion/checkbox.dart' show BeuiCheckbox, BeuiCheckboxStyle;
export 'src/motion/radio.dart' show BeuiRadioGroup, BeuiRadioItem;
export 'src/motion/switch.dart' show BeuiSwitch, BeuiSwitchStyle;
export 'src/motion/tabs.dart' show BeuiTab, BeuiTabs, BeuiTabsVariant;
