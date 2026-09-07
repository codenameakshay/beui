import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Flutter port of the source registry preview
/// `components/previews/agents/chat-preview.tsx`.
///
/// Three catalog pages (`message-bubble`, `message`, `message-scroller`) render
/// this same surface with different props, so it lives in one place here just
/// as it does in the source.
class ChatPreviewMessage {
  /// Creates a seed transcript entry.
  const ChatPreviewMessage({
    required this.id,
    required this.from,
    required this.content,
  });

  /// Stable identity — also the scroller rail anchor id.
  final String id;

  /// Author side.
  final BeuiMessageFrom from;

  /// Body text.
  final String content;
}

/// Source `DEFAULT_MESSAGES`.
const kChatPreviewDefaultMessages = <ChatPreviewMessage>[
  ChatPreviewMessage(
    id: 'welcome-question',
    from: BeuiMessageFrom.user,
    content: 'What should we include in the first release?',
  ),
  ChatPreviewMessage(
    id: 'welcome-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Start with the smallest workflow that still feels complete.',
  ),
];

/// Source `DEFAULT_REPLY`.
const kChatPreviewDefaultReply =
    'I’d include composing a prompt, following a streamed answer, '
    'recovering from an error, and returning to the latest response without '
    'losing the reader’s place.';

const _charactersPerSecond = 96;
const _streamDelay = Duration(milliseconds: 140);
const _replyDelay = Duration(milliseconds: 420);

/// How a streamed turn ended — the preview models all three so the gallery
/// doesn't teach that a response only ever succeeds.
enum ChatPreviewOutcome {
  /// Streams to the end and completes.
  complete,

  /// Fails partway through.
  error,

  /// The reader presses stop mid-stream.
  stopped,
}

class _Rendered {
  _Rendered({
    required this.id,
    required this.from,
    required this.content,
    this.animateIn = false,
    this.streaming = false,
  });

  final String id;
  final BeuiMessageFrom from;
  String content;
  final bool animateIn;
  bool streaming;

  /// Terminal status once [streaming] goes false.
  BeuiStreamingResponseStatus status = BeuiStreamingResponseStatus.complete;
}

/// The source `ChatPreview` component.
class ChatPreview extends StatefulWidget {
  /// Creates the shared chat preview surface.
  const ChatPreview({
    super.key,
    this.initialMessages = kChatPreviewDefaultMessages,
    this.reply = kChatPreviewDefaultReply,
    this.showAvatars = false,
    this.showMetadata = false,
    this.showRail = false,
    this.assistantVariant = BeuiMessageBubbleVariant.soft,
    this.userVariant = BeuiMessageBubbleVariant.solid,
    this.placeholder = 'Send a message…',
    this.outcome = ChatPreviewOutcome.complete,
    this.showActions = true,
    this.announce = true,
  });

  /// Seed transcript.
  final List<ChatPreviewMessage> initialMessages;

  /// Canned assistant answer streamed after each send.
  final String reply;

  /// Show the sender avatar column.
  final bool showAvatars;

  /// Show the per-message header/footer metadata.
  final bool showMetadata;

  /// Show the scroller's navigation rail.
  final bool showRail;

  /// Bubble tone for assistant turns.
  final BeuiMessageBubbleVariant assistantVariant;

  /// Bubble tone for user turns.
  final BeuiMessageBubbleVariant userVariant;

  /// Composer placeholder.
  final String placeholder;

  /// How the canned reply ends. `complete` streams to the end; `error`
  /// fails partway; `stopped` is what the composer's stop button produces.
  final ChatPreviewOutcome outcome;

  /// Whether responses carry copy / retry / feedback controls. True by
  /// default, so the library's "real chat" showcase demonstrates the
  /// controls every response should offer.
  final bool showActions;

  /// Whether the transcript speaks streamed text.
  ///
  /// True by default. The old preview passed `announce: false` to each
  /// response to work around the nested-live-region problem; the scroller now
  /// owns the conversation's one live region, so the correct answer is to
  /// leave it on and let each response push sentences into it.
  final bool announce;

  @override
  State<ChatPreview> createState() => _ChatPreviewState();
}

class _ChatPreviewState extends State<ChatPreview> {
  late final List<_Rendered> _messages = [
    for (final m in widget.initialMessages)
      _Rendered(id: m.id, from: m.from, content: m.content),
  ];

  int _nextId = 0;
  bool _pending = false;
  Timer? _replyTimer;
  Timer? _streamTimer;
  _Rendered? _streamTarget;
  String _streamFull = '';
  Stopwatch? _streamClock;

