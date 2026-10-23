export function captureReducedMotion(config) {
  const value = config.reducedMotion ?? 'no-preference';
  if (!['reduce', 'no-preference'].includes(value)) {
    throw new Error('reducedMotion must be reduce or no-preference');
  }
  return value;
}

export function assertMotionEnvironment(config, environment) {
  const expected = captureReducedMotion(config) === 'reduce';
  if (environment.reducedMotion !== expected) {
    throw new Error('Browser matchMedia reduced motion differs from requested preference');
  }
  if (config.requireFlutterProbe && !environment.flutterCapture) {
    throw new Error('Missing effective Flutter capture probe. Use captureProbe=1');
  }
  if (environment.flutterCapture && environment.flutterCapture.disableAnimations !== expected) {
    throw new Error('Flutter MediaQuery.disableAnimations differs from browser preference');
  }
}

export function assertServedJavascript(config, scripts) {
  if (!config.servedJs) return;
  const { url, sha256, revision } = config.servedJs;
  if (!url || !/^[a-f0-9]{64}$/.test(sha256 ?? '') || !revision) {
    throw new Error('servedJs requires url, sha256, and revision');
  }
  const actual = scripts.find(script => script.url === url);
  if (!actual || actual.sha256 !== sha256) {
    throw new Error(`Served JavaScript hash mismatch for ${url}`);
  }
}
