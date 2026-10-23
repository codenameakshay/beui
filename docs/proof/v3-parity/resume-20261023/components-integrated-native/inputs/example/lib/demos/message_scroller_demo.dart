import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'agents_chat_preview.dart';

/// Gallery route for [BeuiMessageScroller] — a 1:1 port of the source preview
/// `components/previews/agents/message-scroller.preview.tsx`: a ten-turn
/// transcript with the navigation rail, live-edge following, and a composer.
Widget messageScrollerDemo(BuildContext context) => const ChatPreview(
  initialMessages: _messages,
  showRail: true,
  reply:
      'The viewport follows while you stay at the live edge. Scroll upward '
      'while this response streams and it will leave your reading position '
      'alone.',
  placeholder: 'Send another message…',
);

/// Source `MESSAGES`.
const _messages = <ChatPreviewMessage>[
  ChatPreviewMessage(
    id: 'scope-question',
    from: BeuiMessageFrom.user,
    content: 'What should the first release include?',
  ),
  ChatPreviewMessage(
    id: 'scope-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Start with the smallest workflow that still feels complete.',
  ),
  ChatPreviewMessage(
    id: 'states-question',
    from: BeuiMessageFrom.user,
    content: 'Include streaming and recovery states too.',
  ),
  ChatPreviewMessage(
    id: 'states-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Yes. Those states make the first version feel dependable.',
  ),
  ChatPreviewMessage(
    id: 'evidence-question',
    from: BeuiMessageFrom.user,
    content: 'How should we present tool results?',
  ),
  ChatPreviewMessage(
    id: 'evidence-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Keep results close to the action that produced them.',
  ),
  ChatPreviewMessage(
    id: 'approval-question',
    from: BeuiMessageFrom.user,
    content: 'What about actions that need confirmation?',
  ),
  ChatPreviewMessage(
    id: 'approval-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Pause the run, explain the impact, and ask before continuing.',
  ),
  ChatPreviewMessage(
    id: 'summary-question',
    from: BeuiMessageFrom.user,
    content: 'Can the transcript stay easy to navigate?',
  ),
  ChatPreviewMessage(
    id: 'summary-answer',
    from: BeuiMessageFrom.assistant,
    content: 'Use the rail to jump between turns without losing your place.',
  ),
];
