import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route proving that a consumer installs [BeuiAgentTheme] once and
/// then uses ordinary agent widgets — no visual wrappers.
///
/// The serif face is a stand-in for a consumer family such as General Sans;
/// the published package ships no fonts. The palette is a warm green built
/// from [BeuiColors] so [BeuiAgentTheme] does not have to duplicate color.
Widget agentThemeDemo(BuildContext context) => const _AgentThemeDemo();

class _AgentThemeDemo extends StatefulWidget {
  const _AgentThemeDemo();

  @override
  State<_AgentThemeDemo> createState() => _AgentThemeDemoState();
}

class _AgentThemeDemoState extends State<_AgentThemeDemo> {
  bool _expanded = false;
  BeuiApprovalCardStatus _status = BeuiApprovalCardStatus.pending;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = BeuiColors.of(BeuiColorTheme.green, brightness).copyWith(
      primary: brightness == Brightness.dark
          ? const Color(0xFF7CB86A)
          : const Color(0xFF3D6B2F),
      accent: brightness == Brightness.dark
          ? const Color(0xFFC4A35A)
          : const Color(0xFF8A6A2F),
    );

    const agent = BeuiAgentTheme(
      shapes: BeuiAgentShapes(
        userBubble: BorderRadius.all(Radius.circular(22)),
        assistantBubble: BorderRadius.all(Radius.circular(10)),
        card: BorderRadius.all(Radius.circular(18)),
        nested: BorderRadius.all(Radius.circular(10)),
      ),
      layout: BeuiAgentLayout(
        conversationGutter: EdgeInsets.fromLTRB(16, 12, 16, 12),
        turnSpacing: 12,
        groupedMessageSpacing: 4,
        bubblePadding: EdgeInsets.fromLTRB(12, 8, 12, 8),
        cardPadding: EdgeInsets.all(12),
        sectionSpacing: 10,
      ),
      icons: BeuiAgentIcons(
        pendingApproval: Icons.gavel_outlined,
        expand: Icons.unfold_more,
        edit: Icons.edit_outlined,
        approved: Icons.check_circle_outline,
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        // Stand-in for a consumer face such as General Sans.
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'serif'),
        extensions: [colors, agent],
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 560,
            child: BeuiMessageScroller(
              padding: agent.layout.conversationGutter,
              child: BeuiMessageGroup(
                spacing: BeuiMessageSpacing.standard,
                children: [
                  const BeuiMessage(
                    from: BeuiMessageFrom.user,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiMessageBubble(
                            variant: BeuiMessageBubbleVariant.solid,
                            child: BeuiMessageBubbleContent(
                              child: Text(
                                'Draft the next step and wait for my OK.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  BeuiMessage(
                    from: BeuiMessageFrom.assistant,
                    children: [
                      BeuiMessageContent(
                        children: [
                          BeuiStreamingResponse(
                            status: BeuiStreamingResponseStatus.complete,
                            child: Text(
                              'Here is a compact proposal. Expand it to edit '
                              'the details, then approve or reject.',
                              style: agent.typography.assistantBody.copyWith(
                                color: colors.foreground,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const BeuiAgentActivity(
                            status: BeuiAgentActivityStatus.complete,
                            items: [
                              BeuiAgentActivityText(
                                id: 'compare',
                                content:
                                    'Compared the current draft against the last approved version.',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          BeuiApprovalCard(
                            title: 'Apply this change?',
                            description:
                                'Only the decision is visible until you expand.',
                            status: _status,
                            expanded: _expanded,
                            onExpandedChanged: (v) =>
                                setState(() => _expanded = v),
                            headerAction: IconButton(
                              tooltip: 'Edit',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _expanded = !_expanded),
                              icon: Icon(agent.icons.edit, size: 16),
                            ),
                            compactChild: Text(
                              'Update the shared layout and keep the current split.',
                              style: agent.typography.description.copyWith(
                                color: colors.mutedForeground,
                              ),
                            ),
                            expandedChild: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Full proposal',
                                  style: agent.typography.title.copyWith(
                                    color: colors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Keep the current participants, apply the new '
                                  'totals, and record this as a single turn. '
                                  'Nothing here is product-specific — the card '
                                  'only hosts whatever editor the consumer builds.',
                                  style: agent.typography.description.copyWith(
                                    color: colors.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // The expandable body renders its children
                                // exactly once — see the EditableText-count
                                // test in test/motion/approval_card_test.dart.
                                BeuiInput(
                                  defaultValue: 'Shared layout',
                                  onChanged: (_) {},
                                ),
                              ],
                            ),
                            onApprove: () => setState(
                              () => _status = BeuiApprovalCardStatus.approved,
                            ),
                            onReject: () => setState(
                              () => _status = BeuiApprovalCardStatus.rejected,
                            ),
                            onRequestChanges: () => setState(
                              () => _status =
                                  BeuiApprovalCardStatus.changesRequested,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const BeuiToolResult(
                            kind: BeuiToolResultKind.terminal,
                            status: BeuiToolResultStatus.success,
                            tool: 'apply_change',
                            title: 'apply_change',
                            meta: '120ms',
                            child: BeuiToolResultOutput(
                              code: 'ok\n3 files updated',
                              language: BeuiCodeLanguage.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
