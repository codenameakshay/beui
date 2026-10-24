import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import 'agents_chat_preview.dart';

/// Gallery route for [BeuiMessage] — a 1:1 port of the source preview
/// `components/previews/agents/message.preview.tsx`: avatars + metadata +
/// ghost assistant bubbles over the shared chat surface.
Widget messageDemo(BuildContext context) => const ChatPreview(
  showAvatars: true,
  showMetadata: true,
  assistantVariant: BeuiMessageBubbleVariant.ghost,
  placeholder: 'Ask a follow-up…',
);
