import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiAgentActivity] — mirrors the source mixed-stream
/// preview: frames of steps → search → tools, then complete, with Replay.
Widget agentActivityDemo(BuildContext context) => const _AgentActivityDemo();

const _activeBrief = BeuiAgentActivityStep(
  id: 'brief',
  label: 'Reading the launch brief',
  status: BeuiAgentStepStatus.active,
);

const _completeBrief = BeuiAgentActivityStep(
  id: 'brief',
  label: 'Reading the launch brief',
  status: BeuiAgentStepStatus.complete,
);

const _pendingSearch = BeuiAgentActivitySearch(
  id: 'search',
  query: 'independent coffee roasters in Portland',
  results: [],
);

const _completeSearch = BeuiAgentActivitySearch(
  id: 'search',
  query: 'independent coffee roasters in Portland',
  results: [
    BeuiAgentSearchResult(
      id: 'heart',
      title: 'Heart Coffee',
      domain: 'heartroasters.com',
    ),
    BeuiAgentSearchResult(
      id: 'coava',
      title: 'Coava Coffee',
      domain: 'coavacoffee.com',
    ),
    BeuiAgentSearchResult(
      id: 'upper-left',
      title: 'Upper Left Roasters',
      domain: 'upperleftroasters.com',
    ),
  ],
  moreCount: 5,
);

const _readTool = BeuiAgentActivityTool(
  id: 'read',
  action: 'read',
  target: 'campaign-notes.md',
);

const _activityFrames = <List<BeuiAgentActivityItem>>[
  [_activeBrief],
  [_completeBrief, _pendingSearch],
  [_completeBrief, _completeSearch],
  [_completeBrief, _completeSearch, _readTool],
  [
    _completeBrief,
    _completeSearch,
    _readTool,
    BeuiAgentActivityTool(
      id: 'edit',
      action: 'edit',
      target: 'launch-plan.ts',
      additions: 42,
      deletions: 8,
    ),
    BeuiAgentActivityTool(id: 'run', action: 'run', target: 'bun test launch'),
    BeuiAgentActivityStep(
      id: 'verify',
      label: 'Checking the final campaign plan',
      status: BeuiAgentStepStatus.complete,
    ),
  ],
];

class _AgentActivityDemo extends StatefulWidget {
  const _AgentActivityDemo();

  @override
  State<_AgentActivityDemo> createState() => _AgentActivityDemoState();
}