  bool get _loading => _pending || _streamTarget != null;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _streamTimer?.cancel();
    super.dispose();
  }

  void _submit(String prompt, String? model) {
    if (_loading) return;
    final run = _nextId++;
    // The assistant row is created now, empty and streaming, so the turn has
    // one identity from "preparing" through "streaming" to "done" instead of
    // a pending row that unmounts and hands off to a separate real row.
    setState(() {
      _messages
        ..add(
          _Rendered(
            id: 'sent-user-$run',
            from: BeuiMessageFrom.user,
            content: prompt,
            animateIn: true,
          ),
        )
        ..add(
          _Rendered(
            id: 'sent-assistant-$run',
            from: BeuiMessageFrom.assistant,
            content: '',
            animateIn: true,
            streaming: true,
          ),
        );
      _pending = true;
    });
    _beginReply('sent-assistant-$run');
  }

  void _beginReply(String id) {
    _replyTimer?.cancel();
    _replyTimer = Timer(_replyDelay, () {
      if (!mounted) return;
      final existing = _messages.where((m) => m.id == id).firstOrNull;
      final target =
          existing ??
          _Rendered(
            id: id,
            from: BeuiMessageFrom.assistant,
            content: '',
            animateIn: true,
            streaming: true,
          );
      setState(() {
        if (existing == null) {
          _messages.add(target);
        } else {
          target.content = '';
        }
        target.streaming = true;
        target.status = BeuiStreamingResponseStatus.complete;
        _pending = false;
        _streamTarget = target;
        _streamFull = widget.reply;
      });
      _startStream();
    });
  }

  /// Where an `error` outcome gives up, as a fraction of the reply.
  static const double _failAt = 0.55;

  void _startStream() {
    _streamClock = Stopwatch()..start();
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      final target = _streamTarget;
      final clock = _streamClock;
      if (!mounted || target == null || clock == null) {
        t.cancel();
        return;
      }
      final elapsed = clock.elapsed - _streamDelay;
      final cursor = elapsed.isNegative
          ? 0
          : (elapsed.inMicroseconds / 1e6 * _charactersPerSecond).floor().clamp(
              0,
              _streamFull.length,
            );

      // The error route stops mid-answer, which is what a real failure
      // looks like — a partial response plus a distinct failure affordance.
      if (widget.outcome == ChatPreviewOutcome.error &&
          cursor >= (_streamFull.length * _failAt).floor()) {
        t.cancel();
        setState(() {
          target.content = _streamFull.substring(
            0,
            (_streamFull.length * _failAt).floor(),
          );
          target.streaming = false;
          target.status = BeuiStreamingResponseStatus.error;
          _streamTarget = null;
        });
        return;
      }

      final next = _streamFull.substring(0, cursor);
      if (next != target.content) setState(() => target.content = next);
      if (cursor >= _streamFull.length) {
        t.cancel();
        setState(() {
          target.streaming = false;
          target.status = BeuiStreamingResponseStatus.complete;
          _streamTarget = null;
        });
      }
    });
  }

  /// Stopping leaves the turn in `stopped`, not a fake `complete`.
  void _stop() {
    _replyTimer?.cancel();
    _streamTimer?.cancel();
    setState(() {
      _pending = false;
      for (final m in _messages) {
        if (!m.streaming) continue;
        m.streaming = false;
        m.status = BeuiStreamingResponseStatus.stopped;
      }
      _streamTarget = null;
    });
  }

  /// Resumes a stopped turn, or retries a failed one, in place.
  void _resume(_Rendered message) {
    if (_loading) return;
    setState(() => _pending = true);
    _beginReply(message.id);
  }

  Widget _row(_Rendered message) {
    final bubble = BeuiMessage(
      key: ValueKey(message.id),
      from: message.from,
      animateIn: message.from == BeuiMessageFrom.user && message.animateIn,
      children: [
        if (widget.showAvatars)
          BeuiMessageAvatar(
            child: Icon(
              message.from == BeuiMessageFrom.user
                  ? LucideIcons.user
                  : LucideIcons.bot,
            ),
          ),
        BeuiMessageContent(
          children: [
            if (widget.showMetadata)
              BeuiMessageHeader(
                children: [
                  Text(
                    message.from == BeuiMessageFrom.user ? 'You' : 'Assistant',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(message.streaming ? 'Responding' : 'Now'),
                ],
              ),
            BeuiMessageBubble(
              variant: message.from == BeuiMessageFrom.user
                  ? widget.userVariant
                  : widget.assistantVariant,
              child: BeuiMessageBubbleContent(
                child: message.from == BeuiMessageFrom.assistant
                    ? BeuiStreamingResponse(
                        status: message.streaming
                            ? BeuiStreamingResponseStatus.streaming
                            : message.status,
                        showActions: widget.showActions,
                        // The scroller owns the transcript's live region; this
                        // feeds it the actual streamed text.
                        announceText: message.content,
                        copyText: message.content,
                        onRetry: () => _resume(message),
                        onContinue: () => _resume(message),
                        // One indicator identity: the typing dots are the
                        // response's placeholder, so they cross-fade into the
                        // first token instead of unmounting into an empty box.
                        placeholder: const BeuiMessageTyping(),
                        hasContent: message.content.isNotEmpty,
                        child: Text(message.content),
                      )
                    : Text(message.content),
              ),
            ),
            if (widget.showMetadata && message.from == BeuiMessageFrom.user)
              const BeuiMessageFooter(children: [Text('Sent')]),
          ],
        ),
      ],
    );

    if (!widget.showRail) return bubble;
    return BeuiMessageScrollerAnchor(
      id: message.id,
      from: message.from,
      label: message.from == BeuiMessageFrom.user ? 'You' : 'Assistant',
      description: message.content,
      child: bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    // source: `flex h-[440px] w-full max-w-xl flex-col overflow-hidden
    //          rounded-2xl border border-border/70 bg-background`
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576),
        child: Container(
          height: 440,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.border.withValues(alpha: colors.border.a * 0.7),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: BeuiMessageScroller(
                  busy: _loading,
                  navigation: widget.showRail
                      ? BeuiMessageScrollerNavigation.rail
                      : null,
                  // source viewportClassName: `px-3 py-4`
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  announce: widget.announce,
                  child: BeuiMessageGroup(
                    spacing: BeuiMessageSpacing.standard,
                    children: [for (final m in _messages) _row(m)],
                  ),
                ),
              ),
              // source: `shrink-0 border-t border-border/60 p-2`
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.border.withValues(
                        alpha: colors.border.a * 0.6,
                      ),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: BeuiPromptInput(
                    minRows: 1,
                    maxRows: 1,
                    loading: _loading,
                    onSubmit: _submit,
                    onStop: _stop,
                    placeholder: widget.placeholder,
                    // source className: `border-0 bg-muted shadow-none`
                    bordered: false,
                    surfaceColor: colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
