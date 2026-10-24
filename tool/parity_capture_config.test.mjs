import { test } from 'node:test';
import assert from 'node:assert/strict';
import { captureEvents, captureReducedMotion, assertMotionEnvironment, assertServedJavascript } from './parity_capture_config.mjs';

test('pointer actions normalize defaults without mutating the supplied protocol', () => {
  const config = { targets: { start: { x: 20, y: 30 } }, events: [
    { atMs: 0, target: 'start' },
    { atMs: 10, type: 'down' },
    { atMs: 20, target: 'start' },
    { atMs: 30, type: 'up' },
    { atMs: 40, type: 'click', target: 'start' },
  ] };
  const original = structuredClone(config);
  assert.deepEqual(captureEvents(config), [
    { atMs: 0, type: 'move', target: 'start' },
    { atMs: 10, type: 'down', button: 'left' },
    { atMs: 20, type: 'move', target: 'start' },
    { atMs: 30, type: 'up', button: 'left' },
    { atMs: 40, type: 'click', target: 'start', button: 'left' },
  ]);
  assert.deepEqual(config, original);
  for (const button of ['left', 'middle', 'right']) {
    assert.deepEqual(captureEvents({ events: [
      { atMs: 0, type: 'down', button }, { atMs: 0, type: 'up', button },
    ] }).map(event => event.button), [button, button]);
  }
});

test('invalid pointer sequences and unsupported buttons fail preflight', () => {
  const validate = events => captureEvents({ targets: { start: { x: 20, y: 30 } }, events });
  for (const button of ['back', 'forward', 'LEFT', '', 0, null]) {
    for (const type of ['down', 'up', 'click']) {
      assert.throws(() => validate([{ atMs: 0, type, button, target: 'start' }]), /Unsupported button/);
    }
  }
  for (const events of [
    [{ type: 'up' }],
    [{ type: 'down' }],
    [{ type: 'down' }, { type: 'down' }, { type: 'up' }],
    [{ type: 'down' }, { type: 'down', button: 'right' }],
    [{ type: 'down', button: 'right' }, { type: 'up' }],
    [{ type: 'down' }, { type: 'click', target: 'start' }, { type: 'up' }],
    [{ type: 'down' }, { type: 'up' }, { type: 'up' }],
  ]) assert.throws(() => validate(events.map((event, atMs) => ({ atMs, ...event }))), /held|Unreleased/);
  assert.throws(() => validate([{ atMs: 0, type: 'move', target: 'start', button: 'left' }]), /does not accept/);
  assert.throws(() => validate([{ atMs: 0, type: 'down', target: 'missing' }]), /Unknown target/);
});

test('existing action payload checks run before capture', () => {
  const validate = events => captureEvents({ targets: { start: { x: 20, y: 30 } }, events });
  assert.deepEqual(validate([{ atMs: 0, type: 'key', key: 'Enter' }, { atMs: 1, type: 'text', text: '' }]), [
    { atMs: 0, type: 'key', key: 'Enter' }, { atMs: 1, type: 'text', text: '' },
  ]);
  assert.throws(() => validate([{ atMs: 0, type: 'press' }]), /Unknown event/);
  assert.throws(() => validate([{ atMs: 0, type: 'key' }]), /string key/);
  assert.throws(() => validate([{ atMs: 0, type: 'text', text: 1 }]), /string text/);
  assert.throws(() => validate([null]), /Event must/);
  assert.throws(() => captureEvents({}), /events must/);
});

test('motion setting is validated without changing the legacy default', () => {
  assert.equal(captureReducedMotion({}), 'no-preference');
  for (const value of ['reduce', 'no-preference']) assert.equal(captureReducedMotion({ reducedMotion: value }), value);
  for (const value of ['', true, 'reduced', 1]) assert.throws(() => captureReducedMotion({ reducedMotion: value }), /reducedMotion must/);
});

test('actual browser and Flutter preferences must agree for both settings', () => {
  for (const reduced of [false, true]) {
    const config = { reducedMotion: reduced ? 'reduce' : 'no-preference', requireFlutterProbe: true };
    const environment = { reducedMotion: reduced, flutterCapture: { disableAnimations: reduced } };
    assertMotionEnvironment(config, environment);
    assert.throws(() => assertMotionEnvironment(config, { ...environment, reducedMotion: !reduced }), /matchMedia/);
    assert.throws(() => assertMotionEnvironment(config, { ...environment, flutterCapture: null }), /Missing effective/);
    assert.throws(() => assertMotionEnvironment(config, { ...environment, flutterCapture: { disableAnimations: !reduced } }), /MediaQuery/);
  }
  assertMotionEnvironment({}, { reducedMotion: false });
});

test('served JavaScript requires a real matching response and revision label', () => {
  const servedJs = { url: 'http://localhost/main.dart.js', sha256: 'a'.repeat(64), revision: 'fixture' };
  assertServedJavascript({ servedJs }, [servedJs]);
  assert.throws(() => assertServedJavascript({ servedJs }, []), /hash mismatch/);
  assert.throws(() => assertServedJavascript({ servedJs }, [{ ...servedJs, sha256: 'b'.repeat(64) }]), /hash mismatch/);
  assert.throws(() => assertServedJavascript({ servedJs: { ...servedJs, revision: null } }, []), /requires/);
});
