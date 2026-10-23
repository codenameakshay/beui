import { mkdir, writeFile } from 'node:fs/promises';
import { spawnSync, execFileSync } from 'node:child_process';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '../../../../..');
const output = path.join(import.meta.dirname, process.argv[2] || 'checks');
await mkdir(output);
const files = [
  'card_folder', 'project_folder', 'morphing_tabs', 'prediction_market_card',
  'digit_swap', 'text_scramble', 'number_ticker', 'animated_number',
  'text_reveal', 'text_shimmer', 'text_cascade', 'chromatic_text_reveal',
  'notification_stack', 'dynamic_island', 'availability_scheduler',
  'morphing_search', 'morphing_search_chips', 'prediction_market',
  'bloom_menu', 'feedback_widget', 'dock', 'knockout_bracket',
  'knockout_wheel', 'signup_form', 'infinite_masonry', 'wallet_card',
].map(name => `test/motion/${name}_test.dart`);
const commands = [
  { name: 'owned-tests', cwd: root, args: ['test', ...files, '--name', '^(?!.*golden)'] },
  { name: 'example-tests', cwd: path.join(root, 'example'), args: ['test', 'test/block_parity_round2_test.dart'] },
  { name: 'root-analysis', cwd: root, args: ['analyze'] },
  { name: 'example-analysis', cwd: path.join(root, 'example'), args: ['analyze'] },
];
const results = [];
for (const command of commands) {
  const run = spawnSync('flutter', command.args, { cwd: command.cwd, encoding: 'utf8', maxBuffer: 30*1024*1024 });
  await writeFile(path.join(output, `${command.name}.log`), `${run.stdout}\n${run.stderr}\nexit=${run.status}\n`);
  results.push({ ...command, exit: run.status, signal: run.signal });
}
await writeFile(path.join(output, 'commands.json'), JSON.stringify({ head: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: root, encoding: 'utf8' }).trim(), files: files.length, results }, null, 2));
console.log(JSON.stringify(results.map(({ name, exit }) => ({ name, exit })), null, 2));
if (results.some(r => r.exit !== 0)) process.exitCode = 1;
