import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const source = '/tmp/beui-charts-reference-20261023';
const files = [
  `${source}/app/layout.tsx`,
  `${source}/app/globals.css`,
  `${source}/components/motion/command-palette.tsx`,
  `${source}/components/agents/code-block.tsx`,
  `${source}/components/charts/order-book.tsx`,
  'lib/src/theme/beui_text_theme.dart',
  'lib/src/theme/beui_agent_theme.dart',
  'example/lib/explorer/explorer_app.dart',
  'example/pubspec.yaml',
  'docs/PORTING_SPEC.md',
];
const records = [];
for (const path of files) {
  const bytes = await readFile(path);
  records.push({ path, sha256: createHash('sha256').update(bytes).digest('hex'),
    usage: bytes.toString().split('\n').flatMap((text, index) =>
      /Geist|JetBrains|\bInter\b|font-family|fontFamily|font-sans|font-mono|sans\.variable|mono\.variable/.test(text)
        ? [{ line: index + 1, text }] : []) });
}
console.log(JSON.stringify({
  sourceCommit: execFileSync('git', ['-C', source, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  sourceStatus: execFileSync('git', ['-C', source, 'status', '--short'], { encoding: 'utf8' }).trim(),
  flutterCommit: execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(),
  records,
}, null, 2));
