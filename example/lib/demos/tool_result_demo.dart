import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiToolResult] — mirrors the source docs previews:
/// a streaming terminal run that collapses on complete, and a request result
/// that ends in error with retry / copy chrome.
Widget toolResultDemo(BuildContext context) => const _ToolResultDemo();

class _ToolResultDemo extends StatefulWidget {
  const _ToolResultDemo();

  @override
  State<_ToolResultDemo> createState() => _ToolResultDemoState();
}

class _ToolResultDemoState extends State<_ToolResultDemo> {
  int _terminalRun = 0;
  int _requestRun = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 512),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Terminal output',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
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
              Text(
                'Request result',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 280,
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
            ],
          ),
        ),
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
  });

  final int steps;
  final Duration interval;
  final BeuiToolResultStatus finalStatus;

  int visible = 0;
  BeuiToolResultStatus status = BeuiToolResultStatus.running;
  final List<Timer> _timers = [];

  void start(VoidCallback onTick) {
    cancel();
    visible = 0;
    status = BeuiToolResultStatus.running;
    for (var i = 0; i < steps; i++) {
      _timers.add(
        Timer(interval * i + const Duration(milliseconds: 180), () {
          visible = i + 1;
          onTick();
        }),
      );
    }
    _timers.add(
      Timer(interval * steps + const Duration(milliseconds: 480), () {
        status = finalStatus;
        onTick();
      }),
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
