# Invalid and inconclusive captures

The following files remain unchanged. None certifies parity.

| Directory | Status | Reason |
| --- | --- | --- |
| `after-width592` | Invalid foreign build | `localhost:8103` reached Dart PID 9455 in `t3-d825aa5b/example`, not this worker's frozen release. Old tab widths and fake market artwork were visible. |
| `after-width592-light` | Invalid foreign build | Same port collision. |
| `after-width592-reduced` | Invalid foreign build | Same port collision. Effective Flutter reduced motion was also not measured. |
| `before-expanded/reference/dock`, `number`, `text-animation` | Invalid source route | Requested `/components/components/…`. |
| `before-components-corrected` | Invalid source route | Requested `/components/…` instead of `/components/motion/…`. |
| `pointer-focus-before.log` | Invalid regression reproduction | Target locator was wrong. The later `pointer-focus-repro.log` is the valid red reproduction. |
| `after`, `after-final`, `after-release`, `after-expanded-actions` | Supplementary only | Earlier implementation states or default-width captures. Their metadata and raw step failures remain. |
| `after-light`, `after-reduced` | Supplementary only | Unpaired source run. No measurement of effective Flutter `disableAnimations`. |
| `compare/card-motion/after-result.json` | Inconclusive | Design Compare returned `capture_unreliable` with a null score. |

PID 9455 was verified and stopped by the parent. Python PID 4100 remained. A subsequent `127.0.0.1:8103/main.dart.js` request matched the frozen release SHA-256 `aea97a92218d9462a95d601dde72b6bc9e4fee1c060ea4730967aa05fdaf1bbb`. The replacement batches save expected and actual hashes, URL, and check time in `served-build.json`.

The alternative address `127.0.0.2` did not work. The raw curl result was `curl: (28) Connection timed out after 20006 milliseconds`. The empty stream hash `e3b0c442…` is not a build identity.

The original `before` recordings retain their SHA-256 manifest. No baseline wrapper patch was applied. The fresh candidate uses the shared opt-in `previewWidth=592` frame. That changed capture wrapper is not a widget fix or a same-conditions baseline recapture.
