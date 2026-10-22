import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The root test exercises the actual gallery caller in the example package.
// ignore: avoid_relative_lib_imports
import '../../example/lib/demos/image_viewer_demo.dart';
import '../support.dart';

void main() {
  testWidgets('photo demo opens, navigates, closes, and reopens the viewer', (
    tester,
  ) async {
    final previousProvider = debugNetworkImageHttpClientProvider;
    debugNetworkImageHttpClientProvider = () => _ImageHttpClient();
    addTearDown(() {
      debugNetworkImageHttpClientProvider = previousProvider;
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });

    await tester.pumpWidget(
      beuiTestApp(Builder(builder: imageViewerDemo), width: 400),
    );
    final context = tester.element(find.byType(BeuiImageViewer));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = previousProvider;

    expect(find.byType(BeuiImageViewerThumbnail), findsNWidgets(3));
    expect(find.byType(RawImage), findsNWidgets(3));
    for (final image in tester.widgetList<RawImage>(find.byType(RawImage))) {
      expect(image.image, isNotNull);
    }
    expect(find.text('01 / Form and light'), findsNothing);
    expect(find.byTooltip('Close viewer'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Open Sculptural architecture'));
    await tester.pumpAndSettle();
    expect(find.text('01 / Form and light'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Next image'));
    await tester.pumpAndSettle();
    expect(find.text('01 / Form and light'), findsNothing);
    expect(find.text('02 / A little room to breathe'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close viewer'));
    await tester.pumpAndSettle();
    expect(find.text('02 / A little room to breathe'), findsNothing);
    expect(find.byTooltip('Close viewer'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Open Sculptural architecture'));
    await tester.pumpAndSettle();
    expect(find.text('01 / Form and light'), findsOneWidget);
    expect(find.text('02 / A little room to breathe'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close viewer'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close viewer'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ImageHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _ImageHttpRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageHttpRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _ImageHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  // Flutter's test/image_data.dart kTransparentImage, a valid 1x1 RGBA PNG.
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gMQFwcdLl4wmwAAAAtJREFUCNdjYAACAAAFAAHiJgWbAAAAAElFTkSuQmCC',
  );

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _png.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_png).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
