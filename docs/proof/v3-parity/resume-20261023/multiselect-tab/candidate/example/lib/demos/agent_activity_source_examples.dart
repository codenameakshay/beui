import 'dart:async';
import 'dart:math' as math;

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';
import 'agent_search_marks.dart';

enum AgentActivityExample { text, steps, search, tools, trace }

const _reasoning =
    'Reading the request and separating the content model from its presentation.\n'
    'The activity shell can stay consistent while each event supplies its own compact renderer.\n'
    'Text remains freeform so partial tokens can update without recreating the surrounding timeline.\n'
    'As each sentence wraps, the measured stream moves upward through a single transform instead of repeatedly jumping the native scroll position.\n'
    'Older context stays available above the fold while the newest tokens remain crisp at the bottom edge.\n'
    'Once the run finishes, the viewport switches from automatic following to ordinary user-controlled scrolling.\n'
    'Opening the completed disclosure returns to the beginning so the reasoning can be read in order.\n'
    'The capped viewport follows the latest sentence and preserves the full log after completion.';

const _steps = [
  ('brief', 'Reading the product brief', null),
  ('patterns', 'Mapping the interaction patterns', null),
  ('states', 'Connecting the loading and completion states', '3 states'),
  ('verify', 'Verifying the final behavior', null),
];
const _tools = <BeuiAgentActivityItem>[
  BeuiAgentActivityTool(
    id: 'read',
    action: 'read',
    target: 'campaign-notes.md',
  ),
  BeuiAgentActivityTool(
    id: 'edit',
    action: 'edit',
    target: 'launch-plan.ts',
    additions: 42,
    deletions: 8,
  ),
  BeuiAgentActivityTool(id: 'run', action: 'run', target: 'bun test launch'),
];
const _trace = <BeuiAgentActivityItem>[
  BeuiAgentActivityTrace(
    id: 'plan',
    kind: BeuiAgentTraceKind.thinking,
    label: 'Thinking',
    detail: 'Mapping the interaction flow…',
  ),
  BeuiAgentActivityTrace(
    id: 'decision',
    kind: BeuiAgentTraceKind.message,
    label: 'Decision',
    detail: 'Use one compact disclosure',
  ),
  BeuiAgentActivityTrace(
    id: 'write',
    kind: BeuiAgentTraceKind.write,
    label: 'Draft component',
    detail: 'components/agents/run-log.tsx',
  ),
  BeuiAgentActivityTrace(
    id: 'verify',
    kind: BeuiAgentTraceKind.run,
    label: 'Validate types',
    detail: 'bun run typecheck',
  ),
  BeuiAgentActivityTrace(
    id: 'inspect',
    kind: BeuiAgentTraceKind.read,
    label: 'Inspect preview',
    detail: 'activity-preview.png',
  ),
];
const _results = [
  BeuiAgentSearchResult(
    id: 'google',
    title: 'Google for Developers',
    domain: 'developers.google.com',
    icon: AgentSearchMark('google'),
  ),
  BeuiAgentSearchResult(
    id: 'github',
    title: 'GitHub',
    domain: 'github.com',
    icon: AgentSearchMark('github'),
  ),
  BeuiAgentSearchResult(
    id: 'wikipedia',
    title: 'Wikipedia',
    domain: 'wikipedia.org',
    icon: AgentSearchMark('wikipedia'),
  ),
  BeuiAgentSearchResult(
    id: 'vercel',
    title: 'Vercel Docs',
    domain: 'vercel.com/docs',
    icon: AgentSearchMark('vercel'),
  ),
];

/// Independently addressable source activity examples with their own clocks.
class AgentActivitySourcePreview extends StatefulWidget {
  const AgentActivitySourcePreview({required this.example, super.key});
  final AgentActivityExample example;
  @override
  State<AgentActivitySourcePreview> createState() => _SourcePreviewState();
}

class _SourcePreviewState extends State<AgentActivitySourcePreview> {
  int _run = 0;
  int _elapsed = 0;
  bool _reduce = false;
  Timer? _timer;

