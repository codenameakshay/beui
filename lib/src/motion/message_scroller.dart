import 'package:flutter/material.dart';

/// A reader-aware conversation viewport that follows streamed output at the
/// live edge and releases control when the reader moves away.
///
/// Scaffold — port of the source `beui.dev/r/message-scroller` entry;
/// implementation pending. See docs/PORTING_SPEC.md §4.
class BeuiMessageScroller extends StatelessWidget {
  const BeuiMessageScroller({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('BeuiMessageScroller — not yet ported'),
    );
  }
}
