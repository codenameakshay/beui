import 'package:beui/beui.dart';
import 'package:flutter/material.dart';

/// Gallery route for [BeuiSortableList].
Widget sortableStackDemo(BuildContext context) => const _SortableStackDemo();

class _SortableStackDemo extends StatefulWidget {
  const _SortableStackDemo();

  @override
  State<_SortableStackDemo> createState() => _SortableStackDemoState();
}

class _SortableStackDemoState extends State<_SortableStackDemo> {
  var _tasks = List<_Task>.of(_initialTasks);

  @override
  Widget build(BuildContext context) => BeuiSortableList<_Task>(
    items: _tasks,
    getItemId: (task) => task.id,
    getItemLabel: (task) => task.title,
    onItemsChange: (tasks) => setState(() => _tasks = tasks),
    label: 'Studio priorities',
    children: (items) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IN THE STUDIO',
                      style: TextStyle(fontSize: 10, letterSpacing: 1.5),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Make room for what matters.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text('${items.length.toString().padLeft(2, '0')} tasks'),
            ],
          ),
        ),
        BeuiSortableListGroup(
          children: [
            for (var index = 0; index < items.length; index++)
              BeuiSortableListItem(
                id: items[index].id,
                child: Row(
                  children: [
                    const BeuiSortableListHandle(),
                    const SizedBox(width: 8),
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: items[index].tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(items[index].icon, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BeuiSortableListItemContent(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(items[index].detail),
                          ],
                        ),
                      ),
                    ),
                    Text((index + 1).toString().padLeft(2, '0')),
                    const SizedBox(width: 8),
                    const Icon(Icons.circle_outlined, size: 14),
                  ],
                ),
              ),
          ],
        ),
        const BeuiSortableListUndo(),
      ],
    ),
  );
}

class _Task {
  const _Task(this.id, this.title, this.detail, this.icon, this.tint);

  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final Color tint;
}

const _initialTasks = [
  _Task(
    'research',
    'Collect references',
    'Find the right direction',
    Icons.description_outlined,
    Color(0xfffff1d6),
  ),
  _Task(
    'design',
    'Explore the visual system',
    'Type, color, and composition',
    Icons.palette_outlined,
    Color(0xffffe9eb),
  ),
  _Task(
    'build',
    'Build the first prototype',
    'Make the interaction tangible',
    Icons.layers_outlined,
    Color(0xffe5efff),
  ),
  _Task(
    'ship',
    'Ship something useful',
    'Polish the details and release',
    Icons.rocket_launch_outlined,
    Color(0xffe2f5e8),
  ),
];
