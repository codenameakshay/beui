import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiChatApp] — a full agent workspace composing nav,
/// messages, streaming, planning, approvals, tools, code, diffs, media,
/// sources, and prompt input (source `chat-app-usage`).
Widget chatAppDemo(BuildContext context) => const _ChatAppDemo();

// ---------------------------------------------------------------------------
// Sample data (mirrors source chat-app-usage)
// ---------------------------------------------------------------------------

const _reply =
    "I'll keep the patch focused, preserve the current checkout layout, "
    'and run the same validation path before preparing the release.';

const _diffLines = <BeuiFileDiffLine>[
  BeuiFileDiffLine(
    id: 'context-1',
    type: BeuiFileDiffLineType.context,
    oldLine: 41,
    newLine: 41,
    content: '  const total = subtotal + shipping;',
  ),
  BeuiFileDiffLine(
    id: 'removed-1',
    type: BeuiFileDiffLineType.removed,
    oldLine: 42,
    content: '  return submitOrder(total);',
  ),
  BeuiFileDiffLine(
    id: 'added-1',
    type: BeuiFileDiffLineType.added,
    newLine: 42,
    content: '  const result = validateOrder({ total, items });',
  ),
  BeuiFileDiffLine(
    id: 'added-2',
    type: BeuiFileDiffLineType.added,
    newLine: 43,
    content: '  return result.ok ? submitOrder(total) : result;',
  ),
];

const _approvalQuestions = <BeuiApprovalCardQuestion>[
  BeuiApprovalCardQuestion(
    id: 'release',
    title: 'How should the patch be released?',
    options: [
      BeuiApprovalCardOption(
        value: 'focused',
        label: 'Ship the focused checkout fix',
      ),
      BeuiApprovalCardOption(
        value: 'bundle',
        label: 'Bundle it with the next release',
      ),
    ],
    allowCustom: true,
    customPlaceholder: 'Add another release instruction…',
  ),
];

const _resources = <BeuiSidebarResource>[
  BeuiSidebarResource(
    id: 'release',
    label: 'Release workspace',
    kind: BeuiSidebarResourceKind.project,
    children: [
      BeuiSidebarResource(
        id: 'checkout',
        label: 'Checkout audit',
        kind: BeuiSidebarResourceKind.file,
      ),
      BeuiSidebarResource(
        id: 'release-notes',
        label: 'Release notes',
        kind: BeuiSidebarResourceKind.file,
      ),
      BeuiSidebarResource(
        id: 'references',
        label: 'Research sources',
        kind: BeuiSidebarResourceKind.bookmark,
      ),
    ],
  ),
  BeuiSidebarResource(
    id: 'design',
    label: 'Design system',
    kind: BeuiSidebarResourceKind.folder,
    children: [
      BeuiSidebarResource(
        id: 'tokens',
        label: 'Motion tokens',
        kind: BeuiSidebarResourceKind.file,
      ),
      BeuiSidebarResource(
        id: 'components',
        label: 'Component inventory',
        kind: BeuiSidebarResourceKind.file,
      ),
    ],
  ),
  BeuiSidebarResource(
    id: 'archive',
    label: 'Archived runs',
    kind: BeuiSidebarResourceKind.folder,
  ),
];

const _models = <BeuiPromptModel>[
  BeuiPromptModel(value: 'balanced', label: 'Balanced'),
  BeuiPromptModel(value: 'fast', label: 'Fast'),
  BeuiPromptModel(value: 'deep', label: 'Deep reasoning'),
];

const _actions = <BeuiPromptAction>[
  BeuiPromptAction(
    value: 'attach',
    label: 'Attach file',
    icon: Icon(LucideIcons.paperclip),
  ),
  BeuiPromptAction(
    value: 'project',
    label: 'Add project context',
    icon: Icon(LucideIcons.folder_kanban),
  ),
  BeuiPromptAction(
    value: 'skill',
    label: 'Use a skill',
    icon: Icon(LucideIcons.wand_sparkles),
  ),
];

// ---------------------------------------------------------------------------
// Demo
// ---------------------------------------------------------------------------

class _ChatAppDemo extends StatefulWidget {
  const _ChatAppDemo();

  @override
  State<_ChatAppDemo> createState() => _ChatAppDemoState();
}

