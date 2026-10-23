# Tooltip semantics move contract

Compile the actual production adapter, then run its DOM contract with Playwright:

```sh
dart compile js -O2 test/web/semantics_move_guard_entry.dart -o /tmp/beui-semantics-guard.js
npm install --prefix /tmp/beui-guard-runtime playwright-core
PLAYWRIGHT_MODULE=/tmp/beui-guard-runtime/node_modules/playwright-core/index.mjs \
  CHROMIUM_EXECUTABLE='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  REQUIRED_BROWSERS=chromium \
  node test/web/semantics_move_guard_contract.mjs /tmp/beui-semantics-guard.js /tmp/beui-guard-results
```

The output directory must not already exist. Without PLAYWRIGHT_MODULE the runner resolves the installed `playwright-core` package. CHROMIUM_EXECUTABLE, FIREFOX_EXECUTABLE and WEBKIT_EXECUTABLE override Playwright's installed browser paths. REQUIRED_BROWSERS is a comma-separated list, defaulting to chromium. Unavailable required browsers and zero executed browsers fail the run; optional unavailable browsers are recorded.

The contract checks final ordering and retained focus across 240 positions, native return/error behavior, unrelated and nontransparent wrappers, other focus ownership, shadow-root embedding, and append variants. Native no-op semantics remain unchanged. This does not replace the real Flutter Bump fixture, screen-reader checks, or browser-specific accessibility verification.
