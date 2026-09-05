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

// Theme (BeuiColors ThemeExtension + typography + agent semantics).
export 'src/theme/beui_agent_status_colors.dart';
export 'src/theme/beui_agent_strings.dart';
export 'src/theme/beui_agent_theme.dart';
export 'src/theme/beui_colors.dart';
export 'src/theme/beui_text_theme.dart';

// Components (lib/src/motion/...).
export 'src/motion/action_swap.dart'
    show
        BeuiActionSwapButton,
        BeuiActionSwapIcon,
        BeuiActionSwapItem,
        BeuiActionSwapText,
        BeuiActionSwapVariant;
export 'src/motion/animated_badge.dart'
    show BeuiAnimatedBadge, BeuiAnimatedBadgeSize, BeuiAnimatedBadgeStatus;
export 'src/motion/animated_number.dart' show BeuiAnimatedNumber;
export 'src/motion/animated_toast_stack.dart'
    show
        BeuiAnimatedToastStack,
        BeuiToast,
        BeuiToastAction,
        BeuiToastController,
        BeuiToastPosition,
        BeuiToastStatus;
export 'src/motion/availability_scheduler/availability_scheduler.dart'
    show
        BeuiAvailabilityScheduler,
        BeuiDayAvailability,
        BeuiDayKey,
        BeuiTimeRange,
        BeuiWeekAvailability,
        beuiDefaultWeek;
export 'src/motion/bloom_menu.dart'
    show BeuiBloomMenu, BeuiBloomMenuItem, beuiDefaultBloomMenuItems;
export 'src/motion/bottom_sheet.dart' show BeuiBottomSheet;
export 'src/motion/bouncy_accordion.dart'
    show BeuiBouncyAccordion, BeuiBouncyAccordionItem;
export 'src/motion/button/base.dart'
    show BeuiButton, BeuiButtonSize, BeuiButtonVariant;
export 'src/motion/button/magnetic.dart' show BeuiMagneticButton;
export 'src/motion/button/stateful.dart'
    show BeuiButtonState, BeuiStatefulButton;
export 'src/motion/checkbox.dart' show BeuiCheckbox, BeuiCheckboxStyle;
export 'src/motion/command_palette.dart'
    show BeuiCommandItem, BeuiCommandPalette;
export 'src/motion/cylinder_carousel.dart'
    show BeuiCylinderCarousel, BeuiCylinderCurve;
export 'src/motion/dock.dart' show BeuiDock, BeuiDockItem;
export 'src/motion/drawer.dart' show BeuiDrawer, BeuiDrawerSide;
export 'src/motion/dynamic_island.dart'
    show BeuiDynamicIsland, BeuiDynamicIslandView;
export 'src/motion/expandable_action_bar.dart'
    show
        BeuiExpandableActionBar,
        BeuiExpandableActionBarItem,
        BeuiExpandableActionBarSize;
export 'src/motion/expandable_tabs.dart'
    show BeuiExpandableTabs, BeuiExpandableTabsItem;
export 'src/motion/feedback_widget.dart'
    show
        BeuiFeedbackData,
        BeuiFeedbackPosition,
        BeuiFeedbackSentiment,
        BeuiFeedbackWidget,
        BeuiFeedbackWidgetStyle;
export 'src/motion/file_upload.dart'
    show
        BeuiFileUpload,
        BeuiFileUploadItem,
        BeuiFileUploadStatus,
        BeuiFileUploadVariant,
        beuiFormatBytes;
export 'src/motion/infinite_masonry.dart'
    show
        BeuiInfiniteMasonry,
        BeuiInfiniteMasonryKey,
        BeuiMasonryItemBuilder,
        BeuiMasonryKeyBuilder,
        BeuiMasonrySizeEstimator;
export 'src/motion/input.dart' show BeuiInput, BeuiInputStyle;
export 'src/motion/knockout_bracket.dart'
    show
        BeuiBracketRound,
        BeuiKnockoutBracket,
        BeuiMatch,
        BeuiMatchSide,
        BeuiMatchStatus,
        BeuiMatchWinner,
        BeuiTeam;
