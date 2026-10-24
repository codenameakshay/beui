import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../table-followup/candidate.dart' as fixture;

@JS('__readTableBaselines')
external set _readTableBaselines(JSFunction callback);

void main() {
  fixture.main();
  _readTableBaselines = (() {
    final rows = <Map<String, Object?>>[];
    void visit(Element element) {
      if (element.widget is RichText) {
        final render = element.findRenderObject();
        if (render is RenderParagraph && render.hasSize) {
          final text = render.text.toPlainText();
          if (text == 'Name' ||
              text == 'Leo Marsh' ||
              text == 'leo.marsh211@beui.dev' ||
              text == 'Suspended') {
            final origin = render.localToGlobal(Offset.zero);
            rows.add({
              'text': text,
              'x': origin.dx,
              'y': origin.dy,
              'width': render.size.width,
              'height': render.size.height,
              'baseline':
                  origin.dy +
                  render.getDryBaseline(
                    render.constraints,
                    TextBaseline.alphabetic,
                  )!,
              'style': render.text.style.toString(),
            });
          }
        }
      }
      element.visitChildren(visit);
    }

    final root = WidgetsBinding.instance.rootElement;
    if (root != null) visit(root);
    return jsonEncode(rows).toJS;
  }).toJS;
}