class _AddedMessage {
  _AddedMessage({
    required this.id,
    required this.from,
    required this.content,
    this.streaming = false,
  });

  final String id;
  final BeuiMessageFrom from;
  String content;
  bool streaming;

  /// Whether generation was stopped before this reply finished:
  /// renders as [BeuiStreamingResponseStatus.stopped] with a real Continue
  /// affordance instead of silently presenting a truncated answer as done.
  bool stopped = false;
}

/// The three sidebar nav actions (source `New task` / `Search` / `Runs`).
enum _SidebarNav { newTask, search, runs }

class _ChatAppDemoState extends State<_ChatAppDemo> {
  final List<Timer> _toolTimers = [];
  final List<Timer> _chatTimers = [];
  final List<Timer> _approvalTimers = [];
  Timer? _streamTimer;

  int _runId = 0;
  List<BeuiSidebarResource> _items = List.of(_resources);
  String _activeResource = 'checkout';
  bool _sidebarVisible = true;
  _SidebarNav? _activeNav;

  bool _pending = false;
  String? _activeReplyId;
  final List<_AddedMessage> _messages = [];

  /// "Attach file" was an action the composer offered and then swallowed.
  /// The demo now owns real attachment state so the chip row, its upload
  /// progress, removal and retry are all reachable from the gallery.
  List<BeuiPromptAttachment> _attachments = const [];
  final List<Timer> _uploadTimers = [];
  int _attachmentSeq = 0;

  BeuiToolApprovalStatus _toolStatus = BeuiToolApprovalStatus.pending;
  BeuiApprovalCardStatus _approvalStatus = BeuiApprovalCardStatus.pending;

  bool get _busy => _pending || _activeReplyId != null;

  @override
  void dispose() {
    _clearToolTimers();
    _clearChatTimers();
    _clearApprovalTimers();
    _clearUploadTimers();
    _streamTimer?.cancel();
    super.dispose();
  }

  void _clearUploadTimers() {
    for (final t in _uploadTimers) {
      t.cancel();
    }
    _uploadTimers.clear();
  }

  void _clearToolTimers() {
    for (final t in _toolTimers) {
      t.cancel();
    }
    _toolTimers.clear();
  }

  void _clearChatTimers() {
    for (final t in _chatTimers) {
      t.cancel();
    }
    _chatTimers.clear();
  }

  void _clearApprovalTimers() {
    for (final t in _approvalTimers) {
      t.cancel();
    }
    _approvalTimers.clear();
  }

  List<BeuiTodoItem> get _plan {
    final checksStatus = switch (_toolStatus) {
      BeuiToolApprovalStatus.complete => BeuiTodoItemStatus.completed,
      BeuiToolApprovalStatus.running => BeuiTodoItemStatus.inProgress,
      BeuiToolApprovalStatus.denied ||
      BeuiToolApprovalStatus.error => BeuiTodoItemStatus.cancelled,
      _ => BeuiTodoItemStatus.pending,
    };
    return [
      const BeuiTodoItem(
        id: 'inspect',
        title: Text('Inspect the checkout flow'),
        status: BeuiTodoItemStatus.completed,
      ),
      const BeuiTodoItem(
        id: 'patch',
        title: Text('Prepare the validation patch'),
        status: BeuiTodoItemStatus.completed,
      ),
      BeuiTodoItem(
        id: 'checks',
        title: const Text('Run focused checks'),
        status: checksStatus,
      ),
      BeuiTodoItem(
        id: 'review',
        title: const Text('Collect release approval'),
        status: _toolStatus == BeuiToolApprovalStatus.complete
            ? BeuiTodoItemStatus.inProgress
            : BeuiTodoItemStatus.pending,
      ),
    ];
  }

  void _approveTool() {
    _clearToolTimers();
    setState(() => _toolStatus = BeuiToolApprovalStatus.approving);
    _toolTimers.addAll([
      Timer(const Duration(milliseconds: 450), () {
        if (mounted) {
          setState(() => _toolStatus = BeuiToolApprovalStatus.approved);
        }
      }),
      Timer(const Duration(milliseconds: 850), () {
        if (mounted) {
          setState(() => _toolStatus = BeuiToolApprovalStatus.running);
        }
      }),
      Timer(const Duration(milliseconds: 1650), () {
        if (mounted) {
          setState(() => _toolStatus = BeuiToolApprovalStatus.complete);
        }
      }),
    ]);
  }