export 'src/motion/loader.dart' show BeuiLoader, BeuiLoaderVariant;
export 'src/motion/magnetic.dart' show BeuiMagnetic;
export 'src/motion/marquee.dart' show BeuiMarquee, BeuiMarqueeDirection;
export 'src/motion/morphing_modal.dart'
    show BeuiModalPlacement, BeuiMorphingModal;
export 'src/motion/not_found.dart'
    show
        BeuiNotFoundGlitch,
        BeuiNotFoundMagnetic,
        BeuiNotFoundSpotlight,
        BeuiNotFoundStacked,
        BeuiNotFoundTerminal;
export 'src/motion/notification_stack.dart'
    show BeuiNotificationStack, BeuiNotificationStackItem;
export 'src/motion/number_ticker.dart' show BeuiNumberTicker;
export 'src/motion/otp_input.dart' show BeuiOtpInput, BeuiOtpStatus;
export 'src/motion/overflow_actions.dart'
    show BeuiOverflowActionItem, BeuiOverflowActions, BeuiOverflowActionsSize;
export 'src/motion/prediction_market.dart'
    show
        BeuiPredictionMarket,
        BeuiPredictionMarketMode,
        BeuiPredictionMarketOrder,
        BeuiPredictionMarketOutcome,
        BeuiPredictionMarketQuote;

// Overlay foundation (tooltip, drawer, sheet, modal, command-palette, …).
export 'src/motion/parallax.dart' show BeuiParallax, BeuiParallaxAxis;
export 'src/motion/popover.dart'
    show BeuiPopover, BeuiPopoverAlign, BeuiPopoverSide, BeuiPopoverTrigger;
export 'src/motion/popover_morph.dart'
    show BeuiMorphPopover, BeuiMorphPopoverAlign, BeuiMorphPopoverSide;
export 'src/motion/preview_rail.dart'
    show
        BeuiPreviewRail,
        BeuiPreviewRailItem,
        BeuiPreviewRailOrientation,
        BeuiPreviewRailPreviewSide,
        BeuiPreviewRailStyle;
export 'src/motion/radio.dart' show BeuiRadioGroup, BeuiRadioItem;
export 'src/motion/range_slider.dart' show BeuiRangeSlider;
export 'src/motion/scroll_progress.dart' show BeuiScrollProgress;
export 'src/motion/scroll_reveal.dart' show BeuiScrollReveal;
export 'src/motion/scroll_to.dart' show BeuiScrollTo;
export 'src/motion/select.dart'
    show BeuiMorphSelect, BeuiSelect, BeuiSelectOption;
export 'src/motion/shader_background/shader_background.dart'
    show BeuiShaderBackground, BeuiShaderVariant;
export 'src/motion/shared_layout_bg.dart' show BeuiSharedLayoutBg;
export 'src/motion/smooth_scroll.dart'
    show
        BeuiSmoothScroll,
        BeuiSmoothScrollApi,
        BeuiSmoothScrollOrientation,
        beuiEaseScroll;
export 'src/motion/swap/swap.dart'
    show
        BeuiChain,
        BeuiChainTone,
        BeuiMultiChainSwap,
        BeuiToken,
        BeuiTokenSide,
        beuiDefaultSwapChains,
        beuiDefaultSwapTokens;
export 'src/motion/swipeable_list.dart'
    show
        BeuiSwipeAction,
        BeuiSwipeActionCallback,
        BeuiSwipeActionTone,
        BeuiSwipeSide,
        BeuiSwipeableList,
        BeuiSwipeableListItem,
        BeuiSwipeableListValue;
export 'src/motion/switch.dart' show BeuiSwitch, BeuiSwitchStyle;
export 'src/motion/table/table.dart'
    show
        BeuiSortDirection,
        BeuiSortState,
        BeuiTable,
        BeuiTableAlign,
        BeuiTableColumn,
        BeuiTableInsertPosition;
export 'src/motion/tabs.dart' show BeuiTab, BeuiTabs, BeuiTabsVariant;
export 'src/motion/text_cascade.dart' show BeuiTextCascade;
export 'src/motion/text_reveal.dart' show BeuiTextReveal, BeuiTextRevealSplit;
export 'src/motion/text_shimmer.dart' show BeuiTextShimmer;
export 'src/motion/theme_toggle.dart'
    show
        BeuiThemeRevealStart,
        BeuiThemeRevealVariant,
        BeuiThemeSwitcher,
        BeuiThemeSwitcherController,
        BeuiThemeToggle;
