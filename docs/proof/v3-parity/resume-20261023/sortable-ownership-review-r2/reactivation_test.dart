import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beui/src/motion/sortable_list.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'original_probe_test.dart' as p;

void main() {
  testWidgets('same cached root reactivation restores Undo registry and node identity', (t) async {
    final external = FocusNode();
    addTearDown(external.dispose);
    var wrapped = false;
    late StateSetter update;
    final changes = <List<String>>[];
    final cachedRoot = BeuiSortableList<String>(
      key: GlobalKey(),
      defaultItems: const ['A', 'B', 'C'],
      getItemId: (id) => id,
      getItemLabel: (id) => id,
      onItemsChange: changes.add,
      children: (ids) => Column(mainAxisSize: MainAxisSize.min, children: [
        BeuiSortableListGroup(children: [for (final id in ids)
          BeuiSortableListItem(id: id, child: BeuiSortableListHandle(child: Text('$id-first'))),
        ]),
        const BeuiSortableListUndo(),
      ]),
    );
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [BeuiColors.light()]),
      home: Scaffold(body: StatefulBuilder(builder: (context, set) {
        update = set;
        return Column(children: [
          if (wrapped) Padding(padding: const EdgeInsets.all(1), child: cachedRoot) else cachedRoot,
          TextButton(focusNode: external, onPressed: () {}, child: const Text('Outside')),
        ]);
      })),
    ));
    await p.focus(t, 'A-first');
    final original = p.node(t, 'A-first');
    await p.key(t, LogicalKeyboardKey.end);
    expect(changes, [['B', 'C', 'A']]);
    for (final target in [true, false, true]) {
      update(() => wrapped = target);
      await t.pumpAndSettle();
      expect(p.node(t, 'A-first'), same(original));
      external.requestFocus();
      await t.pump();
      p.undo(t)();
      await t.pumpAndSettle();
      expect(original.hasPrimaryFocus, isTrue);
      expect(changes.last, ['A', 'B', 'C']);
      await p.key(t, LogicalKeyboardKey.end);
      expect(changes.last, ['B', 'C', 'A']);
    }
    await t.pumpWidget(const SizedBox());
    expect(original.parent, isNull);
    expect(original.hasFocus, isFalse);
  });
}
