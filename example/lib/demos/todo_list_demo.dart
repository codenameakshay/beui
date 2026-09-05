import 'dart:async';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

import '../explorer/widgets.dart';

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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512), // max-w-lg
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
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
                    child: ReplayButton(onPressed: _replay),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const SectionLabel('Empty · before the agent has planned'),
            const SizedBox(height: 12),
            // An empty task list is a normal state, not an error — the
            // description says what will appear here and when, so the panel
            // orients instead of shrugging.
            const BeuiTodoList(
              items: [],
              title: Text('Implementation plan'),
              emptyDescription:
                  'The agent posts its plan here before it starts work, and '
                  'ticks tasks off as it goes.',
            ),
            const SizedBox(height: 32),
            const SectionLabel('Cancelled and pending rows'),
            const SizedBox(height: 12),
            const BeuiTodoList(
              collapseOnComplete: false,
              title: Text('Migration plan'),
              items: [
                BeuiTodoItem(
                  id: 'a',
                  title: Text('Inspect the current data flow'),
                  status: BeuiTodoItemStatus.completed,
                ),
                BeuiTodoItem(
                  id: 'b',
                  title: Text('Update the response schema'),
                  status: BeuiTodoItemStatus.inProgress,
                  progress: 40,
                  detail: Text('40%'),
                ),
                BeuiTodoItem(
                  id: 'c',
                  title: Text('Add coverage for edge cases'),
                  status: BeuiTodoItemStatus.pending,
                ),
                BeuiTodoItem(
                  id: 'd',
                  title: Text('Backfill the legacy rows'),
                  status: BeuiTodoItemStatus.cancelled,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
