import 'dart:io';

import 'package:beui/beui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('beuiVersion matches the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml has no version: line');
    expect(beuiVersion, match!.group(1));
  });
}
