// The explorer catalog — the single source of truth for what the gallery shows.
//
// Mirrors the section/order of beui.dev's component explorer: Components
// ("motion"), AI Agents, and Blocks — each in the same order as the site's
// sidebar, wired to the Flutter demo builders.
import 'package:flutter/widgets.dart';

import '../demos/action_rails_demo.dart';
import '../demos/agent_activity_demo.dart';
import '../demos/agent_theme_demo.dart';
import '../demos/ai_sidebar_demo.dart';
import '../demos/animated_badge_demo.dart';
import '../demos/animated_sidebar_demo.dart';
import '../demos/animated_toast_stack_demo.dart';
import '../demos/approval_card_demo.dart';
import '../demos/availability_scheduler_demo.dart';
import '../demos/bloom_menu_demo.dart';
import '../demos/bounce_sidebar_demo.dart';
import '../demos/bottom_sheet_demo.dart';
import '../demos/bouncy_accordion_demo.dart';
import '../demos/center_morph_modal_demo.dart';
import '../demos/chat_app_demo.dart';
import '../demos/citations_demo.dart';
import '../demos/code_block_demo.dart';
import '../demos/command_palette_demo.dart';
import '../demos/context_menu_demo.dart';
import '../demos/core_demos.dart';
import '../demos/cylinder_carousel_demo.dart';
import '../demos/dynamic_island_demo.dart';
import '../demos/expandable_tabs_demo.dart';
import '../demos/expanding_arrow_button_demo.dart';
import '../demos/feedback_widget_demo.dart';
import '../demos/file_diff_demo.dart';
import '../demos/file_upload_demo.dart';
import '../demos/image_generation_demo.dart';
import '../demos/infinite_masonry_demo.dart';
import '../demos/input_demo.dart';
import '../demos/knockout_bracket_demo.dart';
import '../demos/loader_demo.dart';
import '../demos/loading_states_demo.dart';
import '../demos/message_bubble_demo.dart';
import '../demos/message_demo.dart';
import '../demos/message_scroller_demo.dart';
import '../demos/not_found_demo.dart';
import '../demos/notification_stack_demo.dart';
import '../demos/number_demo.dart';
import '../demos/otp_input_demo.dart';
import '../demos/popover_demo.dart';
import '../demos/popover_morph_demo.dart';
import '../demos/prediction_market_demo.dart';
import '../demos/preview_rail_demo.dart';
import '../demos/prompt_input_demo.dart';
import '../demos/pull_to_refresh_demo.dart';
import '../demos/range_slider_demo.dart';
import '../demos/scroll_animation_demo.dart';
import '../demos/select_demo.dart';
import '../demos/shader_background_demo.dart';
import '../demos/streaming_response_demo.dart';
import '../demos/swap_demo.dart';
import '../demos/swipeable_list_demo.dart';
import '../demos/table_demo.dart';
import '../demos/theme_toggle_demo.dart';
import '../demos/todo_list_demo.dart';
import '../demos/tool_approval_demo.dart';
import '../demos/tool_result_demo.dart';
import '../demos/wallet_card_demo.dart';
import '../demos/wheel_picker_demo.dart';

/// The three top-level groups in the explorer, mirroring the site's sidebar.
enum ExploreSection {
  components('Components', 'motion', 'Motion primitives with composable APIs.'),
  agents(
    'AI Agents',
    'agents',
    'Conversational and agent-reasoning interfaces.',
  ),
  blocks('Blocks', 'blocks', 'Composed, product-ready motion patterns.');

  const ExploreSection(this.title, this.slug, this.subtitle);

  /// Display title ("Components" / "AI Agents" / "Blocks").
  final String title;

  /// URL-ish slug used in breadcrumbs ("motion" / "agents" / "blocks").
  final String slug;

  /// One-line subtitle shown under the index heading.
  final String subtitle;
}