export 'src/motion/tilt_card.dart' show BeuiTiltCard;
export 'src/motion/tooltip.dart' show BeuiTooltip, BeuiTooltipSide;
export 'src/motion/wallet_card/wallet_card.dart'
    show BeuiWalletAccount, BeuiWalletCard;
export 'src/motion/wheel_picker.dart'
    show BeuiWheelPicker, BeuiWheelPickerOption, BeuiWheelPickerStyle;
export 'src/overlay/beui_overlay.dart' show BeuiOverlay, BeuiOverlayBuilder;

// Motion — expanding CTA suite (expanding / hold / slide).
export 'src/motion/expanding_arrow_button.dart'
    show
        BeuiExpandingArrowButton,
        BeuiHoldActionButton,
        BeuiHoldActionDirection,
        BeuiSlideActionButton;

// Motion — sidebars, context menu, and center-morph modal.
export 'src/motion/animated_sidebar.dart'
    show
        BeuiAnimatedSidebar,
        BeuiAnimatedSidebarCollapsible,
        BeuiAnimatedSidebarGroup,
        BeuiAnimatedSidebarItem,
        BeuiAnimatedSidebarScope,
        BeuiAnimatedSidebarSide,
        BeuiAnimatedSidebarTrigger,
        BeuiAnimatedSidebarVariant,
        beuiAnimatedSidebarActiveKey,
        beuiAnimatedSidebarChromeKey,
        beuiAnimatedSidebarInsetKey,
        beuiAnimatedSidebarMobilePanelKey,
        beuiAnimatedSidebarPanelKey,
        kBeuiAnimatedSidebarIconWidth,
        kBeuiAnimatedSidebarMobileBreakpoint,
        kBeuiAnimatedSidebarMobileWidth,
        kBeuiAnimatedSidebarWidth;
export 'src/motion/bounce_sidebar.dart'
    show
        BeuiBounceSidebar,
        BeuiBounceSidebarItem,
        beuiBounceSidebarIndicatorKey;
export 'src/motion/center_morph_modal.dart' show BeuiCenterMorphModal;
export 'src/motion/context_menu.dart'
    show
        BeuiContextMenu,
        BeuiContextMenuItem,
        BeuiContextMenuItemKind,
        BeuiContextMenuModality,
        BeuiContextMenuTone;
export 'src/motion/pull_to_refresh.dart'
    show BeuiPullToRefresh, BeuiPullToRefreshStatus;

// Agents — message primitives and conversation-surface components.
export 'src/motion/agent_activity.dart'
    show
        BeuiAgentActivity,
        BeuiAgentActivityContentType,
        BeuiAgentActivityItem,
        BeuiAgentActivitySearch,
        BeuiAgentActivityStatus,
        BeuiAgentActivityStep,
        BeuiAgentActivityText,
        BeuiAgentActivityTool,
        BeuiAgentActivityTrace,
        BeuiAgentSearchResult,
        BeuiAgentStepStatus,
        BeuiAgentTraceKind,
        beuiFormatAgentActivityDuration;
export 'src/motion/ai_sidebar.dart'
    show
        BeuiAiSidebar,
        BeuiSidebarResource,
        BeuiSidebarResourceDropPosition,
        BeuiSidebarResourceKind,
        BeuiSidebarResourceMenuControls,
        BeuiSidebarResourceMove,
        beuiAiSidebarKey,
        beuiAiSidebarRenameKey,
        beuiAiSidebarRowKey,
        beuiSidebarCanContain,
        beuiSidebarContains,
        beuiSidebarFind,
        beuiSidebarInsert,
        beuiSidebarMove,
        beuiSidebarRemove,
        beuiSidebarRename;
export 'src/motion/approval_card.dart'
    show
        BeuiApprovalCard,
        BeuiApprovalCardAnswer,
        BeuiApprovalCardAnswers,
        BeuiApprovalCardOption,
        BeuiApprovalCardQuestion,
        BeuiApprovalCardStatus;
