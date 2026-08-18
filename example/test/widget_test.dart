import 'package:beui/beui.dart';
import 'package:beui_example/explorer/catalog.dart';
import 'package:beui_example/explorer/explorer_app.dart';
import 'package:beui_example/explorer/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gallery URL query string opens the matching route', () {
    expect(
      explorerRouteFromUri(Uri.parse('https://example/?page=guides')),
      isA<GuidesRoute>(),
    );
    expect(
      explorerRouteFromUri(Uri.parse('https://example/?section=agents')),
      isA<IndexRoute>().having(
        (r) => r.section,
        'section',
        ExploreSection.agents,
      ),
    );
    final detail = explorerRouteFromUri(
      Uri.parse('https://example/?slug=chat-app'),
    );
    expect(detail, isA<DetailRoute>());
    expect((detail as DetailRoute).entry.slug, 'chat-app');
    expect(
      explorerBrightnessFromUri(Uri.parse('https://example/?theme=light')),
      Brightness.light,
    );
    expect(
      explorerColorThemeFromUri(Uri.parse('https://example/?color=violet')),
      BeuiColorTheme.violet,
    );
  });

  testWidgets('explorer boots on the Components index', (tester) async {
    // Desktop surface so the fixed sidebar (not the drawer) renders.
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const BeuiExplorerApp());
    await tester.pump();

    // The wordmark and the Components heading render.
    expect(find.text('beUI'), findsWidgets);
    expect(find.text('Components'), findsWidgets);
    // The Components section count renders near the top of the sidebar. Read it
    // off the catalog rather than hardcoding: this assertion silently rotted
    // once already when the catalog grew past the literal it was written with.
    // (Blocks' count is below the fold in the lazy ListView, so not asserted.)
    expect(find.text('${kComponents.length}'), findsOneWidget);
    // A known sidebar entry is present.
    expect(find.text('Switch'), findsWidgets);
  });
}