  int get _completionMs => switch (widget.example) {
    AgentActivityExample.text => (_reasoning.length / 90 * 1000).ceil() + 500,
    AgentActivityExample.steps => 4200,
    AgentActivityExample.search => 3900,
    AgentActivityExample.tools => 3600,
    AgentActivityExample.trace => 3500,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
    _start();
  }

  @override
  void didUpdateWidget(AgentActivitySourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.example != widget.example) _start();
  }

  void _start() {
    _timer?.cancel();
    _elapsed = _reduce ? _completionMs : 0;
    if (_reduce) return;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _elapsed = timer.tick * 16);
      if (_elapsed >= _completionMs) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _visible(int start, int interval, int count) =>
      ((_elapsed - start) ~/ interval + 1).clamp(0, count);

  @override
  Widget build(BuildContext context) {
    final complete = _elapsed >= _completionMs;
    final example = widget.example;
    final stepsVisible = _elapsed < 850
        ? 1
        : math.min(4, 2 + (_elapsed - 850) ~/ 800);
    final searchVisible = _elapsed < 650 ? 0 : _visible(650, 650, 4);
    final items = switch (example) {
      AgentActivityExample.text =>
        _reasoning
            .substring(
              0,
              math.min(_reasoning.length, (_elapsed / 1000 * 90).floor()),
            )
            .split('\n')
            .where((s) => s.isNotEmpty)
            .indexed
            .map<BeuiAgentActivityItem>(
              (line) => BeuiAgentActivityText(
                id: 'reasoning-${line.$1}',
                content: line.$2,
              ),
            )
            .toList(),
      AgentActivityExample.steps => [
        for (var i = 0; i < stepsVisible; i++)
          BeuiAgentActivityStep(
            id: _steps[i].$1,
            label: _steps[i].$2,
            meta: _steps[i].$3,
            status: _elapsed >= 3300 || i < stepsVisible - 1
                ? BeuiAgentStepStatus.complete
                : BeuiAgentStepStatus.active,
          ),
      ],
      AgentActivityExample.search => [
        BeuiAgentActivitySearch(
          id: 'search',
          query: 'accessible animation patterns for React',
          results: _results.take(searchVisible).toList(),
          moreCount: searchVisible == 4 ? 7 : null,
        ),
      ],
      AgentActivityExample.tools =>
        _tools.take(_elapsed < 550 ? 0 : _visible(550, 850, 3)).toList(),
      AgentActivityExample.trace =>
        _trace.take(_elapsed < 250 ? 0 : _visible(250, 650, 5)).toList(),
    };
    return Center(
      child: SizedBox(
        width: example == AgentActivityExample.trace ? 576 : 512,
        height: example == AgentActivityExample.trace ? 300 : 330,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: BeuiAgentActivity(
                key: ValueKey(_run),
                items: items,
                contentType: switch (example) {
                  AgentActivityExample.text =>
                    BeuiAgentActivityContentType.text,
                  AgentActivityExample.steps =>
                    BeuiAgentActivityContentType.step,
                  AgentActivityExample.search =>
                    BeuiAgentActivityContentType.search,
                  AgentActivityExample.tools =>
                    BeuiAgentActivityContentType.tool,
                  AgentActivityExample.trace =>
                    BeuiAgentActivityContentType.trace,
                },
                status: complete
                    ? BeuiAgentActivityStatus.complete
                    : BeuiAgentActivityStatus.working,
                duration: example == AgentActivityExample.text
                    ? _reasoning.length / 90
                    : example == AgentActivityExample.steps
                    ? 4.2
                    : 0,
                defaultOpen: _reduce,
                collapseOnComplete: !_reduce,
                maxHeight: example == AgentActivityExample.text
                    ? 180
                    : example == AgentActivityExample.trace
                    ? 190
                    : 220,
                activeLabel: example == AgentActivityExample.trace
                    ? 'Running the agent trace…'
                    : null,
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: ReplayButton(
                onPressed: () => setState(() {
                  _run++;
                  _start();
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
