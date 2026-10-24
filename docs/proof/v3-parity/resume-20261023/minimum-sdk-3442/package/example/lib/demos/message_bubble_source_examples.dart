import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

/// Source `message-bubble-avatars.preview.tsx`.
class MessageBubbleAvatarsPreview extends StatefulWidget {
  const MessageBubbleAvatarsPreview({super.key});

  @override
  State<MessageBubbleAvatarsPreview> createState() => _AvatarsState();
}

class _AvatarsState extends State<MessageBubbleAvatarsPreview> {
  int _step = 0;
  int _run = 0;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _timers.addAll([
      Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _step = 1);
      }),
      Timer(const Duration(milliseconds: 1550), () {
        if (mounted) setState(() => _step = 2);
      }),
    ]);
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 576,
      height: 410,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BeuiMessageGroup(
              key: ValueKey(_run),
              children: [
                BeuiMessage(
                  from: BeuiMessageFrom.user,
                  children: [
                    const BeuiMessageAvatar(child: Icon(LucideIcons.user)),
                    const BeuiMessageContent(
                      children: [
                        BeuiMessageHeader(children: [Text('You'), Text('Now')]),
                        BeuiMessageBubble(
                          variant: BeuiMessageBubbleVariant.solid,
                          child: BeuiMessageBubbleContent(
                            child: Text(
                              'Can you turn these notes into a launch update?',
                            ),
                          ),
                        ),
                        BeuiMessageFooter(children: [Text('Delivered')]),
                      ],
                    ),
                  ],
                ),
                if (_step >= 1)
                  const BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    children: [
                      BeuiMessageAvatar(child: Icon(LucideIcons.bot)),
                      BeuiMessageContent(
                        children: [
                          BeuiMessageHeader(
                            children: [Text('Assistant'), Text('Just now')],
                          ),
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.soft,
                            child: BeuiMessageBubbleContent(
                              child: BeuiStreamingResponse(
                                status: BeuiStreamingResponseStatus.complete,
                                showActions: false,
                                child: Text(
                                  'Absolutely. I’ll keep it concise and lead with what changed.',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                if (_step >= 2)
                  const BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    children: [
                      BeuiMessageAvatar(placeholder: true),
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.soft,
                            child: BeuiMessageBubbleContent(
                              child: BeuiStreamingResponse(
                                status: BeuiStreamingResponseStatus.complete,
                                showActions: false,
                                child: Text(
                                  'Do you want the tone to feel more technical or more customer-facing?',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ReplayButton(
                  onPressed: () {
                    setState(() {
                      _step = 0;
                      _run++;
                    });
                    _start();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Source `message-bubble-collapsible.preview.tsx`.
class MessageBubbleShowMorePreview extends StatelessWidget {
  const MessageBubbleShowMorePreview({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
      width: 576,
      height: 410,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 56, 12, 0),
        child: Align(
          alignment: Alignment.topLeft,
          child: BeuiMessage(
            from: BeuiMessageFrom.assistant,
            children: [
              BeuiMessageAvatar(child: Icon(LucideIcons.bot)),
              BeuiMessageContent(
                children: [
                  BeuiMessageHeader(
                    children: [Text('Assistant'), Text('Summary')],
                  ),
                  BeuiMessageBubble(
                    variant: BeuiMessageBubbleVariant.soft,
                    animateIn: false,
                    child: BeuiMessageBubbleContent(
                      maxWidthFactor: 0.9,
                      child: BeuiStreamingResponse(
                        status: BeuiStreamingResponseStatus.complete,
                        showActions: false,
                        child: BeuiMessageBubbleCollapsible(
                          collapsedLines: 4,
                          child: Text(
                            'The release is ready for a focused rollout. The main conversation flow, keyboard navigation, error recovery, and reduced-motion behavior are all covered.\n\n'
                            'I would keep advanced workflow controls out of this version. They add configuration without improving the first-run experience, and the usage data from this release will give us a better basis for those decisions.\n\n'
                            'Before publishing, run the accessibility suite once more and verify the streaming behavior with a long response on a smaller viewport.',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