/// One catalog entry — a component or block, its metadata, and its live demo.
@immutable
class ExploreEntry {
  const ExploreEntry({
    required this.title,
    required this.slug,
    required this.section,
    required this.blurb,
    required this.builder,
    this.isNew = false,
    this.sourceFile,
  });

  /// Display title, e.g. "Switch".
  final String title;

  /// Slug matching the source route, e.g. "switch".
  final String slug;

  /// Which group this belongs to.
  final ExploreSection section;

  /// A short, one-line functional description (card body + detail subtitle).
  final String blurb;

  /// Whether to show the teal "NEW" badge, matching the source.
  final bool isNew;

  /// Builds the live demo.
  final WidgetBuilder builder;

  /// Overrides the demo file path shown on the Code tab, for entries whose
  /// demo lives in a shared file rather than `<slug>_demo.dart`.
  final String? sourceFile;
}

/// Composes the gooey Popover and its Morph variant onto one page, mirroring the
/// source's single "Popover" entry that documents both.
Widget _popoverCombined(BuildContext context) =>
    _StackedDemos(builders: const [popoverDemo, popoverMorphDemo]);

class _StackedDemos extends StatelessWidget {
  const _StackedDemos({required this.builders});
  final List<WidgetBuilder> builders;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < builders.length; i++) ...[
          if (i > 0) const SizedBox(height: 56),
          builders[i](context),
        ],
      ],
    );
  }
}