export 'src/motion/attachment_upload.dart'
    show
        BeuiAttachmentKind,
        BeuiAttachmentRejectReason,
        BeuiAttachmentStatus,
        BeuiAttachmentUpload,
        BeuiAttachmentUploadController,
        BeuiAttachmentUploadItem;
export 'src/motion/chat_app.dart' show BeuiChatApp;
export 'src/motion/chromatic_text_reveal.dart' show BeuiChromaticTextReveal;
export 'src/motion/citations.dart'
    show
        BeuiCitation,
        BeuiCitationFavicon,
        BeuiCitationItem,
        BeuiCitationList,
        BeuiCitationStack,
        BeuiCitations,
        beuiFaviconUrl,
        citationTargetId;
export 'src/motion/code_block.dart'
    show BeuiCodeBlock, BeuiCodeBlockStatus, BeuiCodeLanguage;
export 'src/motion/file_diff.dart'
    show
        BeuiFileDiff,
        BeuiFileDiffHunkGap,
        BeuiFileDiffLine,
        BeuiFileDiffLineType,
        BeuiFileDiffStatus,
        BeuiFileDiffWrap;
export 'src/motion/image_generation.dart'
    show
        BeuiImageGeneration,
        BeuiImageGenerationSize,
        BeuiImageGenerationStatus;
export 'src/motion/knockout_wheel.dart' show BeuiKnockoutWheel;
export 'src/motion/loading_states.dart'
    show
        BeuiAgentProgress,
        BeuiReasoningText,
        BeuiReasoningTextVariant,
        BeuiThinkingShimmer,
        beuiFormatAgentElapsed;
export 'src/motion/message.dart'
    show
        BeuiMessage,
        BeuiMessageAvatar,
        BeuiMessageBubbleSide,
        BeuiMessageContent,
        BeuiMessageFooter,
        BeuiMessageFrom,
        BeuiMessageGroup,
        BeuiMessageHeader,
        BeuiMessageMarker,
        BeuiMessageScope,
        BeuiMessageSideScope,
        BeuiMessageSpacing,
        BeuiMessageTyping;
export 'src/motion/message_bubble.dart'
    show
        BeuiMessageBubble,
        BeuiMessageBubbleAlign,
        BeuiMessageBubbleCollapsible,
        BeuiMessageBubbleContent,
        BeuiMessageBubbleGroup,
        BeuiMessageBubbleSpacing,
        BeuiMessageBubbleVariant;
export 'src/motion/message_scroller.dart'
    show
        BeuiMessageScroller,
        BeuiMessageScrollerAnchor,
        BeuiMessageScrollerNavigation,
        BeuiMessageScrollerRailItem,
        BeuiMessageScrollerState;
export 'src/motion/prompt_input.dart'
    show
        BeuiPromptAction,
        BeuiPromptAttachment,
        BeuiPromptAttachmentStatus,
        BeuiPromptBlockedReason,
        BeuiPromptInput,
        BeuiPromptModel,
        BeuiPromptSubmission;
export 'src/motion/range_slider_bubble.dart' show BeuiBubbleSlider;
export 'src/motion/range_slider_fluid.dart' show BeuiFluidSlider;
export 'src/motion/range_slider_ruler.dart' show BeuiRulerSlider;
export 'src/motion/range_slider_wave.dart' show BeuiWaveSlider;
export 'src/motion/streaming_response.dart'
    show
        BeuiStreamingResponse,
        BeuiStreamingResponseFeedback,
        BeuiStreamingResponseStatus;
export 'src/motion/todo_list.dart'
    show BeuiTodoItem, BeuiTodoItemStatus, BeuiTodoList;
export 'src/motion/tool_approval.dart'
    show
        BeuiToolApproval,
        BeuiToolApprovalCode,
        BeuiToolApprovalGrant,
        BeuiToolApprovalParameter,
        BeuiToolApprovalSeverity,
        BeuiToolApprovalStatus;
export 'src/motion/tool_result.dart'
    show
        BeuiToolResult,
        BeuiToolResultKind,
        BeuiToolResultOutput,
        BeuiToolResultStatus;