class _AgentActivityDemoState extends State<_AgentActivityDemo> {
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<BeuiColors>() ??
        BeuiColors.of(BeuiColorTheme.defaultMono, theme.brightness);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 576),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(colors, 'Mixed stream'),
              const SizedBox(height: 16),
              SizedBox(
                height: 330,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _ActivityRun(key: ValueKey<int>(_run)),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: TextButton(
                        onPressed: () => setState(() => _run++),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          // Desktop `adaptivePlatformDensity` is compact
                          // (-2,-2) and eats 4px of the 24px source button.
                          visualDensity: VisualDensity.standard,
                          foregroundColor: colors.foreground,
                        ),
                        // Source: gap-1.5 px-2 py-1 text-xs — `TextButton.icon`
                        // hardcodes an 8px gap, so build the row by hand.
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.rotate_ccw,
                              size: 12,
                              color: colors.mutedForeground,
                            ),
                            const SizedBox(width: 6), // gap-1.5
                            Text(
                              'Replay',
                              style: TextStyle(
                                fontSize: 12,
                                height: 16 / 12, // text-xs
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                                color: colors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _sectionLabel(colors, 'Completed · step summary'),
              const SizedBox(height: 12),
              BeuiAgentActivity(
                items: const [
                  BeuiAgentActivityStep(
                    id: 'a',
                    label: 'Parse the request',
                    status: BeuiAgentStepStatus.complete,
                  ),
                  BeuiAgentActivityStep(
                    id: 'b',
                    label: 'Draft the outline',
                    status: BeuiAgentStepStatus.complete,
                    meta: '1.2s',
                  ),
                  BeuiAgentActivityStep(
                    id: 'c',
                    label: 'Polish the answer',
                    status: BeuiAgentStepStatus.complete,
                  ),
                ],
                status: BeuiAgentActivityStatus.complete,
                duration: 4.6,
                defaultOpen: true,
                collapseOnComplete: false,
                maxHeight: 180,
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Trace rows'),
              const SizedBox(height: 12),
              const BeuiAgentActivity(
                items: [
                  BeuiAgentActivityTrace(
                    id: 't1',
                    kind: BeuiAgentTraceKind.thinking,
                    label: 'Plan',
                    detail: 'outline response structure',
                  ),
                  BeuiAgentActivityTrace(
                    id: 't2',
                    kind: BeuiAgentTraceKind.run,
                    label: 'Shell',
                    detail: 'rg "agent-activity" lib/',
                  ),
                  BeuiAgentActivityTrace(
                    id: 't3',
                    kind: BeuiAgentTraceKind.message,
                    label: 'Reply',
                  ),
                ],
                status: BeuiAgentActivityStatus.complete,
                defaultOpen: true,
                collapseOnComplete: false,
                maxHeight: 200,
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Failed · the run crashed'),
              const SizedBox(height: 12),
              // The failure states force the panel open and wear a card in the
              // status tier, so a crashed run can never read as a clean one.
              const BeuiAgentActivity(
                items: [
                  BeuiAgentActivityTool(
                    id: 'f1',
                    action: 'read',
                    target: 'campaign-notes.md',
                  ),
                  BeuiAgentActivityTool(
                    id: 'f2',
                    action: 'run',
                    target: 'bun test launch',
                  ),
                ],
                status: BeuiAgentActivityStatus.failed,
                failedSummary: 'Failed · bun test exited 1 after 2 tools',
                defaultOpen: true,
                maxHeight: 140,
              ),
              const SizedBox(height: 32),
              _sectionLabel(colors, 'Cancelled · stopped part-way'),
              const SizedBox(height: 12),
              const BeuiAgentActivity(
                items: [
                  BeuiAgentActivityStep(
                    id: 'c1',
                    label: 'Reading the launch brief',
                    status: BeuiAgentStepStatus.complete,
                  ),
                  BeuiAgentActivityStep(
                    id: 'c2',
                    label: 'Drafting the campaign plan',
                    status: BeuiAgentStepStatus.pending,
                  ),
                ],
                status: BeuiAgentActivityStatus.cancelled,
                duration: 12,
                defaultOpen: true,
                maxHeight: 140,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BeuiColors colors, String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.1,
        color: colors.mutedForeground.withValues(alpha: 0.85),
      ),
    );
  }
}

class _ActivityRun extends StatefulWidget {
  const _ActivityRun({super.key});

  @override
  State<_ActivityRun> createState() => _ActivityRunState();
}

class _ActivityRunState extends State<_ActivityRun> {
  int _frame = 0;
  bool _complete = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      setState(() {
        _frame = _activityFrames.length - 1;
        _complete = true;
      });
      return;
    }

    // Source: 850 + index * 1050 per subsequent frame; complete +900 after last.
    for (var i = 1; i < _activityFrames.length; i++) {
      final index = i;
      _timers.add(
        Timer(Duration(milliseconds: 850 + (index - 1) * 1050), () {
          if (mounted) setState(() => _frame = index);
        }),
      );
    }
    final finalFrameAt = 850 + (_activityFrames.length - 2) * 1050;
    _timers.add(
      Timer(Duration(milliseconds: finalFrameAt + 900), () {
        if (mounted) setState(() => _complete = true);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BeuiAgentActivity(
      items: _activityFrames[_frame],
      status: _complete
          ? BeuiAgentActivityStatus.complete
          : BeuiAgentActivityStatus.working,
      duration: 5.1,
      defaultOpen: MediaQuery.disableAnimationsOf(context),
      collapseOnComplete: !MediaQuery.disableAnimationsOf(context),
      maxHeight: 220,
    );
  }
}