/// Components ("motion") — same order as the source sidebar (37 entries).
const List<ExploreEntry> kComponents = [
  ExploreEntry(
    title: 'Marquee',
    slug: 'marquee',
    section: ExploreSection.components,
    blurb: 'Infinite horizontal or vertical scroll with pause-on-hover.',
    builder: marqueeDemo,
  ),
  ExploreEntry(
    title: 'Tabs',
    slug: 'tabs',
    section: ExploreSection.components,
    blurb: 'Pill, segment or underline tabs with a spring layout indicator.',
    builder: tabsDemo,
  ),
  ExploreEntry(
    title: 'Switch',
    slug: 'switch',
    section: ExploreSection.components,
    blurb: 'Toggle with a spring-driven thumb and press feedback.',
    builder: switchDemo,
  ),
  ExploreEntry(
    title: 'Input',
    slug: 'input',
    section: ExploreSection.components,
    blurb:
        'Text field with icons, left-aligned announced errors and a success check.',
    builder: inputDemo,
  ),
  ExploreEntry(
    title: 'Select',
    slug: 'select',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Panel that bouncily unfolds from the trigger, plus a Morph variant.',
    builder: selectDemo,
  ),
  ExploreEntry(
    title: 'Checkbox',
    slug: 'checkbox',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Draw-on checkmark with spring press feedback and indeterminate.',
    builder: checkboxDemo,
  ),
  ExploreEntry(
    title: 'Radio Group',
    slug: 'radio',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Single-select with a gliding indicator dot and spring feedback.',
    builder: radioDemo,
  ),
  ExploreEntry(
    title: 'Bottom Sheet',
    slug: 'bottom-sheet',
    section: ExploreSection.components,
    blurb: 'Draggable sheet with snap points, inertia and a glass surface.',
    builder: bottomSheetDemo,
  ),
  ExploreEntry(
    title: 'Pull to Refresh',
    slug: 'pull-to-refresh',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Pull-to-refresh with drag resistance and async refresh handling.',
    builder: pullToRefreshDemo,
  ),
  ExploreEntry(
    title: 'Shared Layout Background',
    slug: 'shared-layout-bg',
    section: ExploreSection.components,
    blurb: 'A pill that glides between hovered items with a blur enter/exit.',
    builder: sharedLayoutDemo,
  ),
  ExploreEntry(
    title: 'Bounce Sidebar',
    slug: 'bounce-sidebar',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'A vertical sidebar whose active dot springs along a curved path.',
    builder: bounceSidebarDemo,
  ),
  ExploreEntry(
    title: 'Animated Sidebar',
    slug: 'animated-sidebar',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'App sidebar that folds to an icon rail on desktop, sheet on mobile.',
    builder: animatedSidebarDemo,
  ),
  ExploreEntry(
    title: 'Preview Rail',
    slug: 'preview-rail',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Navigation rail of ticks that preview a destination — hover or tap.',
    builder: previewRailDemo,
  ),
  ExploreEntry(
    title: 'Dock',
    slug: 'dock',
    section: ExploreSection.components,
    blurb: 'macOS-style dock with grouped actions and a gliding active pill.',
    builder: dockDemo,
  ),
  ExploreEntry(
    title: 'Tooltip',
    slug: 'tooltip',
    section: ExploreSection.components,
    blurb: 'Hover or focus tooltip with a blur enter/exit and spring spawn.',
    builder: tooltipDemo,
  ),
  ExploreEntry(
    title: 'Context Menu',
    slug: 'context-menu',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Context-menu primitives with a pointer-origin clip morph and typeahead.',
    builder: contextMenuDemo,
  ),
  ExploreEntry(
    title: 'Popover',
    slug: 'popover',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Gooey popover that oozes from the trigger, plus a Morph variant.',
    builder: _popoverCombined,
  ),
  ExploreEntry(
    title: 'Morphing Modal',
    slug: 'morphing-modal',
    section: ExploreSection.components,
    blurb:
        'A panel that morphs its height between inner views, blur cross-fade.',
    builder: morphingModalDemo,
  ),
  ExploreEntry(
    title: 'Center Morph Modal',
    slug: 'center-morph-modal',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'A full-size surface that unfolds from its exact center and folds back.',
    builder: centerMorphModalDemo,
  ),
  ExploreEntry(
    title: 'Text Animation',
    slug: 'text-animation',
    section: ExploreSection.components,
    blurb: 'Reveal sequences, shimmer loading states and letter-cascade swaps.',
    builder: textAnimationDemo,
  ),
  ExploreEntry(
    title: 'Number Animation',
    slug: 'number',
    section: ExploreSection.components,
    blurb: 'Count-up values and rolling digit tickers.',
    builder: numberDemo,
  ),
  ExploreEntry(
    title: 'Animated Badge',
    slug: 'animated-badge',
    section: ExploreSection.components,
    blurb: 'Status badge with animated state icons and pulse feedback.',
    builder: animatedBadgeDemo,
  ),
  ExploreEntry(
    title: 'Action Swap',
    slug: 'action-swap',
    section: ExploreSection.components,
    blurb: 'Swap a button\'s text and icons with blur, roll or cascade motion.',
    builder: actionSwapDemo,
  ),
  ExploreEntry(
    title: 'Animated Toast Stack',
    slug: 'animated-toast-stack',
    section: ExploreSection.components,
    blurb: 'Stacked toasts with status morphs, swipe dismissal and actions.',
    builder: animatedToastStackDemo,
  ),
  ExploreEntry(
    title: 'Theme Toggle',
    slug: 'theme-toggle',
    section: ExploreSection.components,
    blurb: 'Theme toggle with a full-page clip-path reveal.',
    builder: themeToggleDemo,
  ),
  ExploreEntry(
    title: 'Bouncy Accordion',
    slug: 'bouncy-accordion',
    section: ExploreSection.components,
    blurb: 'Single-open accordion with a weighted spring layout.',
    builder: bouncyAccordionDemo,
  ),
  ExploreEntry(
    title: 'Drawer',
    slug: 'drawer',
    section: ExploreSection.components,
    blurb: 'Side panel that springs in with a backdrop blur and esc-to-close.',
    builder: drawerDemo,
  ),
  ExploreEntry(
    title: 'Scroll Animation',
    slug: 'scroll-animation',
    section: ExploreSection.components,
    blurb: 'A smooth-scroll provider and a reading-progress indicator.',
    builder: scrollAnimationDemo,
  ),
  ExploreEntry(
    title: 'Range Slider',
    slug: 'range-slider',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Tick dots and a bouncy vertical-bar thumb that snaps between steps.',
    builder: rangeSliderDemo,
  ),
  ExploreEntry(
    title: 'Wheel Picker',
    slug: 'wheel-picker',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'iOS-style 3D picker drum with momentum snap; composes into pickers.',
    builder: wheelPickerDemo,
  ),
  ExploreEntry(
    title: 'Table',
    slug: 'table',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Virtualized table smooth at 10k+ rows: sort, select, resize, reorder.',
    builder: tableDemo,
  ),
  ExploreEntry(
    title: 'Shader Background',
    slug: 'shader-background',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Canvas shader backgrounds (mesh, grain, warp, waves, voronoi…).',
    builder: shaderBackgroundDemo,
  ),
  ExploreEntry(
    title: 'Cylinder Carousel',
    slug: 'cylinder-carousel',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Items line the inside of a cylinder; drag or scroll with springy snap.',
    builder: cylinderCarouselDemo,
  ),
  ExploreEntry(
    title: 'Loader',
    slug: 'loader',
    section: ExploreSection.components,
    isNew: true,
    blurb: 'Loading indicator with seventeen variants from one size prop.',
    builder: loaderDemo,
  ),
  ExploreEntry(
    title: 'Tilt Card',
    slug: 'tilt-card',
    section: ExploreSection.components,
    blurb: '3D perspective tilt on hover with a cursor-tracked glare.',
    builder: tiltCardDemo,
  ),
  ExploreEntry(
    title: 'Button',
    slug: 'button',
    section: ExploreSection.components,
    blurb: 'Spring-pressed Button, StatefulButton and MagneticButton.',
    builder: buttonDemo,
  ),
  ExploreEntry(
    title: 'Animated CTA Buttons',
    slug: 'expanding-arrow-button',
    section: ExploreSection.components,
    isNew: true,
    blurb:
        'Call-to-action buttons with expanding, hold and slide interactions.',
    builder: expandingArrowButtonDemo,
  ),
];

