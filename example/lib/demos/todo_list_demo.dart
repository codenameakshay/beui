import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiTodoList] — mirrors the source preview: an
/// auto-advancing implementation plan with morphing status marks, a rolling
/// completion count, and a Replay control.
Widget todoListDemo(BuildContext context) => const _TodoListDemo();

class _TodoListDemo extends StatefulWidget {
  const _TodoListDemo();

  @override
  State<_TodoListDemo> createState() => _TodoListDemoState();
}

class _TodoListDemoState extends State<_TodoListDemo> {
  static const _tasks = <String>[
    'Inspect the current data flow',
    'Update the response schema',
    'Add coverage for edge cases',
    'Run checks and prepare the result',
  ];

  static const _ticksPerTask = 4;

  int _run = 0;
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _armTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = null;
    if (_step >= _tasks.length * _ticksPerTask) return;
    _timer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _step += 1);
      _armTimer();
    });
  }

  void _replay() {
    setState(() {
      _run += 1;
      _step = 0;
    });
    _armTimer();
  }

  List<BeuiTodoItem> _itemsAtStep(int step) {
    return [
      for (var index = 0; index < _tasks.length; index++)
        BeuiTodoItem(
          id: 'task-$index',
          title: Text(_tasks[index]),
          status: step >= (index + 1) * _ticksPerTask
              ? BeuiTodoItemStatus.completed
              : step >= index * _ticksPerTask
              ? BeuiTodoItemStatus.inProgress
              : BeuiTodoItemStatus.pending,
          progress:
              step >= index * _ticksPerTask &&
                  step < (index + 1) * _ticksPerTask
              ? ((step % _ticksPerTask) + 1) * 25.0
              : null,
          detail:
              step >= index * _ticksPerTask &&
                  step < (index + 1) * _ticksPerTask
              ? Text('${((step % _ticksPerTask) + 1) * 25}%')
              : null,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<BeuiColors>()!;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512), // max-w-lg
        child: SizedBox(
          height: 330,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: BeuiTodoList(
                  key: ValueKey<int>(_run),
                  items: _itemsAtStep(_step),
                  title: const Text('Implementation plan'),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                child: TextButton.icon(
                  onPressed: _replay,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
