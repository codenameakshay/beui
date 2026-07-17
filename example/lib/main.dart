import 'package:flutter/material.dart';

import 'explorer/explorer_app.dart';

/// The beUI component explorer — a Flutter gallery that mirrors the layout and
/// feel of beui.dev's component explorer (sidebar + card grid + detail pages)
/// across Components, Blocks and the Motion Guides. Each detail page's Preview
/// tab renders the real ported widget, so the gallery doubles as the living
/// showcase and the render target for golden tests.
///
/// The chrome lives in `explorer/`; the individual demos live in `demos/`.
void main() => runApp(const BeuiExplorerApp());
