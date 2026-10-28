// Compiles every ```dart block in README.md against the current public API, so
// a renamed parameter or a changed type fails here instead of in a consumer's
// first copy-paste.
//
// Each block becomes the body of a function that has `context` and `setState`
// in scope, with `package:beui/beui.dart` and `package:flutter/material.dart`
// imported. Import lines in a block move to the top of its file. The files are
// written under .dart_tool/ so `package:beui` resolves, then analyzed with the
// SDK that runs this test. Errors and warnings fail; lints are ignored. A
// canary file with a known error proves the analyzer resolved package:beui and
// read the directory, so an empty report can't pass by accident.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'README dart snippets compile against the public API',
    () async {
      final readme = File('README.md').readAsLinesSync();
      final snippets = <({int line, List<String> body})>[];
      for (var i = 0; i < readme.length; i++) {
        if (readme[i].trim() != '```dart') continue;
        final start = i + 1;
        var end = start;
        while (readme[end].trim() != '```') {
          end++;
        }
        snippets.add((line: start + 1, body: readme.sublist(start, end)));
        i = end;
      }
      expect(snippets, isNotEmpty, reason: 'no ```dart blocks in README.md');

      final base = Directory('.dart_tool/readme_snippets')
        ..createSync(recursive: true);
      final dir = base.createTempSync('run-');
      addTearDown(() => dir.deleteSync(recursive: true));

      final canary = File('${dir.path}/canary.dart')
        ..writeAsStringSync(
          "import 'package:beui/beui.dart';\n"
          'final String canary = BeuiColorTheme.violet;\n',
        );
      // README line for each generated line, keyed by absolute file path.
      final readmeLines = <String, List<int?>>{};
      for (final (index, s) in snippets.indexed) {
        bool isImport(int k) => s.body[k].trimLeft().startsWith('import ');
        final body = [for (var k = 0; k < s.body.length; k++) k];
        final lines = <(String, int?)>[
          (
            '// ignore_for_file: type=lint, duplicate_import, unused_import, '
                'unused_local_variable, unused_element',
            null,
          ),
          ("import 'package:beui/beui.dart';", null),
          ("import 'package:flutter/material.dart';", null),
          for (final k in body.where(isImport)) (s.body[k], s.line + k),
          (
            'void readmeSnippet(BuildContext context, StateSetter setState) {',
            null,
          ),
          for (final k in body) (isImport(k) ? '' : s.body[k], s.line + k),
          ('}', null),
        ];
        final file = File('${dir.path}/snippet_$index.dart')
          ..writeAsStringSync(lines.map((l) => l.$1).join('\n'));
        readmeLines[file.absolute.path] = [for (final l in lines) l.$2];
      }

      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      final dart = flutterRoot == null ? 'dart' : '$flutterRoot/bin/dart';
      final result = await Process.run(dart, [
        'analyze',
        '--format=machine',
        dir.path,
      ]);
      final output = '${result.stdout}\n${result.stderr}';

      final problems = <String>[];
      final canaryCodes = <String>{};
      for (final row in output.split('\n')) {
        final f = row.split('|');
        if (f.length < 8 || !{'ERROR', 'WARNING'}.contains(f[0])) continue;
        final path = File(f[3]).absolute.path;
        if (path == canary.absolute.path) {
          canaryCodes.add(f[2]);
          continue;
        }
        final readmeLine = readmeLines[path]?[int.parse(f[4]) - 1];
        final at = readmeLine == null
            ? '$path:${f[4]}'
            : 'README.md:$readmeLine';
        problems.add('$at ${f[2]} ${f.sublist(7).join('|')}');
      }
      expect(canaryCodes, {
        'INVALID_ASSIGNMENT',
      }, reason: 'dart analyze missed the canary:\n$output');
      expect(
        problems,
        isEmpty,
        reason: 'README snippets no longer compile:\n${problems.join('\n')}',
      );
      // 3 is the analyzer's exit code for errors, the canary's included.
      // Anything else means it crashed or stopped early.
      expect(result.exitCode, 3, reason: 'dart analyze failed:\n$output');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
