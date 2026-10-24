import 'dart:js_interop';

import 'package:flutter/material.dart';

extension type _ImageElement(JSObject object) implements JSObject {
  external set src(JSString value);
  external set alt(JSString value);
  external set width(JSNumber value);
  external set height(JSNumber value);
  external set referrerPolicy(JSString value);
  external _ImageStyle get style;
  external JSPromise<JSAny?> decode();
}

extension type _ImageStyle(JSObject object) implements JSObject {
  external set objectFit(JSString value);
  external set borderRadius(JSString value);
  external set pointerEvents(JSString value);
}

Widget providerFavicon(String url, Widget fallback) =>
    _ProviderFavicon(url: url, fallback: fallback);

class _ProviderFavicon extends StatefulWidget {
  const _ProviderFavicon({required this.url, required this.fallback});

  final String url;
  final Widget fallback;

  @override
  State<_ProviderFavicon> createState() => _ProviderFaviconState();
}

class _ProviderFaviconState extends State<_ProviderFavicon> {
  bool _failed = false;

  @override
  void didUpdateWidget(_ProviderFavicon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    final requested = widget.url;
    return ExcludeSemantics(
      child: HtmlElementView.fromTagName(
        key: ValueKey(requested),
        tagName: 'img',
        onElementCreated: (element) {
          final image = _ImageElement(element as JSObject)
            ..alt = ''.toJS
            ..width = 16.toJS
            ..height = 16.toJS
            ..referrerPolicy = 'no-referrer'.toJS
            ..src = requested.toJS;
          image.style
            ..objectFit = 'contain'.toJS
            ..borderRadius = '2px'.toJS
            ..pointerEvents = 'none'.toJS;
          image.decode().toDart.then(
            (_) {},
            onError: (Object error, StackTrace stack) {
              if (mounted && widget.url == requested) {
                setState(() => _failed = true);
              }
            },
          );
        },
      ),
    );
  }
}