/// Blocks — same order as the source sidebar (18 entries).
const List<ExploreEntry> kBlocks = [
  ExploreEntry(
    title: 'Availability Scheduler',
    slug: 'availability-scheduler',
    section: ExploreSection.blocks,
    isNew: true,
    blurb: 'Weekly availability grid with per-day time ranges.',
    builder: availabilitySchedulerDemo,
  ),
  ExploreEntry(
    title: 'Multi-chain Swap',
    slug: 'swap',
    section: ExploreSection.blocks,
    blurb: 'Token swap card with chain switching and an animated quote.',
    builder: swapDemo,
  ),
  ExploreEntry(
    title: 'Dynamic Island',
    slug: 'dynamic-island',
    section: ExploreSection.blocks,
    blurb: 'iOS-style island that morphs between compact and expanded views.',
    builder: dynamicIslandDemo,
  ),
  ExploreEntry(
    title: 'Command Palette',
    slug: 'command-palette',
    section: ExploreSection.blocks,
    blurb: '⌘K palette with fuzzy search and spring-animated results.',
    builder: commandPaletteDemo,
  ),
  ExploreEntry(
    title: 'Expandable Action Bar',
    slug: 'expandable-action-bar',
    section: ExploreSection.blocks,
    blurb: 'Icon rail whose segments expand to reveal a label on hover.',
    builder: expandableActionBarDemo,
    sourceFile: 'example/lib/demos/action_rails_demo.dart',
  ),
  ExploreEntry(
    title: 'Overflow Actions',
    slug: 'overflow-actions',
    section: ExploreSection.blocks,
    blurb: 'Primary actions with an overflow that fans out from a ⋯ toggle.',
    builder: overflowActionsDemo,
    sourceFile: 'example/lib/demos/action_rails_demo.dart',
  ),
  ExploreEntry(
    title: 'Expandable Tabs',
    slug: 'expandable-tabs',
    section: ExploreSection.blocks,
    blurb: 'Icon tabs where the active tab expands to show its label.',
    builder: expandableTabsDemo,
  ),
  ExploreEntry(
    title: 'Swipeable List',
    slug: 'swipeable-list',
    section: ExploreSection.blocks,
    blurb: 'List rows with spring-backed swipe-to-reveal actions.',
    builder: swipeableListDemo,
  ),
  ExploreEntry(
    title: 'File Upload',
    slug: 'file-upload',
    section: ExploreSection.blocks,
    blurb:
        'Drop zone with real progress, cancel-in-flight and size-limit notices.',
    builder: fileUploadDemo,
  ),
  ExploreEntry(
    title: 'Attachment Upload',
    slug: 'attachment-upload',
    section: ExploreSection.blocks,
    blurb:
        'Mixed attachment workspace — image previews, seekable audio, retry.',
    builder: attachmentUploadDemo,
    sourceFile: 'example/lib/demos/file_upload_demo.dart',
  ),
  ExploreEntry(
    title: 'Prediction Market',
    slug: 'prediction-market',
    section: ExploreSection.blocks,
    blurb: 'Market card with a gliding outcome pill and animated odds.',
    builder: predictionMarketDemo,
  ),
  ExploreEntry(
    title: 'Wallet Card',
    slug: 'wallet-card',
    section: ExploreSection.blocks,
    isNew: true,
    blurb: 'Wallet card with an account switcher and morphing search.',
    builder: walletCardDemo,
  ),
  ExploreEntry(
    title: 'OTP Input',
    slug: 'otp-input',
    section: ExploreSection.blocks,
    blurb: 'One-time-code field with per-cell focus and a success check.',
    builder: otpInputDemo,
  ),
  ExploreEntry(
    title: 'Bloom Menu',
    slug: 'bloom-menu',
    section: ExploreSection.blocks,
    isNew: true,
    blurb: 'Radial action menu that blooms open from a floating trigger.',
    builder: bloomMenuDemo,
  ),
  ExploreEntry(
    title: 'Feedback Widget',
    slug: 'feedback-widget',
    section: ExploreSection.blocks,
    isNew: true,
    blurb:
        'Feedback popover that keeps drafts, validates inline and morphs to success.',
    builder: feedbackWidgetDemo,
  ),
  ExploreEntry(
    title: '404 / Not Found',
    slug: 'not-found',
    section: ExploreSection.blocks,
    blurb:
        'Five expressive 404 treatments: glitch, magnetic, spotlight and more.',
    builder: notFoundDemo,
  ),
  ExploreEntry(
    title: 'Infinite Masonry',
    slug: 'infinite-masonry',
    section: ExploreSection.blocks,
    isNew: true,
    blurb: 'Masonry grid that lazily appends tiles as you scroll.',
    builder: infiniteMasonryDemo,
  ),
  ExploreEntry(
    title: 'Notification Stack',
    slug: 'notification-stack',
    section: ExploreSection.blocks,
    isNew: true,
    blurb:
        'Collapsed notification stack that expands with layout-aware motion.',
    builder: notificationStackDemo,
  ),
  ExploreEntry(
    title: 'Knockout Bracket',
    slug: 'knockout-bracket',
    section: ExploreSection.blocks,
    isNew: true,
    blurb: 'Tournament bracket with connectors that animate as rounds fill.',
    builder: knockoutBracketDemo,
  ),
];

