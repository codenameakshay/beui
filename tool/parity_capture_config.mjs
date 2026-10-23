export function captureEvents(config) {
  if (!Array.isArray(config.events)) throw new Error('events must be an array');
  let heldButton = null;
  const events = config.events.map(action => {
    if (!action || typeof action !== 'object') throw new Error('Event must be an object');
    const type = action.type ?? 'move';
    if (!['move', 'click', 'down', 'up', 'key', 'text'].includes(type)) throw new Error(`Unknown event type ${type}`);
    if ((action.target !== undefined || type === 'move' || type === 'click') &&
        !Object.hasOwn(config.targets ?? {}, action.target)) throw new Error(`Unknown target ${action.target}`);
    if (type === 'key' && typeof action.key !== 'string') throw new Error('Key event requires a string key');
    if (type === 'text' && typeof action.text !== 'string') throw new Error('Text event requires a string text');
    const event = { ...action, type };
    if (['click', 'down', 'up'].includes(type)) {
      event.button = action.button === undefined ? 'left' : action.button;
      if (!['left', 'middle', 'right'].includes(event.button)) throw new Error(`Unsupported button ${event.button}`);
      if (type === 'up') {
        if (heldButton !== event.button) throw new Error(`Pointer up ${event.button} does not match held button ${heldButton}`);
        heldButton = null;
      } else {
        if (heldButton !== null) throw new Error(`Cannot ${type} while button ${heldButton} is held`);
        if (type === 'down') heldButton = event.button;
      }
    } else if (action.button !== undefined) throw new Error(`Event ${type} does not accept a button`);
    return event;
  });
  if (heldButton !== null) throw new Error(`Unreleased pointer button ${heldButton}`);
  return events;
}

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
