import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';
import 'agents_chat_preview.dart';

/// Gallery route for `BeuiMessageBubble`: the source preview's shared chat
/// surface, plus a specimen sheet covering tones, grouping, collapsing and
/// interaction that the source's docs-only usage samples don't render.
Widget messageBubbleDemo(BuildContext context) => const _MessageBubbleDemo();

class _MessageBubbleDemo extends StatelessWidget {
  const _MessageBubbleDemo();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChatPreview(
                reply:
                    'That message mounted once with a spring pop. Streaming '
                    'updates only change its content, so the entrance does '
                    'not replay.',
                placeholder: 'Send a bubble…',
              ),
              SizedBox(height: 32),
              _Section(
                title: 'Tones',
                blurb:
                    'Six variants. `danger` carries a leading alert glyph as '
                    'well as its tint, so the state survives a colourblind '
                    'reader; `outline` has a card fill so its hairline is not '
                    'the only thing holding the shape.',
                child: _Tones(),
              ),
              SizedBox(height: 32),
              _Section(
                title: 'Group and marker',
                blurb:
                    'Consecutive turns from one author stack in a group under '
                    'a single avatar; a marker separates them.',
                child: _GroupAndMarker(),
              ),
              SizedBox(height: 32),
              _Section(
                title: 'Collapsible',
                blurb:
                    'Long bodies clamp to `collapsedLines` behind a fade and '
                    'animate open on the library disclosure curve.',
                child: _Collapsible(),
              ),
              SizedBox(height: 32),
              _Section(
                title: 'Interactive',
                blurb:
                    'A bubble with `onTap` is a button: it reports the role, '
                    'takes Enter and Space, and shows a focus ring painted '
                    'outside layout so focusing does not reflow the text.',
                child: _Interactive(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.blurb,
    required this.child,
  });

  final String title;
  final String blurb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title, note: blurb),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.borderStrong),
          ),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

/// Every variant, both sides, with the label naming what you are looking at.
class _Tones extends StatelessWidget {
  const _Tones();

  static const _labels = <BeuiMessageBubbleVariant, String>{
    BeuiMessageBubbleVariant.solid: 'solid — the usual user turn',
    BeuiMessageBubbleVariant.soft: 'soft — the usual assistant turn',
    BeuiMessageBubbleVariant.tint: 'tint — primary wash, for emphasis',
    BeuiMessageBubbleVariant.outline: 'outline — bordered card surface',
    BeuiMessageBubbleVariant.ghost: 'ghost — no chrome, full width',
    BeuiMessageBubbleVariant.danger: 'danger — a turn that went wrong',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in _labels.entries) ...[
          if (entry.key != _labels.keys.first) const SizedBox(height: 12),
          BeuiMessage(
            key: ValueKey(entry.key),
            // `solid` is the user tone, so show it on the user side.
            from: entry.key == BeuiMessageBubbleVariant.solid
                ? BeuiMessageFrom.user
                : BeuiMessageFrom.assistant,
            animateIn: false,
            children: [
              BeuiMessageContent(
                children: [
                  BeuiMessageBubble(
                    variant: entry.key,
                    animateIn: false,
                    child: BeuiMessageBubbleContent(child: Text(entry.value)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GroupAndMarker extends StatelessWidget {
  const _GroupAndMarker();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiMessage(
          from: BeuiMessageFrom.assistant,
          animateIn: false,
          children: [
            BeuiMessageAvatar(child: Icon(LucideIcons.bot)),
            BeuiMessageContent(
              children: [
                BeuiMessageHeader(children: [Text('Assistant'), Text('09:41')]),
                BeuiMessageBubbleGroup(
                  children: [
                    BeuiMessageBubble(
                      animateIn: false,
                      child: BeuiMessageBubbleContent(
                        child: Text('I found three candidates.'),
                      ),
                    ),
                    BeuiMessageBubble(
                      animateIn: false,
                      child: BeuiMessageBubbleContent(
                        child: Text('Two are in the checkout path.'),
                      ),
                    ),
                    BeuiMessageBubble(
                      animateIn: false,
                      child: BeuiMessageBubbleContent(
                        child: Text('Want me to open the first?'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        BeuiMessageMarker(child: Text('New messages')),
        SizedBox(height: 16),
        BeuiMessage(
          from: BeuiMessageFrom.user,
          animateIn: false,
          children: [
            BeuiMessageContent(
              children: [
                BeuiMessageBubble(
                  variant: BeuiMessageBubbleVariant.solid,
                  animateIn: false,
                  child: BeuiMessageBubbleContent(child: Text('Open it.')),
                ),
                BeuiMessageFooter(children: [Text('Sent')]),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible();

  static const _long =
      'The checkout flow calls the pricing service twice: once to render the '
      'summary and again on submit. The second call is what fails under load, '
      'because it happens inside the transaction and inherits its timeout. '
      'Moving it before the transaction opens fixes the timeout without '
      'changing the pricing logic, and it also lets the summary and the '
      'submit share one response instead of racing each other. The tradeoff '
      'is a slightly staler price if the user waits on the summary screen, '
      'which the existing five-second cache already allows for.';

  @override
  Widget build(BuildContext context) {
    return const BeuiMessage(
      from: BeuiMessageFrom.assistant,
      animateIn: false,
      children: [
        BeuiMessageContent(
          children: [
            BeuiMessageBubble(
              animateIn: false,
              child: BeuiMessageBubbleContent(
                child: BeuiMessageBubbleCollapsible(
                  collapsedLines: 3,
                  child: Text(_long),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Interactive extends StatefulWidget {
  const _Interactive();

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiMessage(
          from: BeuiMessageFrom.assistant,
          animateIn: false,
          children: [
            BeuiMessageContent(
              children: [
                BeuiMessageBubble(
                  variant: BeuiMessageBubbleVariant.outline,
                  animateIn: false,
                  child: BeuiMessageBubbleContent(
                    semanticLabel: 'Open pricing service trace',
                    onTap: () => setState(() => _taps++),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.external_link, size: 14),
                        SizedBox(width: 8),
                        Flexible(child: Text('Open pricing service trace')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _taps == 0
              ? 'Tab to it, then press Enter or Space.'
              : 'Activated $_taps ${_taps == 1 ? 'time' : 'times'}.',
          style: TextStyle(fontSize: 12, color: colors.mutedForeground),
        ),
      ],
    );
  }
}
