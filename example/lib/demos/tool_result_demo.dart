import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiToolResult] — mirrors the source docs previews:
/// a streaming terminal run that collapses on complete, and a request result
/// that ends in error with retry / copy chrome.
///
/// The remaining sections cover the states the audit found unrepresented: a
/// cancelled run, the two-line header under 400px, a capped viewport with its
/// fade + "N more" cue, and two concurrent tool calls composed as a plain
/// [Column] (the A25 recipe — there is no separate "tool group" component).
Widget toolResultDemo(BuildContext context) => const _ToolResultDemo();

class _ToolResultDemo extends StatefulWidget {
  const _ToolResultDemo();

  @override
  State<_ToolResultDemo> createState() => _ToolResultDemoState();
}

class _ToolResultDemoState extends State<_ToolResultDemo> {
  int _terminalRun = 0;
  int _requestRun = 0;
  int _concurrentRun = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel('Terminal output', colors: colors),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _TerminalRun(
                        key: ValueKey<int>(_terminalRun),
                        onReplay: () => setState(() => _terminalRun++),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _ReplayButton(
                        colors: colors,
                        onPressed: () => setState(() => _terminalRun++),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _SectionLabel('Request result', colors: colors),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _RequestRun(
                        key: ValueKey<int>(_requestRun),
                        onReplay: () => setState(() => _requestRun++),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _ReplayButton(
                        colors: colors,
                        onPressed: () => setState(() => _requestRun++),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              _SectionLabel('Cancelled', colors: colors),
              const SizedBox(height: 4),
              _SectionNote(
                'A run the user stopped. Neutral, not an error — the status '
                'role is `neutral`, and the actions stay reachable so it can '
                'be run again.',
                colors: colors,
              ),
              const SizedBox(height: 12),
              BeuiToolResult(
                tool: 'terminal.run',
                title: 'Migration was cancelled',
                kind: BeuiToolResultKind.terminal,
                status: BeuiToolResultStatus.cancelled,
                meta: '0.4s',
                collapseOnComplete: false,
                copyText: _cancelledOutput,
                onRetry: () {},
                child: const BeuiToolResultOutput(code: _cancelledOutput),
              ),

              const SizedBox(height: 32),
              _SectionLabel('Narrow header (two lines)', colors: colors),
              const SizedBox(height: 4),
              _SectionNote(
                'Under 400px the seven-element header wraps: title and status '
                'lead, metadata and the tool slug drop to a second line.',
                colors: colors,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 320,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: BeuiToolResult(
                        tool: 'http.request',
                        title: 'Fetching project activity',
                        kind: BeuiToolResultKind.request,
                        status: BeuiToolResultStatus.success,
                        meta: 'GET /v1/activity',
                        collapseOnComplete: false,
                        copyText: _narrowOutput,
                        onRetry: () {},
                        child: const BeuiToolResultOutput(
                          code: _narrowOutput,
                          language: BeuiCodeLanguage.json,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              _SectionLabel('Capped output', colors: colors),
              const SizedBox(height: 4),
              _SectionNote(
                'A 120px viewport over a 60-line log. The bottom fade and the '
                '"+N more" count only appear while content is actually below '
                'the fold — scroll to the end and both retire.',
                colors: colors,
              ),
              const SizedBox(height: 12),
              BeuiToolResult(
                tool: 'terminal.run',
                title: 'Building 60 modules',
                kind: BeuiToolResultKind.terminal,
                status: BeuiToolResultStatus.success,
                meta: '11.2s',
                maxHeight: 120,
                collapseOnComplete: false,
                copyText: _longOutput,
                child: BeuiToolResultOutput(code: _longOutput),
              ),

              const SizedBox(height: 32),
              _SectionLabel('Concurrent tool calls', colors: colors),
              const SizedBox(height: 4),
              _SectionNote(
                'Two tools running at once is a Column of BeuiToolResults in '
                'one message — each with its own status, its own body, and its '
                'own collapse. No extra component required.',
                colors: colors,
              ),
              const SizedBox(height: 12),
              _ConcurrentRun(
                key: ValueKey<int>(_concurrentRun),
                onReplay: () => setState(() => _concurrentRun++),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _ReplayButton(
                  colors: colors,
                  onPressed: () => setState(() => _concurrentRun++),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.colors});

  final String text;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: colors.mutedForeground,
      ),
    );
  }
}

class _SectionNote extends StatelessWidget {
  const _SectionNote(this.text, {required this.colors});

  final String text;
  final BeuiColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 18 / 12,
        color: colors.mutedForeground,
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton({required this.colors, required this.onPressed});

  final BeuiColors colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        LucideIcons.rotate_ccw,
        size: 12,
        color: colors.mutedForeground,
      ),
      label: Text(
        'Replay',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.mutedForeground,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: colors.mutedForeground,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Demo driver (source useToolResultDemo)
// ---------------------------------------------------------------------------

class _DemoDriver {
  _DemoDriver({
    required this.steps,
    this.interval = const Duration(milliseconds: 420),
    this.finalStatus = BeuiToolResultStatus.success,
    this.startDelay = Duration.zero,
  });

  final int steps;
  final Duration interval;
  final BeuiToolResultStatus finalStatus;
  final Duration startDelay;

  int visible = 0;
  BeuiToolResultStatus status = BeuiToolResultStatus.running;
  final List<Timer> _timers = [];

  void start(VoidCallback onTick) {
    cancel();
    visible = 0;
    status = BeuiToolResultStatus.running;
    for (var i = 0; i < steps; i++) {
      _timers.add(
        Timer(
          startDelay + interval * i + const Duration(milliseconds: 180),
          () {
            visible = i + 1;
            onTick();
          },
        ),
      );
    }
    _timers.add(
      Timer(
        startDelay + interval * steps + const Duration(milliseconds: 480),
        () {
          status = finalStatus;
          onTick();
        },
      ),
    );
  }

  void cancel() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

// ---------------------------------------------------------------------------
// Terminal preview
// ---------------------------------------------------------------------------

const _terminalLines = <String>[
  r'$ bun test tests/a11y.test.tsx',
  'bun test v1.3.14',
  '✓ StreamingResponse complete',
  '✓ ToolApproval pending',
  '✓ Citations expanded',
  '49 pass · 0 fail',
];

const _cancelledOutput =
    r'$ bun run db:migrate'
    '\nApplying 004_add_orders…'
    '\n^C  interrupted by user';

const _narrowOutput = '''{
  "status": 200,
  "events": 12
}''';

final String _longOutput = List<String>.generate(
  60,
  (i) => '[${(i + 1).toString().padLeft(2, '0')}/60] bundled module_$i.ts',
).join('\n');

class _TerminalRun extends StatefulWidget {
  const _TerminalRun({required this.onReplay, super.key});

  final VoidCallback onReplay;

  @override
  State<_TerminalRun> createState() => _TerminalRunState();
}

class _TerminalRunState extends State<_TerminalRun> {
  late final _DemoDriver _driver;

  @override
  void initState() {
    super.initState();
    _driver = _DemoDriver(steps: _terminalLines.length);
    _driver.start(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _driver.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final output = _terminalLines.take(_driver.visible).join('\n');
    final running = _driver.status == BeuiToolResultStatus.running;

    return BeuiToolResult(
      tool: 'terminal.run',
      title: running ? 'Running accessibility tests' : 'Tests passed',
      kind: BeuiToolResultKind.terminal,
      status: _driver.status,
      meta: _driver.status == BeuiToolResultStatus.success ? '2.9s' : null,
      copyText: output,
      onRetry: widget.onReplay,
      maxHeight: 150,
      child: BeuiToolResultOutput(code: output),
    );
  }
}

// ---------------------------------------------------------------------------
// Request preview
// ---------------------------------------------------------------------------

const _response = '''{
  "error": "rate_limit_exceeded",
  "retryAfter": 30,
  "requestId": "req_8f21"
}''';

class _RequestRun extends StatefulWidget {
  const _RequestRun({required this.onReplay, super.key});

  final VoidCallback onReplay;

  @override
  State<_RequestRun> createState() => _RequestRunState();
}

class _RequestRunState extends State<_RequestRun> {
  late final _DemoDriver _driver;

  @override
  void initState() {
    super.initState();
    _driver = _DemoDriver(
      steps: 3,
      interval: const Duration(milliseconds: 600),
      finalStatus: BeuiToolResultStatus.error,
    );
    _driver.start(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _driver.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = _driver.status == BeuiToolResultStatus.running;
    final Widget body;
    if (_driver.visible < 3) {
      final text = switch (_driver.visible) {
        0 => 'Preparing request…',
        1 => 'GET /v1/activity\nConnecting…',
        _ => 'GET /v1/activity\nWaiting for response…',
      };
      body = BeuiToolResultOutput(code: text);
    } else {
      body = const BeuiToolResultOutput(
        code: _response,
        language: BeuiCodeLanguage.json,
      );
    }

    return BeuiToolResult(
      tool: 'http.request',
      title: running ? 'Fetching project activity' : 'Request failed',
      kind: BeuiToolResultKind.request,
      status: _driver.status,
      meta: _driver.status == BeuiToolResultStatus.error
          ? '429'
          : 'GET /v1/activity',
      copyText: _response,
      onRetry: widget.onReplay,
      collapseOnComplete: false,
      maxHeight: 150,
      child: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Concurrent tool calls
// ---------------------------------------------------------------------------

const _grepLines = <String>[
  'src/checkout/submit.ts:14',
  'src/checkout/validate.ts:88',
  'src/checkout/index.ts:3',
];

const _typecheckLines = <String>[
  'tsc --noEmit',
  'src/checkout/validate.ts(88,7): error TS2345',
  '1 error',
];

/// Two tools in flight in a single message. Nothing here is a special
/// component — it is a [Column] of independent [BeuiToolResult]s, which is the
/// whole point.
class _ConcurrentRun extends StatefulWidget {
  const _ConcurrentRun({required this.onReplay, super.key});

  final VoidCallback onReplay;

  @override
  State<_ConcurrentRun> createState() => _ConcurrentRunState();
}

class _ConcurrentRunState extends State<_ConcurrentRun> {
  late final _DemoDriver _grep;
  late final _DemoDriver _typecheck;

  @override
  void initState() {
    super.initState();
    // Deliberately staggered: the two calls finish out of order, which is
    // exactly the case a single "tool group" component would flatten.
    _grep = _DemoDriver(
      steps: _grepLines.length,
      interval: const Duration(milliseconds: 320),
    );
    _typecheck = _DemoDriver(
      steps: _typecheckLines.length,
      interval: const Duration(milliseconds: 520),
      finalStatus: BeuiToolResultStatus.error,
      startDelay: const Duration(milliseconds: 400),
    );
    for (final driver in [_grep, _typecheck]) {
      driver.start(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _grep.cancel();
    _typecheck.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grepOut = _grepLines.take(_grep.visible).join('\n');
    final typeOut = _typecheckLines.take(_typecheck.visible).join('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BeuiToolResult(
          key: const ValueKey('grep'),
          tool: 'search.grep',
          title: _grep.status == BeuiToolResultStatus.running
              ? 'Searching for checkout call sites'
              : 'Found 3 call sites',
          kind: BeuiToolResultKind.custom,
          status: _grep.status,
          meta: _grep.status == BeuiToolResultStatus.success ? '0.6s' : null,
          maxHeight: 120,
          collapseOnComplete: false,
          copyText: grepOut,
          child: BeuiToolResultOutput(code: grepOut),
        ),
        const SizedBox(height: 8),
        BeuiToolResult(
          key: const ValueKey('typecheck'),
          tool: 'terminal.run',
          title: _typecheck.status == BeuiToolResultStatus.running
              ? 'Type-checking the workspace'
              : 'Type check failed',
          kind: BeuiToolResultKind.terminal,
          status: _typecheck.status,
          meta: _typecheck.status == BeuiToolResultStatus.error ? '3.1s' : null,
          maxHeight: 120,
          collapseOnComplete: false,
          copyText: typeOut,
          onRetry: widget.onReplay,
          child: BeuiToolResultOutput(code: typeOut),
        ),
      ],
    );
  }
}
