import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiMessage] — mirrors the source Message preview:
/// avatars + metadata + ghost assistant bubbles, with a live send pop-up.
Widget messageDemo(BuildContext context) => const _MessageDemo();

class _DemoMsg {
  const _DemoMsg({
    required this.id,
    required this.from,
    required this.content,
    this.animateIn = false,
  });

  final String id;
  final BeuiMessageFrom from;
  final String content;
  final bool animateIn;
}

class _MessageDemo extends StatefulWidget {
  const _MessageDemo();

  @override
  State<_MessageDemo> createState() => _MessageDemoState();
}

class _MessageDemoState extends State<_MessageDemo> {
  final _controller = TextEditingController();
  final _messages = <_DemoMsg>[
    const _DemoMsg(
      id: 'welcome-question',
      from: BeuiMessageFrom.user,
      content: 'What should we include in the first release?',
    ),
    const _DemoMsg(
      id: 'welcome-answer',
      from: BeuiMessageFrom.assistant,
      content: 'Start with the smallest workflow that still feels complete.',
    ),
  ];
  bool _pending = false;
  int _seed = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String prompt) async {
    if (prompt.trim().isEmpty || _pending) return;
    final run = _seed++;
    final userId = 'sent-user-$run';
    final assistantId = 'sent-assistant-$run';

    setState(() {
      _messages.add(
        _DemoMsg(
          id: userId,
          from: BeuiMessageFrom.user,
          content: prompt.trim(),
          animateIn: true,
        ),
      );
      _pending = true;
      _controller.clear();
    });

    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    setState(() {
      _pending = false;
      _messages.add(
        _DemoMsg(
          id: assistantId,
          from: BeuiMessageFrom.assistant,
          content:
              "I'd include composing a prompt, following a streamed answer, "
              'and returning to the latest response without losing place.',
          animateIn: true,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    children: [
                      BeuiMessageGroup(
                        spacing: BeuiMessageSpacing.standard,
                        children: [
                          const BeuiMessageMarker(child: Text('Today')),
                          for (final m in _messages) _buildRow(m, colors),
                          if (_pending)
                            BeuiMessage(
                              from: BeuiMessageFrom.assistant,
                              children: [
                                BeuiMessageAvatar(
                                  child: Icon(
                                    LucideIcons.bot,
                                    size: 14,
                                    color: colors.mutedForeground,
                                  ),
                                ),
                                const BeuiMessageContent(
                                  children: [
                                    BeuiMessageTyping(
                                      label: 'Preparing response',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
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
                          onSubmitted: _send,
                          decoration: InputDecoration(
                            hintText: 'Ask a follow-up…',
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

  Widget _buildRow(_DemoMsg m, BeuiColors colors) {
    final isUser = m.from == BeuiMessageFrom.user;
    return BeuiMessage(
      key: ValueKey(m.id),
      from: m.from,
      animateIn: m.animateIn,
      children: [
        BeuiMessageAvatar(
          child: Icon(
            isUser ? LucideIcons.user : LucideIcons.bot,
            size: 14,
            color: colors.mutedForeground,
          ),
        ),
        BeuiMessageContent(
          children: [
            BeuiMessageHeader(
              children: [
                Text(
                  isUser ? 'You' : 'Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: colors.foreground.withValues(alpha: 0.7),
                  ),
                ),
                const Text('Now'),
              ],
            ),
            BeuiMessageBubble(
              variant: isUser
                  ? BeuiMessageBubbleVariant.solid
                  : BeuiMessageBubbleVariant.ghost,
              child: BeuiMessageBubbleContent(child: Text(m.content)),
            ),
            if (isUser) const BeuiMessageFooter(children: [Text('Sent')]),
          ],
        ),
      ],
    );
  }
}
