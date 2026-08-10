import 'package:flutter/material.dart';

import 'agents_chat_preview.dart';

/// Gallery route for `BeuiMessageBubble` — a 1:1 port of the source preview
/// `components/previews/agents/message-bubble.preview.tsx`: the shared chat
/// surface with the default tones (solid user / soft assistant), the bubble
/// copy about the mount-only pop, and the `Send a bubble…` placeholder.
///
/// The registry entry for this slug ships that one preview and nothing else —
/// the tones, groups and collapsible bodies live in the page's *usage* code
/// samples, not in a rendered preview — so this route shows one surface too.
Widget messageBubbleDemo(BuildContext context) => const ChatPreview(
  reply:
      'That message mounted once with a spring pop. Streaming updates only '
      'change its content, so the entrance does not replay.',
  placeholder: 'Send a bubble…',
);
