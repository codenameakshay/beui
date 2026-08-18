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
              const SizedBox(height: 32),
              _SectionLabel('Severity tiers', colors: colors),
              const SizedBox(height: 12),
              const _SeverityTiers(),
              const SizedBox(height: 32),
              _SectionLabel('Lapsed end-states', colors: colors),
              const SizedBox(height: 12),
              const _LapsedStates(),
              const SizedBox(height: 32),
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
  BeuiToolApprovalGrant? _grant;
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

  void _approve(BeuiToolApprovalGrant grant) {
    _clearTimers();
    setState(() {
      _grant = grant;
      _status = BeuiToolApprovalStatus.approving;
    });
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
      // Recording which grant was used is what lets the approved card say
      // "Always allowed" instead of a bare "Approved", and what makes the
      // Revoke affordance meaningful.
      grant: _grant,
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
      onApprove: () => _approve(BeuiToolApprovalGrant.once),
      onAlwaysAllow: () => _approve(BeuiToolApprovalGrant.always),
      onDeny: () => _finish(BeuiToolApprovalStatus.denied),
      onRevoke: _grant == BeuiToolApprovalGrant.always
          ? () => setState(() {
              _grant = null;
              _status = BeuiToolApprovalStatus.pending;
            })
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Severity tiers (A3)
// ---------------------------------------------------------------------------

/// The three risk tiers side by side.
///
/// The point of the route is the comparison: before the severity API existed,
/// `rm -rf ~/project` and `ls` rendered byte-identically, so the card could
/// not warn. Note what changes on the destructive tier — warning glyph,
/// tinted emphasis border, `Deny` promoted to the solid lead action,
/// `Allow once` demoted to outlined, and `Always allow` gone entirely.
class _SeverityTiers extends StatelessWidget {
  const _SeverityTiers();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiToolApproval(
          tool: 'fs.readFile',
          title: 'Read a project file?',
          description: 'Reversible, scoped to the workspace.',
          parameters: const [
            BeuiToolApprovalParameter(
              id: 'path',
              label: 'Path',
              value: 'src/components/button.tsx',
            ),
          ],
          onApprove: () {},
          onAlwaysAllow: () {},
          onDeny: () {},
        ),
        const SizedBox(height: 16),
        BeuiToolApproval(
          tool: 'git.push',
          title: 'Push to the shared branch?',
          description: 'Affects other people, but can be reverted.',
          severity: BeuiToolApprovalSeverity.elevated,
          parameters: const [
            BeuiToolApprovalParameter(
              id: 'remote',
              label: 'Remote',
              value: 'origin main',
            ),
          ],
          onApprove: () {},
          onAlwaysAllow: () {},
          onDeny: () {},
        ),
        const SizedBox(height: 16),
        BeuiToolApproval(
          tool: 'fs.remove',
          title: 'Delete the project directory?',
          description: 'This cannot be undone.',
          severity: BeuiToolApprovalSeverity.destructive,
          parameters: const [
            BeuiToolApprovalParameter(
              id: 'command',
              label: 'Command',
              value: BeuiToolApprovalCode(
                code: 'rm -rf ~/project',
                language: BeuiCodeLanguage.bash,
              ),
            ),
          ],
          onApprove: () {},
          // Wired, and still suppressed — a standing grant for a destructive
          // capability is not offered in passing.
          onAlwaysAllow: () {},
          onDeny: () {},
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Lapsed end-states (A21)
// ---------------------------------------------------------------------------

/// `expired` (never ran — the window closed) and `timedOut` (ran, but was cut
/// off). Both are terminal and neither shows an action row.
class _LapsedStates extends StatelessWidget {
  const _LapsedStates();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeuiToolApproval(
          tool: 'terminal.run',
          title: 'Terminal access',
          description: 'The request lapsed before anyone answered it.',
          status: BeuiToolApprovalStatus.expired,
          onApprove: () {},
          onDeny: () {},
        ),
        const SizedBox(height: 16),
        BeuiToolApproval(
          tool: 'http.request',
          title: 'Fetch project activity',
          description: 'Approved, then cut off at the execution budget.',
          status: BeuiToolApprovalStatus.timedOut,
          grant: BeuiToolApprovalGrant.once,
          onApprove: () {},
          onDeny: () {},
        ),
      ],
    );
  }
}
