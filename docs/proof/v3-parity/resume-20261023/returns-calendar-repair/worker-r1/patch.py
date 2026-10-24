from pathlib import Path
p=Path('lib/src/charts/returns_calendar.dart');s=p.read_text();s=s.replace('                  Row(\n                    children: [\n                      SizedBox(', '                  Row(\n                    key: ValueKey(state.widget.years[y]),\n                    children: [\n                      SizedBox(')
s=s.replace('              key: ValueKey(cellKey),\n              focusNode:', '              focusNode:')
s=s.replace('              child: BeuiFocusRing(\n                focused:', '              child: BeuiFocusRing(\n                key: ValueKey(cellKey),\n                focused:')
s=s.replace('  final _focus = FocusNode();\n  @override', '''  final _focus = FocusNode();

  @override
  void deactivate() {
    // DOM removal does not restore a previously visited control. Clear the
    // enclosing scope history before Flutter detaches this focused cell.
    if (_focus.hasPrimaryFocus) _focus.unfocus();
    super.deactivate();
  }

  @override''')
p.write_text(s)
