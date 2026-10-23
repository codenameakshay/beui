import 'package:flutter/material.dart';
import 'package:beui/src/motion/combobox.dart';
import 'package:beui/src/theme/beui_colors.dart';
import 'package:beui/src/theme/beui_text_theme.dart';
Widget _testApp(Widget child, {bool reduce = false}) => MaterialApp(
  theme: BeuiTextTheme.trackingNormal(
    ThemeData.light().copyWith(
      extensions: <ThemeExtension<dynamic>>[BeuiColors.light()],
    ),
  ),
  home: Scaffold(
    body: Center(
      child: reduce
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child,
              ),
            )
          : child,
    ),
  ),
);

Widget fixture({
  ValueChanged<String>? onValueChange,
  ValueChanged<bool>? onOpenChange,
  ValueChanged<String>? onQueryChange,
  String? value,
  String? defaultValue,
  bool? open,
  bool defaultOpen = false,
  String? query,
  String defaultQuery = '',
  bool reduce = false,
}) => _testApp(
  SizedBox(
    width: 260,
    child: BeuiCombobox(
      value: value,
      defaultValue: defaultValue,
      onValueChange: onValueChange,
      open: open,
      defaultOpen: defaultOpen,
      onOpenChange: onOpenChange,
      query: query,
      defaultQuery: defaultQuery,
      onQueryChange: onQueryChange,
      trigger: const BeuiComboboxTrigger(
        child: BeuiComboboxInput(label: 'Search fruits'),
      ),
      content: const BeuiComboboxContent(
        child: BeuiComboboxList(
          ariaLabel: 'Fruits',
          children: <Widget>[
            BeuiComboboxEmpty(child: Text('Nothing found')),
            BeuiComboboxGroup(
              label: 'Fresh',
              children: <Widget>[
                BeuiComboboxItem(
                  value: 'apple',
                  textValue: 'Apple',
                  keywords: <String>['red fruit'],
                  child: Text('Apple'),
                ),
                BeuiComboboxItem(
                  value: 'banana',
                  textValue: 'Banana',
                  child: Text('Banana'),
                ),
                BeuiComboboxItem(
                  value: 'cherry',
                  textValue: 'Cherry',
                  disabled: true,
                  child: Text('Cherry'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
  reduce: reduce,
);


void main() { runApp(fixture(onOpenChange: (v) => debugPrint('EVENT open:$v'), onQueryChange: (v) => debugPrint('EVENT query:$v'), onValueChange: (v) => debugPrint('EVENT value:$v'))); }
