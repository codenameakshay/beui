import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiToolApproval] — mirrors the source docs preview:
/// a terminal-run permission card that progresses through approve → running
/// → complete (or deny), with a Replay control.
Widget toolApprovalDemo(BuildContext context) => const _ToolApprovalDemo();

class _ToolApprovalDemo extends StatefulWidget {
  const _ToolApprovalDemo();

  @override
  State<_ToolApprovalDemo> createState() => _ToolApprovalDemoState();
}

class _ToolApprovalDemoState extends State<_ToolApprovalDemo> {
  int _run = 0;

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
              Text(
                'Permission card',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 360,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: _ApprovalRun(key: ValueKey<int>(_run)),
                    ),
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _ReplayButton(
                        colors: colors,
                        onPressed: () => setState(() => _run++),
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
// Live preview driver (source ToolApprovalPreview)
// ---------------------------------------------------------------------------

class _ApprovalRun extends StatefulWidget {
  const _ApprovalRun({super.key});

  @override
  State<_ApprovalRun> createState() => _ApprovalRunState();
}

class _ApprovalRunState extends State<_ApprovalRun> {
  BeuiToolApprovalStatus _status = BeuiToolApprovalStatus.pending;
  bool _detailsOpen = true;
  final List<Timer> _timers = [];

  void _clearTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void dispose() {
    _clearTimers();
    super.dispose();
  }

  void _finish(BeuiToolApprovalStatus next) {
    _clearTimers();
    setState(() => _status = next);
  }

  void _approve() {
    _clearTimers();
    setState(() => _status = BeuiToolApprovalStatus.approving);
    _timers.addAll([
      Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _status = BeuiToolApprovalStatus.approved);
        }
      }),
      Timer(const Duration(milliseconds: 1150), () {
        if (mounted) {
          setState(() => _status = BeuiToolApprovalStatus.running);
        }
      }),
      Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _status = BeuiToolApprovalStatus.complete);
        }
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pending = _status == BeuiToolApprovalStatus.pending;

    return BeuiToolApproval(
      tool: 'terminal.run',
      title: pending ? 'Allow this tool to run?' : 'Terminal access',
      description:
          'The agent wants to run the project test suite in the current workspace.',
      status: _status,
      open: _detailsOpen,
      onOpenChange: (v) => setState(() => _detailsOpen = v),
      parameters: const [
        BeuiToolApprovalParameter(
          id: 'command',
          label: 'Command',
          value: BeuiToolApprovalCode(
            code: 'bun test tests/a11y.test.tsx',
            language: BeuiCodeLanguage.bash,
          ),
        ),
        BeuiToolApprovalParameter(
          id: 'directory',
          label: 'Directory',
          value: 'ui-components',
        ),
      ],
      onApprove: _approve,
      onAlwaysAllow: _approve,
      onDeny: () => _finish(BeuiToolApprovalStatus.denied),
    );
  }
}
