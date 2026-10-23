import { test } from 'node:test';
import assert from 'node:assert/strict';
import { captureReducedMotion, assertMotionEnvironment, assertServedJavascript } from './parity_capture_config.mjs';

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