/// AI Agents — same order as the source sidebar (17 entries).
const List<ExploreEntry> kAgents = [
  ExploreEntry(
    title: 'Message Bubble',
    slug: 'message-bubble',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Conversational surface with tones, alignment and grouped messages.',
    builder: messageBubbleDemo,
  ),
  ExploreEntry(
    title: 'Message',
    slug: 'message',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Primitives for rows, grouped bubbles, avatars and live markers.',
    builder: messageDemo,
  ),
  ExploreEntry(
    title: 'Message Scroller',
    slug: 'message-scroller',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Conversation viewport that follows the live edge and jumps back with an unread count.',
    builder: messageScrollerDemo,
  ),
  ExploreEntry(
    title: 'Prompt Input',
    slug: 'prompt-input',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Auto-growing composer with attachment chips, a keyboarded model picker and send/stop.',
    builder: promptInputDemo,
  ),
  ExploreEntry(
    title: 'Todo List',
    slug: 'todo-list',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Collapsible task plan with morphing status marks and a count.',
    builder: todoListDemo,
  ),
  ExploreEntry(
    title: 'Code Block',
    slug: 'code-block',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Syntax-highlighted code with stable streaming and line numbers.',
    builder: codeBlockDemo,
  ),
  ExploreEntry(
    title: 'Approval Card',
    slug: 'approval-card',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Decision surface for approvals and single or multi-choice questions.',
    builder: approvalCardDemo,
  ),
  ExploreEntry(
    title: 'File Diff',
    slug: 'file-diff',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Change disclosure with wrap or scroll, hunk-gap markers and live counts.',
    builder: fileDiffDemo,
  ),
  ExploreEntry(
    title: 'Tool Result',
    slug: 'tool-result',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Execution disclosure for terminal output that collapses when done.',
    builder: toolResultDemo,
  ),
  ExploreEntry(
    title: 'Streaming Response',
    slug: 'streaming-response',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Response surface with a visible failed state and a stopped/continue path.',
    builder: streamingResponseDemo,
  ),
  ExploreEntry(
    title: 'Image Generation',
    slug: 'image-generation',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Generated-image surface with determinate progress, cancel and no layout shift.',
    builder: imageGenerationDemo,
  ),
  ExploreEntry(
    title: 'Tool Approval',
    slug: 'tool-approval',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Permission card: allow once, remember access, or deny — with a destructive tier.',
    builder: toolApprovalDemo,
  ),
  ExploreEntry(
    title: 'Citations',
    slug: 'citations',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Inline markers paired with a collapsible reference collection.',
    builder: citationsDemo,
  ),
  ExploreEntry(
    title: 'Agent Activity',
    slug: 'agent-activity',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'A single stream for reasoning, searches, tool calls — including failed and cancelled runs.',
    builder: agentActivityDemo,
  ),
  ExploreEntry(
    title: 'Loading States',
    slug: 'loading-states',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Shimmering reasoning text, progress and cycling phrases.',
    builder: loadingStatesDemo,
  ),
  ExploreEntry(
    title: 'AI Sidebar',
    slug: 'ai-sidebar',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Collapsible AI workspace sidebar with keyboard navigation.',
    builder: aiSidebarDemo,
  ),
  ExploreEntry(
    title: 'Chat App',
    slug: 'chat-app',
    section: ExploreSection.agents,
    isNew: true,
    blurb:
        'Complete agent workspace composing the conversation surfaces, with a responsive sidebar.',
    builder: chatAppDemo,
  ),
  ExploreEntry(
    title: 'Agent Theme',
    slug: 'agent-theme',
    section: ExploreSection.agents,
    isNew: true,
    blurb: 'Install BeuiAgentTheme once and restyle the real agent widgets.',
    builder: agentThemeDemo,
  ),
];

/// All entries across every section, in display order.
const List<ExploreEntry> kAllEntries = [...kComponents, ...kAgents, ...kBlocks];

/// The entries for [section].
List<ExploreEntry> entriesFor(ExploreSection section) => switch (section) {
  ExploreSection.components => kComponents,
  ExploreSection.agents => kAgents,
  ExploreSection.blocks => kBlocks,
};