  /// Starts (or, with [startCursor], resumes) streaming [_reply] into the
  /// assistant message identified by [assistantId].
  void _startStream(String assistantId, {int startCursor = 0}) {
    _streamTimer?.cancel();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      setState(() {
        for (final m in _messages) {
          if (m.id == assistantId) {
            m.content = _reply;
            m.streaming = false;
            m.stopped = false;
          }
        }
        _activeReplyId = null;
      });
      return;
    }

    final startedAt = DateTime.now();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      final cursor = (startCursor + elapsed / 1000 * 92).floor().clamp(
        0,
        _reply.length,
      );
      final content = _reply.substring(0, cursor);
      setState(() {
        for (final m in _messages) {
          if (m.id == assistantId && m.content != content) {
            m.content = content;
          }
        }
      });
      if (cursor >= _reply.length) {
        timer.cancel();
        setState(() {
          for (final m in _messages) {
            if (m.id == assistantId) {
              m.streaming = false;
              m.stopped = false;
            }
          }
          _activeReplyId = null;
        });
      }
    });
  }

  void _submit(String value, String? model) {
    if (value.trim().isEmpty || _busy) return;
    final id = _runId++;
    final assistantId = 'assistant-$id';
    final reduce = MediaQuery.disableAnimationsOf(context);

    setState(() {
      _messages.add(
        _AddedMessage(
          id: 'user-$id',
          from: BeuiMessageFrom.user,
          content: value,
        ),
      );
      // The assistant turn is created *now*, empty and streaming, rather
      // than after the think delay. Its typing indicator is the streaming
      // response's own `placeholder`, so it cross-fades into the first token
      // instead of a separate shimmer row unmounting and a blank bubble
      // taking its place — the pattern agents_chat_preview already uses.
      _messages.add(
        _AddedMessage(
          id: assistantId,
          from: BeuiMessageFrom.assistant,
          content: '',
          streaming: true,
        ),
      );
      _pending = true;
    });

    _chatTimers.add(
      Timer(Duration(milliseconds: reduce ? 0 : 420), () {
        if (!mounted) return;
        setState(() {
          _pending = false;
          _activeReplyId = assistantId;
        });
        _startStream(assistantId);
      }),
    );
  }

  /// Demo file names, cycled so repeated taps produce distinct chips. The
  /// `.csv` is the one that always fails, so the retry path is reachable in
  /// the gallery rather than theoretical.
  static const _attachmentNames = <String>[
    'checkout-flow.png',
    'pricing-notes.md',
    'legacy-export.csv',
  ];

  void _handlePromptAction(String action) {
    if (action != 'attach') return;
    final name = _attachmentNames[_attachmentSeq % _attachmentNames.length];
    final id = 'file-${_attachmentSeq++}';
    setState(() {
      _attachments = [
        ..._attachments,
        BeuiPromptAttachment(
          id: id,
          name: name,
          status: BeuiPromptAttachmentStatus.uploading,
          progress: 0,
        ),
      ];
    });
    _runUpload(id, shouldFail: name.endsWith('.csv'));
  }

  /// Walks one chip from 0 to done over ~900ms, then settles it on `ready`, or
  /// on `failed` with a note when [shouldFail]. A retry always succeeds, so
  /// the failure is a state the reader can get into *and* out of.
  void _runUpload(String id, {bool shouldFail = false}) {
    final startedAt = DateTime.now();
    late Timer timer;
    timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final progress =
          (DateTime.now().difference(startedAt).inMilliseconds / 900).clamp(
            0.0,
            1.0,
          );
      final done = progress >= 1;
      if (done) t.cancel();
      setState(() {
        _attachments = [
          for (final a in _attachments)
            if (a.id != id)
              a
            else if (!done)
              BeuiPromptAttachment(
                id: a.id,
                name: a.name,
                status: BeuiPromptAttachmentStatus.uploading,
                progress: progress,
              )
            else if (shouldFail)
              BeuiPromptAttachment(
                id: a.id,
                name: a.name,
                status: BeuiPromptAttachmentStatus.failed,
                error: 'Upload failed — the file is larger than 10 MB.',
              )
            else
              BeuiPromptAttachment(id: a.id, name: a.name),
        ];
      });
    });
    _uploadTimers.add(timer);
  }

  void _stop() {
    _clearChatTimers();
    _streamTimer?.cancel();
    setState(() {
      _pending = false;
      for (final m in _messages) {
        if (m.streaming) {
          m.streaming = false;
          m.stopped = true;
        }
      }
      _activeReplyId = null;
    });
  }

  /// Resumes a [_AddedMessage.stopped] reply (the Continue control on a
  /// [BeuiStreamingResponseStatus.stopped] notice).
  void _continueStream(String assistantId) {
    final index = _messages.indexWhere((m) => m.id == assistantId);
    if (index == -1) return;
    final startCursor = _messages[index].content.length;
    setState(() {
      _messages[index].streaming = true;
      _messages[index].stopped = false;
      _activeReplyId = assistantId;
    });
    _startStream(assistantId, startCursor: startCursor);
  }

  /// Resets the transcript to a fresh task (the "New task" nav button).
  void _resetConversation() {
    _clearToolTimers();
    _clearChatTimers();
    _clearApprovalTimers();
    _streamTimer?.cancel();
    _streamTimer = null;
    _messages.clear();
    _pending = false;
    _activeReplyId = null;
    _toolStatus = BeuiToolApprovalStatus.pending;
    _approvalStatus = BeuiApprovalCardStatus.pending;
  }

  /// Handles the three sidebar nav buttons — each selects a distinct,
  /// visibly different state the demo already holds rather than a no-op.
  void _selectNav(_SidebarNav nav) {
    setState(() {
      _activeNav = nav;
      switch (nav) {
        case _SidebarNav.newTask:
          _resetConversation();
        case _SidebarNav.search:
          _activeResource = 'references';
        case _SidebarNav.runs:
          _activeResource = 'archive';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SizedBox(
            height: 760,
            child: BeuiChatApp(
              sidebar: _sidebarVisible ? _buildSidebar(colors) : null,
              header: _buildHeader(colors),
              body: _buildBody(),
              prompt: _buildPrompt(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BeuiColors colors) {
    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Column(
              children: [
                for (final entry in [
                  (
                    LucideIcons.message_square_plus,
                    'New task',
                    _SidebarNav.newTask,
                  ),
                  (LucideIcons.search, 'Search', _SidebarNav.search),
                  (LucideIcons.clock_3, 'Runs', _SidebarNav.runs),
                ])
                  _SidebarNavButton(
                    icon: entry.$1,
                    label: entry.$2,
                    colors: colors,
                    active: _activeNav == entry.$3,
                    onTap: () => _selectNav(entry.$3),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Projects',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: BeuiAiSidebar(
                    items: _items,
                    activeId: _activeResource,
                    defaultExpandedIds: const ['release', 'design'],
                    onActiveChange: (id) =>
                        setState(() => _activeResource = id),
                    onItemsChange: (items) => setState(() => _items = items),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 32,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.background.withValues(alpha: 0),
                            colors.background,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BeuiColors colors) {
    final working =
        _busy ||
        _toolStatus == BeuiToolApprovalStatus.approving ||
        _toolStatus == BeuiToolApprovalStatus.running;
    final statusColors = BeuiAgentTheme.of(
      context,
    ).statusColorsFor(Theme.of(context).brightness);
    final statusPalette = working ? statusColors.running : statusColors.success;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              tooltip: _sidebarVisible ? 'Hide sidebar' : 'Show sidebar',
              onPressed: () =>
                  setState(() => _sidebarVisible = !_sidebarVisible),
              icon: Icon(
                LucideIcons.panel_left,
                size: 16,
                color: colors.mutedForeground,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                maximumSize: const Size(40, 40),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checkout release',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                  Text(
                    'Agent workspace · focused patch',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: statusPalette.background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusPalette.solid,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      working ? 'Working' : 'Connected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return BeuiMessageScroller(
      busy: _busy,
      navigation: BeuiMessageScrollerNavigation.rail,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: BeuiMessageGroup(
            spacing: BeuiMessageSpacing.standard,
            children: [
              // User prompt
              BeuiMessage(
                from: BeuiMessageFrom.user,
                children: [
                  const BeuiMessageAvatar(child: Icon(LucideIcons.user)),
                  BeuiMessageContent(
                    children: [
                      const BeuiMessageHeader(
                        children: [Text('You'), Text('10:24')],
                      ),
                      BeuiMessageBubble(
                        variant: BeuiMessageBubbleVariant.solid,
                        child: BeuiMessageBubbleContent(
                          child: const Text(
                            'Audit the checkout flow, fix the validation gap, '
                            'and prepare a release-ready patch.',
                            style: TextStyle(fontSize: 14, height: 1.45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Activity + plan
              BeuiMessage(
                from: BeuiMessageFrom.assistant,
                children: [
                  const BeuiMessageAvatar(child: Icon(LucideIcons.bot)),
                  BeuiMessageContent(
                    children: [
                      const BeuiMessageHeader(
                        children: [Text('beUI Agent'), Text('10:24')],
                      ),
                      BeuiAgentActivity(
                        status: BeuiAgentActivityStatus.complete,
                        duration: 6,
                        defaultOpen: true,
                        collapseOnComplete: false,
                        items: const [
                          BeuiAgentActivityText(
                            id: 'reason',
                            content:
                                'Tracing the checkout submission path and validation boundary.',
                          ),
                          BeuiAgentActivityTool(
                            id: 'read',
                            action: 'read',
                            target: 'checkout/submit.ts',
                          ),
                          BeuiAgentActivitySearch(
                            id: 'search',
                            query: 'order validation failures',
                            results: [
                              BeuiAgentSearchResult(
                                id: 'result-1',
                                title: 'Validation contract',
                                domain: 'docs.beui.dev',
                                url: '/docs/validation',
                              ),
                            ],
                          ),
                        ],
                      ),
                      BeuiTodoList(
                        items: _plan,
                        title: const Text('Release plan'),
                        collapseOnComplete: false,
                      ),
                    ],
                  ),
                ],
              ),

              // Tool approval
              BeuiMessage(
                from: BeuiMessageFrom.assistant,
                children: [
                  const BeuiMessageAvatar(placeholder: true),
                  BeuiMessageContent(
                    children: [
                      BeuiToolApproval(
                        tool: 'terminal.run',
                        title: 'Run focused checkout checks?',
                        description:
                            'The agent needs permission to run the validation '
                            'and accessibility suites.',
                        status: _toolStatus,
                        defaultOpen: true,
                        parameters: const [
                          BeuiToolApprovalParameter(
                            id: 'command',
                            label: 'Command',
                            value: BeuiToolApprovalCode(
                              code: 'bun test checkout --coverage',
                              language: BeuiCodeLanguage.bash,
                            ),
                          ),
                          BeuiToolApprovalParameter(
                            id: 'scope',
                            label: 'Scope',
                            value: 'Current workspace',
                          ),
                        ],
                        onApprove: _approveTool,
                        onAlwaysAllow: _approveTool,
                        onDeny: () {
                          _clearToolTimers();
                          setState(
                            () => _toolStatus = BeuiToolApprovalStatus.denied,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              // Tool result + diff + code (when running/complete)
              if (_toolStatus == BeuiToolApprovalStatus.running ||
                  _toolStatus == BeuiToolApprovalStatus.complete)
                BeuiMessage(
                  from: BeuiMessageFrom.assistant,
                  children: [
                    const BeuiMessageAvatar(placeholder: true),
                    BeuiMessageContent(
                      children: [
                        BeuiToolResult(
                          tool: 'terminal.run',
                          title: _toolStatus == BeuiToolApprovalStatus.running
                              ? 'Running checkout checks'
                              : 'Checkout checks passed',
                          status: _toolStatus == BeuiToolApprovalStatus.running
                              ? BeuiToolResultStatus.running
                              : BeuiToolResultStatus.success,
                          kind: BeuiToolResultKind.terminal,
                          meta: _toolStatus == BeuiToolApprovalStatus.running
                              ? 'Live'
                              : '2.8s',
                          defaultOpen: true,
                          collapseOnComplete: false,
                          child: BeuiToolResultOutput(
                            code: _toolStatus == BeuiToolApprovalStatus.running
                                ? '✓ validation contract\n… checkout keyboard flow'
                                : '✓ validation contract\n'
                                      '✓ checkout keyboard flow\n'
                                      '✓ order submission recovery',
                          ),
                        ),
                        if (_toolStatus == BeuiToolApprovalStatus.complete) ...[
                          const BeuiFileDiff(
                            file: 'checkout/submit.ts',
                            lines: _diffLines,
                            status: BeuiFileDiffStatus.complete,
                            defaultOpen: true,
                            collapseOnComplete: false,
                          ),
                          const BeuiCodeBlock(
                            filename: 'validation.ts',
                            language: BeuiCodeLanguage.typescript,
                            status: BeuiCodeBlockStatus.complete,
                            code:
                                'export function validateOrder(order: Order) {\n'
                                '  return schema.safeParse(order);\n'
                                '}',
                            showLineNumbers: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                )
              else if (_toolStatus == BeuiToolApprovalStatus.denied ||
                  _toolStatus == BeuiToolApprovalStatus.error)
                BeuiMessage(
                  from: BeuiMessageFrom.assistant,
                  children: [
                    const BeuiMessageAvatar(placeholder: true),
                    BeuiMessageContent(
                      children: [
                        BeuiToolResult(
                          tool: 'terminal.run',
                          title: 'Checkout checks were not run',
                          status: _toolStatus == BeuiToolApprovalStatus.denied
                              ? BeuiToolResultStatus.cancelled
                              : BeuiToolResultStatus.error,
                          kind: BeuiToolResultKind.terminal,
                          defaultOpen: true,
                          collapseOnComplete: false,
                          child: BeuiToolResultOutput(
                            code: _toolStatus == BeuiToolApprovalStatus.denied
                                ? 'Permission was not granted. No command was run.'
                                : 'The command could not be completed.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Image + streaming summary + sources
              if (_toolStatus == BeuiToolApprovalStatus.complete)
                BeuiMessage(
                  from: BeuiMessageFrom.assistant,
                  children: [
                    const BeuiMessageAvatar(placeholder: true),
                    BeuiMessageContent(
                      children: [
                        BeuiImageGeneration(
                          status: BeuiImageGenerationStatus.complete,
                          prompt: 'a clear checkout confirmation screen',
                          resolution: '1280 × 840',
                          size: BeuiImageGenerationSize.compact,
                          child: const _GeneratedPreview(),
                        ),
                        BeuiMessageBubble(
                          variant: BeuiMessageBubbleVariant.ghost,
                          child: BeuiMessageBubbleContent(
                            maxWidthFactor: 1,
                            child: BeuiStreamingResponse(
                              status: BeuiStreamingResponseStatus.complete,
                              copyText:
                                  'The checkout patch is ready for review.',
                              sources: const [
                                BeuiCitationItem(
                                  id: 'message',
                                  title: Text('Message composition'),
                                  domain: Text('beui.dev'),
                                  url: '/components/agents/message',
                                ),
                                BeuiCitationItem(
                                  id: 'diff',
                                  title: Text('File Diff'),
                                  domain: Text('beui.dev'),
                                  url: '/components/agents/file-diff',
                                ),
                                BeuiCitationItem(
                                  id: 'approval',
                                  title: Text('Tool Approval'),
                                  domain: Text('beui.dev'),
                                  url: '/components/agents/tool-approval',
                                ),
                              ],
                              child: DefaultTextStyle.merge(
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: Theme.of(
                                    context,
                                  ).extension<BeuiColors>()!.foreground,
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'The checkout patch is ready for review.',
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      '• Validation now runs before submission.',
                                    ),
                                    Text(
                                      '• Failure output stays inside the current flow.',
                                    ),
                                    Text(
                                      '• Focused checks pass without changing the layout.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Release approval
              if (_toolStatus == BeuiToolApprovalStatus.complete)
                BeuiMessage(
                  from: BeuiMessageFrom.assistant,
                  children: [
                    const BeuiMessageAvatar(placeholder: true),
                    BeuiMessageContent(
                      children: [
                        BeuiApprovalCard(
                          questions: _approvalQuestions,
                          status: _approvalStatus,
                          onSubmit: (_) {
                            setState(
                              () => _approvalStatus =
                                  BeuiApprovalCardStatus.submitting,
                            );
                            _clearApprovalTimers();
                            _approvalTimers.add(
                              Timer(const Duration(milliseconds: 650), () {
                                if (mounted) {
                                  setState(
                                    () => _approvalStatus =
                                        BeuiApprovalCardStatus.answered,
                                  );
                                }
                              }),
                            );
                          },
                          result: const Text(
                            'Release direction sent to the agent.',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

              // Live chat turns
              for (final message in _messages)
                BeuiMessage(
                  key: ValueKey(message.id),
                  from: message.from,
                  children: [
                    BeuiMessageAvatar(
                      child: Icon(
                        message.from == BeuiMessageFrom.assistant
                            ? LucideIcons.bot
                            : LucideIcons.user,
                      ),
                    ),
                    BeuiMessageContent(
                      children: [
                        if (message.from == BeuiMessageFrom.assistant)
                          const BeuiMessageHeader(
                            children: [Text('beUI Agent'), Text('Now')],
                          ),
                        BeuiMessageBubble(
                          variant: message.from == BeuiMessageFrom.user
                              ? BeuiMessageBubbleVariant.solid
                              : BeuiMessageBubbleVariant.soft,
                          child: BeuiMessageBubbleContent(
                            child: message.from == BeuiMessageFrom.assistant
                                ? BeuiStreamingResponse(
                                    status: message.streaming
                                        ? BeuiStreamingResponseStatus.streaming
                                        : message.stopped
                                        ? BeuiStreamingResponseStatus.stopped
                                        : BeuiStreamingResponseStatus.complete,
                                    showActions: !message.streaming,
                                    copyText: message.content,
                                    onContinue: message.stopped
                                        ? () => _continueStream(message.id)
                                        : null,
                                    stoppedMessage:
                                        'Response stopped before it finished.',
                                    continueLabel: 'Continue generating',
                                    // The scroller owns the transcript's
                                    // live region; without this it had nothing
                                    // to announce and a screen-reader user
                                    // heard the whole reply as silence.
                                    announceText: message.content,
                                    // One indicator identity — the dots
                                    // are this response's placeholder and
                                    // cross-fade into the first token.
                                    placeholder: const BeuiMessageTyping(),
                                    hasContent: message.content.isNotEmpty,
                                    child: Text(
                                      message.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.45,
                                        color: Theme.of(
                                          context,
                                        ).extension<BeuiColors>()!.foreground,
                                      ),
                                    ),
                                  )
                                : Text(
                                    message.content,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                    ),
                                  ),
                          ),
                        ),
                        if (message.from == BeuiMessageFrom.user)
                          const BeuiMessageFooter(children: [Text('Sent')]),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: BeuiPromptInput(
            loading: _busy,
            onStop: _stop,
            onSubmit: _submit,
            minRows: 1,
            maxRows: 4,
            placeholder: 'Ask the agent to continue…',
            models: _models,
            defaultModel: 'balanced',
            actions: _actions,
            onAction: _handlePromptAction,
            attachments: _attachments,
            onAttachmentRemoved: (a) => setState(() {
              _attachments = [
                for (final x in _attachments)
                  if (x.id != a.id) x,
              ];
            }),
            onAttachmentRetry: (a) {
              setState(() {
                _attachments = [
                  for (final x in _attachments)
                    if (x.id != a.id)
                      x
                    else
                      BeuiPromptAttachment(
                        id: x.id,
                        name: x.name,
                        status: BeuiPromptAttachmentStatus.uploading,
                        progress: 0,
                      ),
                ];
              });
              _runUpload(a.id);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small chrome helpers
// ---------------------------------------------------------------------------

class _SidebarNavButton extends StatelessWidget {
  const _SidebarNavButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final BeuiColors colors;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: Material(
          color: active ? colors.muted : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: colors.mutedForeground),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder generated media (source `GeneratedPreview` SVG).
class _GeneratedPreview extends StatelessWidget {
  const _GeneratedPreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    const emerald500 = Color(0xFF10B981);

    return ColoredBox(
      color: colors.muted,
      child: Center(
        child: AspectRatio(
          aspectRatio: 640 / 420,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: colors.muted)),
                  Positioned(
                    left: w * 0.1,
                    top: h * 0.12,
                    right: w * 0.1,
                    bottom: h * 0.12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.5 - 24,
                    top: h * 0.28,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: emerald500,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.28,
                    right: w * 0.28,
                    top: h * 0.48,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: colors.foreground.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.35,
                    right: w * 0.35,
                    top: h * 0.56,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.mutedForeground.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * 0.38,
                    right: w * 0.38,
                    top: h * 0.68,
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: colors.foreground,
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
