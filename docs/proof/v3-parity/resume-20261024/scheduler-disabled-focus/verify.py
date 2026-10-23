#!/usr/bin/env python3
"""Verify archived bytes separately from recorded behavior. Does not rerun Chrome."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parent
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = json.loads((root / 'manifest.json').read_text())
errors = [name for name, expected in manifest.items()
          if not (root / name).is_file() or sha(root / name) != expected]
identity = json.loads((root / 'identity.json').read_text())
for name, expected in identity['builds'].items():
    if sha(root / name) != expected:
        errors.append('build ' + name)
for item in json.loads((root / 'source-inputs.json').read_text())['inputs']:
    if sha(root / item['archivePath']) != item['sha256']:
        errors.append('source input ' + item['archivePath'])
for item in json.loads((root / 'source-pin-check.json').read_text()):
    if not item['matchesArchived'] or item['pinSha256'] != item['workingSha256']:
        errors.append('source pin ' + item['file'])
behavior_errors = []
runs = []
for batch, build, expect_defect in [
    ('baseline-source', 'builds/source/source.js', False),
    ('baseline-candidate-retry', 'builds/baseline-candidate/main.dart.js', True),
    ('final-candidate', 'builds/final-candidate/main.dart.js', False),
]:
    paths = sorted((root / batch).glob('*/results.json'))
    if len(paths) != 4:
        behavior_errors.append(batch + ': expected four owner/motion runs')
    for path in paths:
        data = json.loads(path.read_text())
        run = str(path.parent.relative_to(root))
        main = [s for s in data['scripts'] if s['url'].endswith('/' + Path(build).name)]
        if not main or any(s['sha256'] != identity['builds'][build] for s in main):
            errors.append(run + ': served/build mismatch')
        for script in data['scripts']:
            if sha(root / 'served' / script['sha256']) != script['sha256']:
                errors.append(run + ': served bytes')
        for state in data['states']:
            if sha(path.parent / state['screenshot']['file']) != state['screenshot']['sha256']:
                errors.append(run + ': screenshot ' + state['name'])
        trusted = [e for e in data['inputs'] if e['type'] in ['keydown', 'keyup', 'pointerdown', 'pointerup']]
        synthetic = []
        for event in trusted:
            if event['isTrusted']:
                continue
            # motion-dom emits synthetic press events from trusted Enter.
            key_type = {'pointerdown': 'keydown', 'pointerup': 'keyup'}.get(event['type'])
            from_enter = (data['target'] == 'source' and data['reducedMotion'] == 'no-preference'
                          and event.get('label') == 'Copy Monday hours to other days'
                          and event.get('x') == 0 and event.get('y') == 0
                          and any(k['type'] == key_type and k.get('key') == 'Enter'
                                  and k['isTrusted'] and k.get('label') == event.get('label')
                                  and 0 <= event['time'] - k['time'] < 50
                                  for k in trusted))
            if from_enter:
                synthetic.append(event)
            else:
                behavior_errors.append(run + ': unexpected untrusted input')
        if not any(e['isTrusted'] and e['type'] == 'pointerdown' for e in trusted):
            behavior_errors.append(run + ': no trusted pointer input')
        states = {s['name']: s for s in data['states']}
        after = states.get('disabled-enter', {}).get('fixture', {})
        calls = after.get('calls')
        if expect_defect:
            if not calls or len(calls) != 1 or calls[0]['fri'] != {'enabled': False, 'ranges': []}:
                behavior_errors.append(run + ': baseline defect not reproduced')
        elif calls != []:
            behavior_errors.append(run + ': disabled Enter emitted a proposal')
        expected_failures = {'disabled Enter emits no proposal'} if expect_defect else set()
        if expect_defect and data['owner'] == 'accept':
            expected_failures.add('disabled Enter preserves Friday')
        failures = {c['name'] for c in data['checks'] if not c['pass']}
        if failures != expected_failures:
            behavior_errors.append(run + ': unexpected checks ' + str(failures))
        runs.append({'run': run, 'checks': len(data['checks']), 'expectedDefect': expect_defect,
                     'failures': sorted(failures), 'trustedInputs': sum(e['isTrusted'] for e in trusted), 'motionSyntheticPressEvents': len(synthetic)})
if 'All tests passed!' not in (root / 'final-all-focused.log').read_text():
    behavior_errors.append('focused tests did not pass')
if 'No issues found!' not in (root / 'final-analyze.log').read_text():
    behavior_errors.append('analysis did not pass')
retained = []
for path in sorted(root.glob('baseline-candidate/*/results.json')):
    data = json.loads(path.read_text())
    retained.append({'run': str(path.parent.relative_to(root)), 'failures': [c['name'] for c in data['checks'] if not c['pass']]})
print(json.dumps({'integrity': {'passed': not errors, 'files': len(manifest), 'errors': errors},
                  'recordedBehavior': {'passed': not behavior_errors, 'errors': behavior_errors, 'runs': runs},
                  'retainedFirstAttemptFailures': retained,
                  'limits': 'Checks recorded trusted native behavior and hashes; does not rerun browser, decode motion, or establish release readiness.'}, indent=2))
raise SystemExit(bool(errors or behavior_errors))
