import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMessageScroller] — mirrors the source preview:
/// a chat-height conversation with stick-to-bottom following, streaming reply,
/// and the optional message navigation rail.
Widget messageScrollerDemo(BuildContext context) =>
    const _MessageScrollerDemo();

class _DemoMsg {
  const _DemoMsg({
    required this.id,
    required this.from,
    required this.content,
    this.animateIn = false,
    this.streaming = false,
  });

  final String id;
  final BeuiMessageFrom from;
  final String content;
  final bool animateIn;
  final bool streaming;

  _DemoMsg copyWith({String? content, bool? animateIn, bool? streaming}) {
    return _DemoMsg(
      id: id,
      from: from,
      content: content ?? this.content,
      animateIn: animateIn ?? this.animateIn,
      streaming: streaming ?? this.streaming,
    );
  }
}

const _initial = <_DemoMsg>[
  _DemoMsg(
    id: 'scope-question',
    from: BeuiMessageFrom.user,
    content: 'What should the first release include?',
  ),
  _DemoMsg(
    id: 'scope-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Start with the smallest workflow that still feels complete.',
  ),
  _DemoMsg(
    id: 'states-question',
    from: BeuiMessageFrom.user,
    content: 'Include streaming and recovery states too.',
  ),
  _DemoMsg(
    id: 'states-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Yes. Those states make the first version feel dependable.',
  ),
  _DemoMsg(
    id: 'evidence-question',
    from: BeuiMessageFrom.user,
    content: 'How should we present tool results?',
  ),
  _DemoMsg(
    id: 'evidence-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Keep results close to the action that produced them.',
  ),
  _DemoMsg(
    id: 'approval-question',
    from: BeuiMessageFrom.user,
    content: 'What about actions that need confirmation?',
  ),
  _DemoMsg(
    id: 'approval-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Pause the run, explain the impact, and ask before continuing.',
  ),
  _DemoMsg(
    id: 'summary-question',
    from: BeuiMessageFrom.user,
    content: 'Can the transcript stay easy to navigate?',
  ),
  _DemoMsg(
    id: 'summary-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Use the rail to jump between turns without losing your place.',
  ),
];

const _reply =
    'The viewport follows while you stay at the live edge. Scroll upward '
    'while this response streams and it will leave your reading position alone.';

const _charsPerSecond = 96;
const _streamDelay = Duration(milliseconds: 140);

class _MessageScrollerDemo extends StatefulWidget {
  const _MessageScrollerDemo();

  @override
  State<_MessageScrollerDemo> createState() => _MessageScrollerDemoState();
}

class _MessageScrollerDemoState extends State<_MessageScrollerDemo> {
  final _controller = TextEditingController();
  final _scrollerKey = GlobalKey<BeuiMessageScrollerState>();
  final _messages = List<_DemoMsg>.of(_initial);
  bool _pending = false;
  bool _following = true;
  int _seed = 0;
  String? _activeReplyId;
  Timer? _replyTimer;
  Timer? _streamTimer;
  int _streamCursor = 0;

  bool get _loading => _pending || _activeReplyId != null;

  @override
  void dispose() {
    _replyTimer?.cancel();
    _streamTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _send(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty || _loading) return;

    final run = _seed++;
    final userId = 'sent-user-$run';
    final assistantId = 'sent-assistant-$run';
    final reduce = MediaQuery.disableAnimationsOf(context);

    setState(() {
      _messages.add(
        _DemoMsg(
          id: userId,
          from: BeuiMessageFrom.user,
          content: text,
          animateIn: true,
        ),
      );
      _pending = true;
      _controller.clear();
    });

    _replyTimer?.cancel();
    _replyTimer = Timer(
      reduce ? Duration.zero : const Duration(milliseconds: 420),
      () {
        if (!mounted) return;
        setState(() {
          _pending = false;
          _messages.add(
            _DemoMsg(
              id: assistantId,
              from: BeuiMessageFrom.assistant,
              content: '',
              animateIn: true,
              streaming: true,
            ),
          );
          _activeReplyId = assistantId;
        });
        _startStream(assistantId, _reply, reduce: reduce);
      },
    );
  }

  void _startStream(String id, String full, {required bool reduce}) {
    _streamTimer?.cancel();
    if (reduce) {
      setState(() {
        final i = _messages.indexWhere((m) => m.id == id);
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(content: full, streaming: false);
        }
        _activeReplyId = null;
      });
      return;
    }

