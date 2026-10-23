from pathlib import Path
p=Path('test/charts/returns_calendar_native_regression_test.dart');s=p.read_text();s=s.replace("    expect(node(t, 0, 12).hasPrimaryFocus, isTrue);\n  });\n  testWidgets('global", """    expect(node(t, 0, 12).hasPrimaryFocus, isTrue);
    node(t, 1, 2).requestFocus();
    await t.pumpAndSettle();
    await show(1, [2024, 2040]);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 1, 0).hasPrimaryFocus, isTrue);
  });
  testWidgets('global""")
s=s.replace("    expect(old.hasPrimaryFocus, isTrue);\n  });", """    expect(old.hasPrimaryFocus, isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pumpAndSettle();
    expect(node(t, 1, 3).hasPrimaryFocus, isTrue);
    await show(false);
    expect(node(t, 1, 2), same(old));
    expect(node(t, 1, 3).hasPrimaryFocus, isTrue);
  });""",1)
a=s.index("  testWidgets('duplicate years render'");b=s.index("  testWidgets('outside focus",a)
s=s[:a]+"""  testWidgets('duplicate years have distinct stable occurrence identities', (t) async {
    Future<void> show(List<int> years) async {
      await t.pumpWidget(beuiTestApp(BeuiReturnsCalendar(years: years), reduce: true));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    await show([2024, 2024, 2025]);
    final first = node(t, 0, 2);
    final second = node(t, 1, 2);
    expect(first, isNot(same(second)));
    second.requestFocus();
    await t.pumpAndSettle();
    await show([2025, 2024, 2024]);
    expect(node(t, 1, 2), same(first));
    expect(node(t, 2, 2), same(second));
    expect(second.hasPrimaryFocus, isTrue);
    await show([2025, 2024, 2030]);
    expect(second.context?.mounted, isFalse);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pumpAndSettle();
    expect(node(t, 1, 12).hasPrimaryFocus, isTrue);
    expect(node(t, 1, 2), same(first));
  });
"""+s[b:];p.write_text(s)
