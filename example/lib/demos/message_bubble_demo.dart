import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'agents_chat_preview.dart';

/// Gallery route for [BeuiMessageBubble] — the source preview
/// (`message-bubble.preview.tsx`) followed by tones, groups, collapsible
/// content, and interactive bubbles.
Widget messageBubbleDemo(BuildContext context) => const _MessageBubbleDemo();

class _MessageBubbleDemo extends StatefulWidget {
  const _MessageBubbleDemo();

  @override
  State<_MessageBubbleDemo> createState() => _MessageBubbleDemoState();
}

class _MessageBubbleDemoState extends State<_MessageBubbleDemo> {
  final _controller = TextEditingController();
  final _sent = <String>[];
  int _taps = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sent.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // source preview `message-bubble.preview.tsx`
              const ChatPreview(
                reply:
                    'That message mounted once with a spring pop. Streaming '
                    'updates only change its content, so the entrance does '
                    'not replay.',
                placeholder: 'Send a bubble…',
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Variants'),
              const SizedBox(height: 12),
              BeuiMessageGroup(
                spacing: BeuiMessageSpacing.standard,
                children: [
                  for (final variant in BeuiMessageBubbleVariant.values)
                    BeuiMessage(
                      from: variant == BeuiMessageBubbleVariant.solid
                          ? BeuiMessageFrom.user
                          : BeuiMessageFrom.assistant,
                      children: [
                        BeuiMessageContent(
                          children: [
                            BeuiMessageHeader(children: [Text(variant.name)]),
                            BeuiMessageBubble(
                              variant: variant,
                              child: BeuiMessageBubbleContent(
                                child: Text('The ${variant.name} bubble tone.'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Grouped bubbles'),
              const SizedBox(height: 12),
              BeuiMessage(
                from: BeuiMessageFrom.assistant,
                children: [
                  BeuiMessageContent(
                    children: [
                      BeuiMessageBubbleGroup(
                        children: [
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.soft,
                            child: const BeuiMessageBubbleContent(
                              child: Text('First thought in the group.'),
                            ),
                          ),
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.soft,
                            child: const BeuiMessageBubbleContent(
                              child: Text('Second thought, same speaker.'),
                            ),
                          ),
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.tint,
                            child: const BeuiMessageBubbleContent(
                              child: Text('A tinted follow-up.'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Collapsible + interactive'),
              const SizedBox(height: 12),
              BeuiMessage(
                from: BeuiMessageFrom.assistant,
                children: [
                  BeuiMessageContent(
                    children: [
                      BeuiMessageBubble(
                        variant: BeuiMessageBubbleVariant.soft,
                        child: BeuiMessageBubbleContent(
                          child: BeuiMessageBubbleCollapsible(
                            collapsedLines: 3,
                            child: Text(
                              'Long-form content that collapses to a few lines '
                              'with a bottom fade, then expands on demand. '
                              'This mirrors the source MessageBubbleCollapsible '
                              'with more/less labels and a springing chevron. '
                              'Use it for lengthy assistant replies, quotes, or '
                              'any bubble body that should stay scannable at rest.',
                              style: TextStyle(color: colors.foreground),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      BeuiMessageBubble(
                        variant: BeuiMessageBubbleVariant.outline,
                        child: BeuiMessageBubbleContent(
                          onTap: () => setState(() => _taps++),
                          child: Text('Tap me — interactive bubble ($_taps)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Mount pop on send'),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.border.withValues(
                      alpha: colors.border.a * 0.7,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: BeuiMessageGroup(
                        children: [
                          for (var i = 0; i < _sent.length; i++)
                            BeuiMessage(
                              key: ValueKey('sent-$i-${_sent[i]}'),
                              from: BeuiMessageFrom.user,
                              animateIn: true,
                              children: [
                                BeuiMessageContent(
                                  children: [
                                    BeuiMessageBubble(
                                      variant: BeuiMessageBubbleVariant.solid,
                                      animateIn: true,
                                      child: BeuiMessageBubbleContent(
                                        child: Text(_sent[i]),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          if (_sent.isEmpty)
                            Text(
                              'Send a bubble to see the spring pop.',
                              style: TextStyle(
                                color: colors.mutedForeground,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: colors.border.withValues(
                        alpha: colors.border.a * 0.6,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'Send a bubble…',
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
                            onPressed: _send,
                            child: const Text('Send'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BeuiColors colors, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.mutedForeground,
      ),
    );
  }
}