    _streamCursor = 0;
    final started = DateTime.now().add(_streamDelay);
    _streamTimer = Timer.periodic(const Duration(milliseconds: 32), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(started);
      if (elapsed.isNegative) return;
      final cursor = (elapsed.inMilliseconds / 1000 * _charsPerSecond)
          .floor()
          .clamp(0, full.length);
      if (cursor == _streamCursor && cursor < full.length) return;
      _streamCursor = cursor;
      final slice = full.substring(0, cursor);
      setState(() {
        final i = _messages.indexWhere((m) => m.id == id);
        if (i >= 0) {
          _messages[i] = _messages[i].copyWith(
            content: slice,
            streaming: cursor < full.length,
          );
        }
      });
      if (cursor >= full.length) {
        timer.cancel();
        setState(() => _activeReplyId = null);
      }
    });
  }

  void _stop() {
    _replyTimer?.cancel();
    _streamTimer?.cancel();
    setState(() {
      _pending = false;
      _activeReplyId = null;
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].streaming) {
          _messages[i] = _messages[i].copyWith(streaming: false);
        }
      }
    });
  }

  String _truncate(String text, int limit) {
    if (text.length <= limit) return text;
    final excerpt = text.substring(0, limit);
    final boundary = excerpt.lastIndexOf(' ');
    final end = boundary > limit * 0.65 ? boundary : limit;
    return '${excerpt.substring(0, end).trim()}…';
  }

  ({String label, String? description}) _previewFor(int index) {
    final m = _messages[index];
    const titleLen = 56;
    const descLen = 88;
    final text = m.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) {
      return (
        label: m.streaming ? 'Responding…' : 'Message',
        description: null,
      );
    }
    if (text.length <= titleLen) {
      String? responseText;
      if (m.from == BeuiMessageFrom.user) {
        for (var j = index + 1; j < _messages.length; j++) {
          if (_messages[j].from == BeuiMessageFrom.assistant) {
            responseText = _messages[j].content
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            break;
          }
        }
      }
      return (
        label: text,
        description: responseText != null && responseText.isNotEmpty
            ? _truncate(responseText, descLen)
            : null,
      );
    }
    final titleExcerpt = text.substring(0, titleLen);
    final titleBoundary = titleExcerpt.lastIndexOf(' ');
    final titleEnd = titleBoundary > titleLen * 0.65 ? titleBoundary : titleLen;
    final label = '${text.substring(0, titleEnd).trim()}…';
    String responseText;
    if (m.from == BeuiMessageFrom.user) {
      responseText = '';
      for (var j = index + 1; j < _messages.length; j++) {
        if (_messages[j].from == BeuiMessageFrom.assistant) {
          responseText = _messages[j].content
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          break;
        }
      }
      if (responseText.isEmpty) {
        responseText = text.substring(titleEnd).trim();
      }
    } else {
      responseText = text.substring(titleEnd).trim();
    }
    return (
      label: label,
      description: responseText.isNotEmpty
          ? _truncate(responseText, descLen)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 576, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                // Status strip — live follow indicator.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.messages_square,
                        size: 14,
                        color: colors.mutedForeground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Message scroller',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _following
                              ? colors.primary.withValues(alpha: 0.12)
                              : colors.muted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _following
                              ? 'Following live edge'
                              : 'Reading history',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _following
                                ? colors.primary
                                : colors.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: BeuiMessageScroller(
                    key: _scrollerKey,
                    busy: _loading,
                    navigation: BeuiMessageScrollerNavigation.rail,
                    followOutput: true,
                    onFollowChange: (v) => setState(() => _following = v),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: BeuiMessageGroup(
                      spacing: BeuiMessageSpacing.standard,
                      children: [
                        for (var i = 0; i < _messages.length; i++)
                          _buildAnchoredRow(i, colors),
                        if (_pending)
                          BeuiMessageScrollerAnchor(
                            id: 'pending-typing',
                            label: 'Assistant is typing…',
                            from: BeuiMessageFrom.assistant,
                            child: BeuiMessage(
                              from: BeuiMessageFrom.assistant,
                              children: [
                                const BeuiMessageContent(
                                  children: [
                                    BeuiMessageTyping(
                                      label: 'Preparing response',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.6)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_loading,
                          onSubmitted: _send,
                          decoration: InputDecoration(
                            hintText: 'Send another message…',
                            filled: true,
                            fillColor: colors.muted,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_loading)
                        BeuiButton(
                          size: BeuiButtonSize.sm,
                          variant: BeuiButtonVariant.outline,
                          onPressed: _stop,
                          child: const Text('Stop'),
                        )
                      else
                        BeuiButton(
                          size: BeuiButtonSize.sm,
                          onPressed: () => _send(_controller.text),
                          child: const Text('Send'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnchoredRow(int index, BeuiColors colors) {
    final m = _messages[index];
    final isUser = m.from == BeuiMessageFrom.user;
    final preview = _previewFor(index);

    return BeuiMessageScrollerAnchor(
      id: m.id,
      label: preview.label,
      description: preview.description,
      from: m.from,
      child: BeuiMessage(
        key: ValueKey(m.id),
        from: m.from,
        animateIn: isUser && m.animateIn,
        children: [
          BeuiMessageContent(
            children: [
              BeuiMessageBubble(
                variant: isUser
                    ? BeuiMessageBubbleVariant.solid
                    : BeuiMessageBubbleVariant.soft,
                child: BeuiMessageBubbleContent(
                  child:
                      m.from == BeuiMessageFrom.assistant &&
                          m.content.isEmpty &&
                          m.streaming
                      ? const BeuiMessageTyping(label: 'Responding')
                      : Text(m.content),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
