# UX audit — beui chat & agent client flows

**Date:** 2026-08-18 · **HEAD:** `538bd35` · **Method:** four parallel Opus audit agents (one per flow cluster), each reading component source, demos, tests, theme tokens, and golden PNGs, scored against the better-ui / better-layout / better-writing / better-accessibility rubrics; findings cross-verified by the orchestrator (disputed claims re-checked against the repo before inclusion). Read-only — no code was changed. The example app was not run; all contrast ratios are computed from the actual token values in `lib/src/theme/beui_colors.g.dart`.

**Scope — 22 components across 4 clusters:**

| Cluster | Components |
|---|---|
| Conversation core | `BeuiChatApp`, `BeuiMessage`, `BeuiMessageBubble`, `BeuiMessageScroller`, `BeuiStreamingResponse`, `loading_states` (`BeuiThinkingShimmer` / `BeuiAgentProgress` / `BeuiReasoningText`), the composed `agents_chat_preview` |
| Input & composition | `BeuiPromptInput`, `BeuiAttachmentUpload`, `BeuiFileUpload`, `BeuiFeedbackWidget`, `BeuiInput` |
| Agent work surfaces | `BeuiToolApproval`, `BeuiApprovalCard`, `BeuiToolResult`, `BeuiAgentActivity`, `BeuiTodoList`, `BeuiAgentTheme` |
| Rich content & shell | `BeuiCitations`, `BeuiCodeBlock`, `BeuiFileDiff`, `BeuiImageGeneration`, `BeuiAiSidebar`, `BeuiPreviewRail` |

**Totals: 154 findings — 9 P0, 51 P1, 94 P2** (per-cluster: 34 / 38 / 44 / 38), plus ~30 protected strengths.

---

## Executive summary

The library's **motion craft is genuinely excellent** — mount-only entrance seeding that never replays on streaming updates, exits consistently faster than entrances, interruptible spring disclosures, per-channel reduced-motion handling where it's done right, and load-bearing fidelity comments throughout. The *feel* of the port is its strongest asset.

The UX debt is concentrated in four systemic places, and it is unevenly distributed in a telling way: **the components with the highest stakes got the least care.**

1. **The trust surface is the weakest surface.** `BeuiToolApproval` — the widget that gates an agent running commands — hides the command behind a collapsed "View details" by default, offers no keyboard path to Approve *or* Deny, has no destructive-action tier in its API (`rm -rf` and `ls` render identically), and keeps its action row tappable for ~220 ms after a decision (double-fire). Meanwhile its sibling `BeuiApprovalCard` got the full treatment (keyboard, semantics, theming, interruptible motion). Error/failure states are missing across the board: a failed `BeuiStreamingResponse` is pixel-identical to a completed one, `BeuiAgentActivity` cannot represent a failed run, and a stopped stream renders as fake-complete.

2. **Keyboard and screen-reader access is a lottery.** Roughly half the cluster is exemplary (`BeuiButton`, `BeuiAttachmentUpload`, `BeuiAiSidebar`'s tree keyboard model, `BeuiApprovalCard`); the other half is pointer-only (`BeuiToolApproval` actions, `BeuiPromptInput`'s + / model menus, all of `BeuiFileUpload`, the feedback close button). Esc is dead on any `trapFocus: false` overlay. Terminal outcomes ("Failed", "Denied", "Copied", "Sent") are never announced because live regions are switched off exactly when the outcome arrives. The transcript nests 3–5 live regions that never announce the streamed text.

3. **A pervasive contrast debt with one root cause.** Tokens that pass AA at full strength (`mutedForeground` = 5.9:1) are alpha-multiplied at the point of use down to 1.6–3:1: placeholders 2.3–2.6:1, tool slugs 2.3:1, line-number gutters 1.6–1.8:1, citation domains 2.55:1, light-mode status badges 2.8–3.7:1. The `ring` token (a 6–12 % hairline meant for borders) is reused as the focus indicator at **1.3:1** — found independently by two auditors.

4. **The system isn't yet a system.** `_AgentDisclosure` is copy-pasted seven times (two copies byte-identical, the highlighter fork already diverged); the same refusal is "Deny", "Reject", and "Cancelled" in three sibling components; press scales range 0.9–0.99; `defaultOpen` differs across four transcript components with no rationale; and `BeuiAgentTheme` ships **zero colour roles** while the five agent widgets hardcode 50 hex literals that *disagree with* the existing `BeuiColors.success/warning/destructive` tokens — agent status colour cannot be rethemed at all.

**Also verified during this audit:** the package **does not compile at HEAD** — `lib/src/motion/wallet_card/search_bar.dart:286` references `LucideIcons.history`, which does not exist in the resolved `flutter_lucide` 1.31.0, so every test fails to load. And the a11y CI gate mandated by `PORTING_SPEC.md:476-492` does not exist: 12 suites enable semantics (`ensureSemantics`) and 17 assert labels (`bySemanticsLabel`), but there are **zero** `matchesSemantics` / `meetsGuideline` / `textContrastGuideline` / `labeledTapTargetGuideline` assertions anywhere under `test/`.

---

## Flow map — how the client fits together

The composed experiences live in the example app, not the library:

- **`agents_chat_preview.dart`** (440×576 card): `BeuiMessageScroller` → `BeuiMessage` rows → `BeuiMessageBubble(BeuiStreamingResponse | Text)` → divider → `BeuiPromptInput` (1-row, borderless). Simulated stream at ~96 chars/s. Notably passes `showActions: false, announce: false` — the flagship "real chat" preview has **no copy, no retry, no feedback on any response**.
- **`chat_app_demo.dart`**: the only transcript composing the agent surfaces — `BeuiAgentActivity` → `BeuiTodoList` → `BeuiToolApproval` → `BeuiToolResult` → `BeuiApprovalCard`, all driven off one `_toolStatus`, inside `BeuiChatApp` (fixed 272 px sidebar, no responsive behaviour, no motion of its own — sidebar toggle is a one-frame null swap).

Canonical state machines (as implemented):

| Surface | States | Missing states |
|---|---|---|
| `BeuiStreamingResponse` | streaming → complete / error | **stopped/cancelled**; error is visually identical to complete |
| `BeuiToolApproval` | pending → approving → approved → running → complete / denied / error | **expired, timedOut**; no record of *which* grant (once vs always) |
| `BeuiApprovalCard` | pending → submitting → approved / answered / changesRequested / rejected | timeout/expiry |
| `BeuiToolResult` | running → success / error / cancelled | — (most complete enum in the cluster) |
| `BeuiAgentActivity` | working → complete | **error/aborted** — a crashed run renders as "Ran 3 tools ✓" |
| `BeuiImageGeneration` | queued → generating → refining → complete / error | progress %, **cancel** |
| `BeuiMessageBubble` | idle, mount-pop, pressed, focused, collapsed/expanded | loading, **failed-to-send**, editing |
| Upload rows | idle → uploading → complete / failed (+removing) | **cancel-in-flight** (`BeuiAttachmentUpload` blanks the X during upload); real `progress` missing from `BeuiAttachmentUploadItem` |

Full per-component flow maps (every state, transition, spring, and duration) are in the cluster sections below.

---

## Cross-cutting themes

Each theme was observed independently in ≥2 clusters; file:line evidence sits in the cluster findings referenced.

### T1 — Trust and failure are under-designed (P0 cluster)
- Command hidden at the moment of approval; every call site in the repo overrides the default (`A1`).
- No risk/severity tier in the approval API; visual weight *inverts* safety — solid `Allow once`, ghost `Deny` (`A3`, `A6`).
- Error ≡ complete in `BeuiStreamingResponse` (`C1`); no failure state in `BeuiAgentActivity` (`A20`); stopped streams present as complete (`C13`); no timeout/expiry/revocation anywhere (`A21`).
- Post-decision double-fire windows (`A4`).

### T2 — Keyboard access is a lottery; Esc can be dead
- Pointer-only: `BeuiToolApproval` actions (`A2`), `BeuiPromptInput` + / model menus (`I2`), all of `BeuiFileUpload` (`I14`), feedback close/trigger (`I24`).
- `trapFocus: false` overlays never take focus, so `BeuiOverlay`'s Esc binding is unreachable (`I2`).
- Exemplars already in-repo to copy from: `attachment_upload.dart:881-897`, `button/base.dart:266-284`, `BeuiApprovalCard`'s expand toggle, `BeuiAiSidebar`'s tree model.
- Where keyboard *works*, focus is often invisible: sidebar rows never render their `focused` flag (`R4`); the bubble focus ring is 1.3:1 *and* shifts content 2 px (`C2`).

### T3 — Contrast debt: alpha-multiplied tokens and a misused `ring`
| Surface | Ratio | Finding |
|---|---|---|
| Focus ring token (`ring`) light/dark | 1.30 / 1.31:1 | `C2`, `R6` (independent) |
| `outline` bubble edge | ~1.1:1 | `C9` |
| Line-number gutters (code/diff) | 1.63–1.82:1 | `R8` |
| Tool slug / meta / chips (`mutedForeground @ .55–.7`) | 2.3–3.0:1 | `A8` |
| Placeholders (`@ .55–.6`) | 2.32–2.61:1 | `I34` |
| Citation domain + link icon | 2.55 / 1.79:1 | `R9` |
| Status badges, light mode (pending/approved/denied) | 2.84–3.74:1 | `A7` |
| `danger` bubble text | 3.43:1 | `C9` |
| Diff add/remove row tints (vs each other) | 1.04:1 | `R19` |

Root fixes: stop multiplying `mutedForeground` by alpha for information-bearing text; add a dedicated `focusRing` colour role (≥3:1) and leave `ring` for hairlines; lift light-mode status foregrounds to a 700-tier.

### T4 — Reduced motion: one policy, two implementations
The project rule (drop movement, keep opacity/colour) is implemented beautifully in conversation core, attachment/feedback, and `BeuiPreviewRail` — and violated by hard cuts in all five agent-cluster disclosures (`A16`), citations row entrances, and `BeuiImageGeneration`'s reveal (`R18`). The correct per-channel pattern (`motionFor(..., isMovement:)`) already exists; the agent cluster just doesn't use it.

### T5 — Streaming auto-follow fights the reader
- `BeuiMessageScroller` restarts a 320 ms `animateTo` on every token (~20× before one completes), so the viewport permanently trails the live edge and the programmatic-scroll guard never clears (`C5`).
- `BeuiCodeBlock` / `BeuiFileDiff` / `BeuiToolResult` yank to `maxScrollExtent` on every change with no "user scrolled away" escape (`R7`).
- No "jump to latest" affordance exists anywhere, despite the scroller computing everything needed for one (`C4`).

### T6 — Hidden content with zero affordance
Scrollbars are explicitly disabled in the code block, file diff, and tool result viewports with no fade, no count, no cue (`R12`, `A22`); rail ticks clip silently past ~28 messages (`C16`); `BeuiFileDiff` ellipsises wide lines with **no horizontal scroll at all** — the single P0 in a component whose whole job is showing what changed (`R1`). `BeuiAgentActivity`'s edge fade masks are the in-repo pattern to copy.

### T7 — Screen-reader narrative is broken at the endpoints
Live regions are gated on the *busy* state, so terminal outcomes are never announced (`A30`); "Copied" swaps a label on a non-live node (`C23`, `R28`); the feedback success view auto-closes in 1.6 s unannounced (`I25`); the transcript nests 3–5 live regions whose labels are constants, so streamed text is never announced either (`C6`).

### T8 — The system isn't a system yet
- `_AgentDisclosure` duplicated ~7×; highlighter duplicated and already diverged between code block and diff (`R33`, `A39`).
- Vocabulary: Deny vs Reject vs Cancelled for the same act (`A26`); ~40 hardcoded English strings, no localization surface (`A27`).
- `defaultOpen` true/true/false/false across four transcript components (`A42`); press scales 0.9 / 0.97 / 0.99 on one screen (`A17`, `C31`); three different card treatments in one transcript (`A38`).
- `BeuiAgentTheme`: zero colour roles vs 50 hardcoded hex literals that disagree with `BeuiColors.success/warning/destructive` (`A36`); consumed by 2 of the 5 widgets it was built for — `BeuiAgentActivity` uses none of it (`A37`).

### T9 — Touch targets: 14–36 px against a 44 pt floor
Inline citation markers ≈16 px, approval actions ~27 px, copy buttons 28 px, response actions 28 px at 2 px spacing, rail ticks 14 px at 0 px spacing, expand/dismiss 20 px, feedback close 20 px (below even WCAG 2.5.8's 24 px floor). `BeuiTodoList`'s 44 px header is the only pass. The fix is uniform: keep the visual, expand the hit slop.

### T10 — The gallery models the wrong patterns
Dead controls ("Attach file" with no handler, three sidebar nav buttons with `onTap: () {}`), no error/stopped routes anywhere, `danger`/`tint`/`outline` variants and `BeuiStreamingResponseStatus.error` demoed nowhere, hardcoded emeralds and a `primaryForeground`-on-`solid` override that renders ~1.08:1 under brand themes, bare `GestureDetector`s consumers will copy. The gallery is the de-facto documentation; it currently teaches anti-patterns.

### T11 — The safety net has holes
No compile at HEAD (verified); zero a11y guideline assertions (verified); no goldens for any conversation-core or agent-cluster component (21 goldens exist, all elsewhere); no dark-mode test despite `isLight` branches in status colours; ~2 keyboard assertions across the agent cluster; `PORTING_SPEC.md`'s Part B interaction-state matrix has no row for any agent-cluster component — plausibly the root cause of T2.

---

## Cluster 1 — Conversation core (34 findings: 3 P0 · 17 P1 · 14 P2)

No golden PNG exists for any component in this cluster; all claims are from source. Palette: `defaultMono` (`beui_colors.g.dart:12-59`).

### Flow map

**`BeuiChatApp`** (`chat_app.dart`, 159 lines) — stateless chrome: `Row[SizedBox(272 sidebar) + Column[header / divider / body / divider / prompt]]`. Exactly one state; no motion of any kind; sidebar show/hide is a one-frame null swap.

**`BeuiMessage`** — row that reverses children for `user`, publishing side/author via scopes. Entrance: `_messagePopUp` spring (mass 0.62, stiffness 480, damping 32), opacity + y 8→0 + scale 0.95→1, origin bottomRight (user) / bottomLeft (assistant). Mount-only (progress seeded 0, flipped post-frame) — streaming updates never replay it. Reduced motion: 120 ms opacity-only. Sub-parts: Group, Avatar (28 px), Content, Header/Footer (11 px metadata), Marker, Typing (3× 4 px dots, 1050 ms, 140 ms stagger).

**`BeuiMessageBubble`** — 6 variants (solid/soft/tint/outline/ghost/danger). States: idle, mount-pop (`_bubblePop` mass 0.52 / 520 / 27; content fades separately after 40 ms), pressed (scale 0.99, 150 ms), focused (2 px border swap in `AnimatedContainer`), collapsed/expanded (ShaderMask fade; chevron springs, **height change not animated**). No loading, failed-to-send, or editing state.

**`BeuiMessageScroller`** — following / released / rail-active + `busy`. Follow and `scrollToId` = `animateTo(320 ms, easeOut)`. Rail ticks scale 1.0/0.68/0.44/0.25 by distance on `beuiSpringLayout`; preview card 180 ms fade + 4 px rise + 3σ unblur. Follow released by `UserScrollNotification` or ArrowUp/PageUp/Home. No empty, error, or "new messages" state.

**`BeuiStreamingResponse`** — streaming/complete/error; copy idle↔copied (1600 ms); feedback none/up/down; sources disclosure (open 220 / close 140 ms). Actions reveal 220 ms opacity + y 4→0.

**`loading_states.dart`** — `BeuiThinkingShimmer` (1800 ms pass), `BeuiAgentProgress` (3×3 grid, 1550 ms, per-cell delays, reduced = opacity-only pulse, `clock.now()`-based), `BeuiReasoningText` (cascade 25 ms stagger / swap 200 ms / scramble 420–760 ms).

### Findings

**C1 — P0 — `error` status is visually and semantically identical to `complete`.** `streaming_response.dart:211-214, 275`. The only difference is two missing thumb icons; semantic label is `'Response'` for both. A failed answer looks like a finished one. `BeuiStreamingResponseStatus.error` appears only in tests — never in a demo. → Destructive-tinted leading icon + short message + `'Response, failed'` semantics; surface retry when `status == error`.

**C2 — P0 — The default focus ring is invisible (1.29:1) and focusing shifts content 2 px.** `message_bubble.dart:391-394` + `beui_colors.g.dart:29`. `ring` = black @ 12 % → 1.29:1 light / 1.35:1 dark vs the 3:1 required. The border lives in the `BoxDecoration`, so it also insets the child — the visible "focus indicator" is a layout jitter. Only the 10 branded themes escape. → Paint the ring outside layout (`foregroundDecoration`/overlay) and give `defaultMono` a ≥3:1 focus colour.

**C3 — P0 — Bubbles assert-fail in debug below ~44 px of width, reachable through the shell.** `message_bubble.dart:355-361` (`minWidth: 36` vs `maxWidth: 0.82 × available`); `BeuiChatApp` hardcodes a 272 px sidebar with no breakpoint (`chat_app.dart:126-133`) — a 300 px window gives the body 28 px. → Clamp `maxW ≥ minWidth`; add a sidebar breakpoint/overlay mode.

**C4 — P1 — No "jump to latest" affordance.** `message_scroller.dart:358-362, 428-454`. The scroller computes `_following`, fires `onFollowChange`, exposes `scrollToEnd()` — and renders nothing. Neither hook is used anywhere in `example/`. → Built-in "↓ Latest" pill (opt-out), with unread count.

**C5 — P1 — Smooth follow chases and never settles during token streaming.** `message_scroller.dart:414-454`. Every growth restarts a 320 ms `animateTo` (~20× per completion at 16 ms token cadence); `_programmaticClear` is re-armed every tick, holding the guard true for the whole stream. → `jumpTo` when growth outpaces the animation; smooth only for discrete appends.

**C6 — P1 — The transcript is a 3–5-deep nest of live regions that never announce the streamed text.** `message_scroller.dart:620, 637, 672-679` + `streaming_response.dart:280` + `message.dart:602`. Labels are constants, so nothing announces; anything that does change risks re-reading the transcript. → One live region; put changing text in its label, debounced to sentence boundaries; default `announce: false` under a scroller.

**C7 — P1 — Interactive bubbles have no button semantics.** `message_bubble.dart:363-402` — tap action, no `button: true`, no label (contrast `_MessageRailTick`, which is correct). Zero semantics assertions in either test file. → `Semantics(button: true)` + `semanticLabel` param.

**C8 — P1 — Touch targets 28 px (2 px apart) and 14 px (0 px apart).** `streaming_response.dart:593-594, 314`; `message_scroller.dart:988-990`. → 44 px hit areas over the same visuals; raise rail pitch or gate to hover-capable pointers.

**C9 — P1 — `outline` variant is invisible (~1.1:1) and `danger` fails at 3.43:1, colour-only.** `message_bubble.dart:265-281`. → `card`/`muted` fill or stronger edge for outline; darker danger text + a `triangle_alert` leading icon.

**C10 — P1 — Completion actions cause a ~40 px one-frame layout jump.** `streaming_response.dart:304-311, 506-526` — opacity/translate animate, height doesn't; inside a following scroller this shoves the transcript. → Animate `heightFactor` (as `_AgentDisclosure` in the same file already does).

**C11 — P1 — Expanding a collapsible bubble snaps.** `message_bubble.dart:566-611` — chevron springs, content pops. → `_AgentDisclosure` pattern + cross-fade the mask.

**C12 — P1 — Nothing animates out of the box.** `animateIn` defaults false on both message and bubble; the flagship preview opts assistant rows out entirely; later prop changes are silently ignored after the one-shot seed (`message_bubble.dart:227-234`). → Default true, derive "new" from key identity, or ship a `BeuiMessageList`.

**C13 — P1 — Stopping a stream produces a fake-complete message.** No `stopped` value exists in the status enum (`streaming_response.dart:19-28`); both demos flip to `complete` on stop. → Add `stopped` with its own affordance.

**C14 — P1 — Empty-bubble flash on every assistant turn.** `chat_app_demo.dart:910-913` renders `' '` → shimmer → empty box → text; the preview stacks two differently-labelled indicators back-to-back. → One indicator identity across pending→streaming, cross-fade into first token.

**C15 — P1 — `SingleChildScrollView` rebuilds the entire transcript at token cadence.** `message_scroller.dart:629` + full re-measure per layout. → Sliver/`itemBuilder` constructor or a loudly documented ceiling.

**C16 — P1 — Rail ticks silently unreachable past ~28 messages.** `message_scroller.dart:850-884` — fixed 14 px pitch, clipped, no scroll/fade. → Compress pitch or scroll with edge fades.

**C17 — P1 — RTL broken across the cluster.** Physical `Alignment.centerRight`/`bottomLeft`, `Border(right:)`, `EdgeInsets.only(left:)` throughout (table of 8 sites in the cluster report); bubble and its own column can disagree about sides in RTL. → Directional variants throughout; mirror the rail.

**C18 — P1 — Demo "Connected" chip: 3.76:1 at 10 px, and never reflects state.** `chat_app_demo.dart:460-533`. **C19 — P1 —** demo overrides `solid` bubble text with brand `primaryForeground` → ~1.08:1 under amber/orange themes (`chat_app_demo.dart:571-574, 928-931`). **C20 — P1 —** half the bubble API (danger/tint/outline, collapsible, group, marker, error status) has no gallery route; variant tests are text-only smoke tests.

P2 (C21–C34, abridged): typing-dot ticker runs at 60 fps under reduced motion; doubled tooltip+semantics labels on actions; "Copied" never announced; sources toggle looks static until hover; `collapsedLines` measures with the assistant style regardless of side; collapsible trigger omits `expanded`; default transcript padding is zero (every demo overrides it); rail preview can paint outside the component below ~290 px; header/footer rows can't wrap (11 px text at `height: 1`); the keyboard escape hatch needs an invisible Tab stop first; press feedback 0.99 (imperceptible) vs 0.9 (exaggerated) on one screen; demo copy promises error-recovery states no demo has; three dead sidebar nav buttons; uncancelled `Future.delayed` in `_ContentReveal`.

### Genuinely good (protect)
Mount-only entrance seeding (the hard part of chat motion, done right); reduced motion as a designed state with 37 test references; `_AgentDisclosure` as the reference disclosure; `_MessageRailTick`'s complete interactive contract; consistent controlled/uncontrolled pattern with honest docs; `clock.now()` in `BeuiAgentProgress`; `_PhraseSlot` reserving width from the longest phrase; load-bearing source-fidelity comments.

---

## Cluster 2 — Input & composition (38 findings: 2 P0 · 13 P1 · 23 P2)

### Flow map

**`BeuiPromptInput`** — composer shell (radius 16, padding 8): multiline field + 32 px footer (`+` actions → `leadingAction` → model picker → send/stop). Height snaps per keystroke to `clamp(lines, 2, 8) × lineHeight` (48–192 px), no `AnimatedSize`. Focus border animates 150 ms. Loading: ↑ swaps to a painted stop square on `beuiSpringSwap`; `+`/model dim and stop responding; **field stays editable**. `+` menu: plus rotates 45°, 224 px panel above-left, enter 280 / exit 160 ms. Model picker: `BeuiSelect` when no icons (keyboarded, bordered pill) or a custom 208 px overlay when any model has an icon (no keyboard, different look). Enter submits, Shift+Enter newlines, IME composing respected; Esc closes nothing; attachments exist only as an `onAction('image')` intent — no model, no chips, no removal.

**`BeuiAttachmentUpload`** — dropzone (192 px min, painted dashed frame, full keyboard via `FocusableActionDetector`) + rows: idle → uploading (900 ms simulated emerald wash, **action slot blank**) → complete (liveRegion) → failed (destructive tint + error line, retry) → removing (420 ms). 55 ms arrival stagger; image rows get hover-preview tooltip + full-screen overlay (rect glide, blur σ12, Esc works); audio rows get a 28-bar animated waveform (not seekable). Rejections fire callbacks only — no UI.

**`BeuiFileUpload`** — dropzone + queue rows: queued → uploading (spinner + 6 px bar, 280 ms ease) → success (check, hardcoded `#10B981` bar) → error (retry + remove). **No keyboard path anywhere.**

**`BeuiFeedbackWidget`** — 48 px corner circle → 400 ms morph to a 320 px panel (radius 40→20, bespoke overshoot cubic; field focus armed 400 ms later) → sending (all exits locked) → sent (sprinkle burst, badge spring, check stroke, auto-close 1600 ms) → error (liveRegion, message preserved). X / Cancel / Esc / outside-tap all **clear the text**.

**`BeuiInput`** — 44 px pill: focused (border + 2 px ring, 200 ms) → error (shake on rising edge; message slides in — but renders centered, see I30) → success (path-drawn check).

### Findings

**I2 — P0 — The `+` actions menu and model picker are unreachable and un-dismissable by keyboard.** `prompt_input.dart:797-807, 930-936, 1137, 1204-1210` are bare `Semantics > GestureDetector`; both menus open `trapFocus: false`, and `beui_overlay.dart:256-263` binds Esc inside a `Focus(autofocus: trapFocus)` subtree — with `trapFocus: false` nothing takes focus, so **Esc is dead**. A keyboard user cannot attach or change model. Violates `PORTING_SPEC.md:456, 471, 390`. → `FocusableActionDetector` on triggers (mirror `button/base.dart:263-288`), roving rows, `trapFocus: true` or hoist the Esc binding.

**I14 — P0 — `BeuiFileUpload` has no keyboard path — dropzone, remove, and retry are pointer-only.** `file_upload.dart:511-532, 836-846`. The spec names this component explicitly ("dropzone is a button"); its sibling does it correctly at `attachment_upload.dart:881-897`. → Copy the sibling's block.

**I1 — P1 — Enter is silently swallowed during generation** (`prompt_input.dart:376-393` — handled unconditionally, `_submit` early-returns on `loading`/empty; no newline, no queue, no feedback). **I3 — P1 —** adding an icon to one model silently swaps the picker from keyboarded `BeuiSelect` to the keyboardless custom overlay *and* changes the trigger's visual language (`:1033-1113`; golden confirms). **I4 — P1 —** full-text `TextPainter.layout` in `build()` per keystroke — a large paste janks the composer permanently (`:448-493`). **I9 — P1 —** anchored menus have no flip/viewport clamping — fixed 224/208 px panels at a fixed offset render off-screen near edges (`:834-839`). **I11 — P1 — There is no attachment surface in the composer at all**: no model, no chip rail, no per-attachment remove; `onSubmit(String, String?)` can't carry attachments; `chat_app_demo`'s "Attach file" action has **no handler** — a dead menu item in the flagship demo. **I12 — P1 —** in-flight uploads can't be cancelled (attachment rows lose their X during upload; file rows conflate cancel with delete). **I13 — P1 —** `BeuiAttachmentUploadItem` has no `progress` field — the wash is a fixed 900 ms simulation that races the consumer's real `status`. **I23 — P1 —** a stray outside tap destroys typed feedback with no confirmation (`feedback_widget.dart:244-253, 394` — the error path proves drafts *can* be preserved). **I24 — P1 —** feedback close is 20×20 (below the 24 px AA floor) and pointer-only, as is the trigger. **I25 — P1 —** success is never announced and self-destructs in 1.6 s. **I30 — P1 — `BeuiInput`'s error message renders centered** under the field — `AnimatedSwitcher` default layout builder + a full-width null branch; **confirmed in the committed golden** `beui_input.png`; the `left: 4` padding is silently inert (`input.dart:577-625`). **I31 — P1 —** errors not announced, label never associated with the field. **I32 — P1 —** the base input exposes no `autofillHints` / `textInputAction` / `maxLength` / `inputFormatters` / `readOnly` — a password or email form with platform autofill is unbuildable through the public API. **I34 — P1 —** placeholders fail contrast everywhere (2.32:1 composer / 2.55:1 input+feedback, both modes) — and the composer's placeholder is its only label; `mutedForeground` un-multiplied already passes. **I36 — P1 —** zero a11y/keyboard assertions across all five suites: no Shift+Enter, IME, paste, disabled, or Esc test — exactly why I2 is invisible to CI.

P2 (abridged): send disabled-vs-can't-stop are indistinguishable (dead stop square when `onStop == null`); disabled composer compounds opacity to ~0.30; `+`/model needlessly dead while streaming (attach-while-streaming is table stakes); send↔stop swap has an entrance but its documented exit is a hard cut; 32 px footer controls (hit-slop to 44); failed file rows read as grey metadata (`PDF · 2.3 MB · Connection lost`); progress announced as a bare unitless number, completion never announced; hardcoded `#10B981` ignores `colors.success` and dark mode; default dropzone copy promises drag-and-drop the port doesn't implement (false on every platform out of the box); rejections silent in UI (600 MB file → nothing happens); waveform documented as a scrubber but not seekable; "Click to preview" is mouse-only copy on a tooltip touch users never see; `BeuiAttachmentUpload` (2299 lines) isn't in the gallery catalog; feedback's 400 ms focus dead-zone swallows first keystrokes; submit disabled-on-empty with no explanation; 3-line hard cap on the feedback field; no rating dimension (highest-leverage friction fix available); repeated identical error re-shakes nothing; nested textField semantics on the composer; demo password-toggle/reset/chips are bare `GestureDetector`s consumers will copy; `BeuiChatApp` pins the composer with no `viewInsets` handling — the soft keyboard covers it outside a resizing `Scaffold`.

### Genuinely good (protect)
Concentric radii (16 = 8 + 8) in the composer; IME-aware Enter (the most-missed chat-composer detail); first-class per-channel reduced motion (opacity-only morph, skipped `AnimatedSize`, sprinkles dropped with instant check); exits consistently faster than entrances; **`attachment_upload.dart` is the keyboard/semantics reference implementation** (FocusableActionDetector ×4, liveRegions, ExcludeSemantics on decoration, scopesRoute on the preview) and its 605-line test suite is the model; `BeuiButton`'s focus contract; painted marks, never assets; the preview close button's reserved overhang with the pointer-bounds comment.

---

## Cluster 3 — Agent work surfaces (44 findings: 4 P0 · 15 P1 · 25 P2)

The dominant theme: **`BeuiApprovalCard` got the trust treatment; `BeuiToolApproval` — the component that actually gates dangerous actions — did not.** All four P0s live in that one file and are fixable without touching the visual design. Note: `flutter test` does not run at HEAD (see T11), so none of this cluster is currently executable in CI.

### Flow map

**`BeuiToolApproval`** — card with shield glyph, title ("Allow this tool to run?"), tool slug (12 px mono muted), amber "Approval required" pill, optional description, collapsed "View details ⌄", footer `Allow once` (solid) / `Always allow` (outlined) / `Deny` (ghost). States: pending / approving / approved / running / complete / denied / error (no expired/timedOut/queued); glyph is `mutedForeground` for every state except error — all colour lives in the badge. Details `defaultOpen: false`; leaving pending force-collapses and animates the footer out (220 ms). After a decision: no undo, no record of which grant, no revocation.

**`BeuiApprovalCard`** — simple mode (status glyph, rolling title, badge or `n/N`, expand chevron/dismiss; Approve / Request changes / Reject via `BeuiButton`) and question mode (stepped radio/checkbox/freeform, progress dots, auto-advance 240 ms). Terminal states collapse the interactive body. Expandable body (new): offstage-measures both children, cross-fades + springs height, fully interruptible, keyboard-activatable.

**`BeuiToolResult`** — seven-element header row (icon · title · meta · slug · status glyph · status text · chevron) over a 220 px-capped output panel (scrollbars off) with Copy result / Run again footer. running / success / error / cancelled; `defaultOpen: true`, force-opens on running, collapses on complete; follows the live edge while streaming.

**`BeuiAgentActivity`** — working (shimmer header + fixed 208 px viewport translating on `beuiSpringLayout`, top fade) → complete (tappable summary "Thought for 4.6 s" / "Ran 3 tools"). Per-step pending/active/complete marks. **No error state.**

**`BeuiTodoList`** — 44 px header (morphing icon, rolling `n/N` tabular counter) over rows with painted status marks (dashed ring / determinate arc / drawn check / X) and a 280 ms strike-through. Auto-collapses on all-complete, re-opens on resume.

### Findings

**A1 — P0 — The command is hidden by default at the moment of approval.** `tool_approval.dart:249` (`defaultOpen = false`) — the user is asked to allow `terminal.run` with no command, no args, no cwd visible. **Every call site in the repo overrides this default** (`tool_approval_demo.dart:168`, `chat_app_demo.dart:647`). → Default open when `parameters.isNotEmpty`.

**A2 — P0 — Allow once / Always allow / Deny / View details are unreachable by keyboard.** Zero focus primitives in the file (verified by grep); actions are `MouseRegion + GestureDetector`. A keyboard user cannot approve *or deny*. `BeuiButton` (used by the sibling card) already has the full contract. → Route the actions through `BeuiButton`.

**A3 — P0 — No risk/destructive differentiation exists in the API.** No `risk`/`severity`/`destructive` parameter; `rm -rf ~/project` and `ls` render byte-identically. → Severity enum: `triangle_alert` glyph, tinted border/badge, demote Allow to outlined and promote Deny on the destructive tier, optionally suppress `Always allow`.

**A4 — P0 — The action row stays hit-testable through its 220 ms exit → double-fire.** `tool_approval.dart:976` (`ignoring` driven by the animation value, not `visible`); same shape at `approval_card.dart:1720`. A fast double-tap fires `onApprove` twice, the second after the decision. → `ignoring: !visible || hidden`.

**A5 — P1 —** Allow/Deny render and silently no-op when handlers are null (codified by a test). **A6 — P1 — Visual weight inverts safety**: max-emphasis `Allow once` (≈16:1 solid), outlined `Always allow` (the most consequential grant), ghost `Deny` last and faintest. **A7 — P1 —** three of four status badges fail AA in light mode (pending 2.84:1, approved 3.20:1, denied 3.74:1 at 11 px; dark is fine). **A8 — P1 —** stacked alpha on `mutedForeground` puts the tool slug — the string identifying *what ran* — at 2.29:1 in both modes (table of 6 sites). **A10 — P1 —** an expandable card built with only `expandedChild` shows a chevron over a legitimately blank body. **A11 — P1 —** only the 20×20 chevron toggles expansion; every sibling makes the whole header the trigger. **A12 — P1 —** `_ExpandableBody` instantiates both children twice (offstage measure + render) — a `BeuiInput` in `expandedChild` becomes two divergent `EditableText` states with two `FocusNode`s (the agent-theme demo does exactly this). **A16 — P1 —** reduced motion hard-cuts all five disclosures (Offstage/heightFactor swaps, no opacity), against the project's own rule. **A20 — P1 — `BeuiAgentActivity` has no failure state** — a crashed run summarises as "Ran 3 tools". **A21 — P1 —** no timeout/expiry/revocation anywhere in five status enums. **A22 — P1 —** tool output scrolls with zero affordance (scrollbars explicitly off, no fade — `agent_activity`'s fade mask is 200 lines away). **A23 — P1 —** the approval details panel is unbounded — a 300-line diff expands the card indefinitely (siblings cap; this one doesn't). **A26 — P1 —** Deny vs Reject vs Cancelled across three siblings. **A27 — P1 —** 40 hardcoded English strings; unusable outside English; → `BeuiAgentStrings` role. **A30 — P1 — the terminal outcome is never announced** — `liveRegion` is gated on the busy state in all three status components, switched off exactly when "Failed"/"Denied" arrives. **A31 — P1 —** touch targets 16–28 px (measured table); only `BeuiTodoList`'s 44 px header passes. **A32 — P1 —** the activity summary trigger is focusable but has no role/label/expanded state. **A33 — P1 —** zero semantics/contrast/tap-target assertions repo-wide (verified — see T11). **A36 — P0 for the theming layer — `BeuiAgentTheme` has no colour roles, and the palette tokens that exist are ignored**: 50 hardcoded `Color(0xFF…)` literals across five widgets, disagreeing with `BeuiColors.success/warning/destructive` (comparison table in source report); exactly one line reads a palette token for status, and it disagrees with the badge two lines away. A consumer cannot retheme agent status colour at all. → `BeuiAgentStatusColors` role (per-status fg/bg/border, light+dark). **A37 — P1 —** theme consumption is 6/4/4 roles in `approval_card` vs **0/0/0** in `agent_activity` (usage matrix in source report); the apply-test only exercises two widgets. **A38 — P1 —** `emphasisBorderWidth` and `useGlassSurfaces` are dead in this cluster; three different card treatments in one transcript. **A40 — P1 —** `BeuiTodoList` null-asserts the theme extension (`todo_list.dart:231`) while all four siblings fall back gracefully — a published package crashing on a consumer's theme.

P2 (abridged): the "View details" gateway is a ~16 px caption-styled row; the tool identity is styled as the least important string on the approval card; the seven-element result header collapses badly under 400 px; `tool_result`'s press scale is 0.9 (everything else 0.97); per-frame `Opacity` over syntax-highlighted subtrees forces saveLayers, and the todo status icon nests five `SingleMotionBuilder`s per row; decision exit animates height where the source is opacity-only (acknowledged in a comment); a working activity panel always reserves full `maxHeight` (208 px of blank for one item); no representation of concurrent tool calls; the todo empty state is a shrug ("No tasks yet"); sentence assembly around interpolated variables blocks localization; no dark-mode test despite `isLight` branches; no goldens for any of the five; motion tokens (`220/140 ms`) declared five times beside five near-identical `_AgentDisclosure` copies; `Object`-typed `tool/title/description` props (`tool: 42` compiles); `defaultOpen` inconsistent across the transcript; approve-vs-always-allow indistinguishable after the fact.

### Genuinely good (protect)
Redundant status encoding everywhere (shape + colour + text; geometric todo marks; signed diff counts) — colourblind-safe by construction; `BeuiApprovalCard`'s expand control is the pattern (semantics + keyboard + the cluster's only real reduced-motion test); `_ExpandableBody`'s spring-height interruptibility (explicitly tested); motion discipline (exits 140 < entrances 220, everything < 300 ms, press 100–160 ms); the 44 px todo header; consistent controlled/uncontrolled parity; the status-morph painters (real craft, per-spec `CustomPaint`); fidelity commentary that makes the port auditable; `_hlJson`'s exact-colour regression test.

---

## Cluster 4 — Rich content & shell (38 findings: 2 P0 · 15 P1 · 21 P2)

### Flow map

**`BeuiCitations`** — inline superscript pills (16×16, raised 2 px) + a collapsible "Sources · N" panel (rows: 20 px favicon → title → domain → index chip → link glyph). Rows stream in (180 ms fade + 6 px spring rise); disclosure 220/140 ms; a global `_CitationAnchors` registry makes inline markers scroll the ancestor scrollable to their row (`ensureVisible`, 280 ms). Favicon falls back to a globe on failure. No error/empty/visited states.

**`BeuiCodeBlock`** — rounded-16 card, 40 px chrome (file glyph, filename, language, status, 28 px copy). streaming = blue "Writing" + spinner + liveRegion; complete = emerald "Ready" + check. Copy → check for 1600 ms. Viewport capped 280 px, scrollbars off; `wrap: false` puts each line in a nested horizontal scroller (gutter scrolls away with it); auto-follows the live edge.

**`BeuiFileDiff`** — header (path, `+N` emerald / `−N` rose with a true Unicode minus, status, chevron) over a 4-column body (old gutter 36 / new gutter 36 / marker 16 / code) with row tints @ 0.07 alpha. Streaming auto-opens; complete **auto-collapses** by default. 220 px cap, vertical only — **no horizontal scroll**.

**`BeuiImageGeneration`** — `AspectRatio`-reserved frame with a five-phase pipeline (queued/generating/refining/complete/error) driving blur/saturation/opacity/scale over 400 ms, a rotating 2×2 dither mark (2.4 s), a per-frame-painted dither field, status row + quoted prompt, retry on error. Zero layout shift between phases (except the error branch, which appends 52 px).

**`BeuiAiSidebar`** — flat-rendered resource tree (16 px indent/depth, 36 px rows, hover marquee on overflow, 28 px ⋯ menu). Full keyboard model: arrows, Home/End, expand/collapse/escape-to-parent, F2 rename, Shift+F10 menu, Alt+Shift moves with optimistic apply + rollback + announcements. Renders no scroll container of its own.

**`BeuiPreviewRail`** — a stack of unlabeled 48×2 px ticks (rest scale 0.25) that swell near the pointer; a preview card glides along the rail on `beuiSpringLayout`, content cross-fading 180/120 ms with unblur. Selection has no visual by default (`highlightActive` opt-in). Golden confirms the resting truth: four grey dashes on an empty canvas.

### Findings

**R1 — P0 — The file diff truncates wide lines with an ellipsis and no horizontal scroll.** `file_diff.dart:912-913`; ~260 px of code on a phone bubble after 88 px of gutters. Approving an agent's edit is the highest-stakes action in the client, and this hides the part of the line that changed. `BeuiCodeBlock` solves it 40 lines away. → Mirror the code-block pattern; add `wrap`, defaulting on below ~480 px.

**R2 — P0 — The preview rail is non-functional on touch and unlabeled everywhere.** Hover-only reveal (`preview_rail.dart:301, 638-663`); tap navigates immediately to a destination the user could not identify; golden shows the entire nav as four anonymous dashes. → Tap-to-preview / tap-again-to-commit on non-hover pointers (or a labeled-list fallback); default `highlightActive: true`.

**R3 — P1 —** url-only citation rows get a click cursor, link glyph, and button semantics — and do nothing when activated (the doc's "we don't launch URLs" makes this the default path). **R4 — P1 —** keyboard focus is invisible on every sidebar row (`focused` is threaded and never read). **R5 — P1 —** selected and hovered rows are the same `muted` fill — selection disappears under the pointer. **R6 — P1 —** the `ring` token composites to 1.30:1 light / 1.31:1 dark and is consumed as the focus ring at four sites — a hairline-border token doing a focus-indicator's job (→ dedicated `focusRing` role). **R7 — P1 —** streaming auto-scroll yanks the reader to the live edge on every change with no scrolled-away escape (code block + diff). **R8 — P1 —** line-number gutters at 1.63:1 (code) / 1.78:1 (diff) in both themes — the cross-reference channel for "I changed line 19" is unreadable. **R9 — P1 —** the two elements that make a source verifiable — domain (2.55:1) and link glyph (1.79:1) — are the least legible things in the citation row. **R10 — P1 —** citation rows have no perceptible hover affordance (a foreground@0.8→1.0 title shift). **R11 — P1 —** the rail sizes to content and overflows its parent both ways (14 items = 336 px, no clamp; 20 horizontal items = RenderFlex overflow on a phone). **R12 — P1 —** code/diff viewports scroll with scrollbars explicitly off and zero edge hint — a 400-line file reads as 14 lines that end mid-statement (the sidebar demo's bottom fade is the in-repo pattern). **R13 — P1 —** image generation shows phase but never progress (four words + a 2.4 s spinner across a 10–60 s operation — canonical "is it frozen?") and cannot be cancelled. **R14 — P1 —** touch targets 16–36 px (worst: the 16 px inline citation marker — the primary verify affordance in prose). **R15 — P1 —** the sidebar ⋯ is `Opacity(0)` on touch but still hit-testable — a permanently invisible button at the end of every row — while rename has no touch entry point at all. **R16 — P1 —** caller-supplied `BeuiCitation.index` vs positional row chips can silently desync under streaming append/filter — marker [2] pointing at row 3. **R17 — P1 —** end-ellipsis on paths destroys the basename (`…/compon…`) — middle-truncate.

P2 (abridged): reduced motion drops opacity channels it should keep (image reveal hard-cuts; citation rows appear bare) — the split-channel fix already exists in `preview_rail`; diff add/remove tints are 1.04:1 apart, resting everything on a 12 px glyph whose own contrast is 3.38–4.19:1 (raise tints, add a leading colour bar); `highlightLines` produces a 1.08:1 wash with no second cue; `collapseOnComplete` hides the finished diff *and* its copy button at the moment of interest (move copy to the header); no hunk model / context expansion / change navigation for diffs beyond ~30 lines; the hover marquee loops on the highest-frequency interaction in the tree and re-measures every frame (delay + one pass, or tooltip); 52 px layout shift on image error (reserve the slot); `destructive` is 3.94:1 in light mode; empty states unhandled ("Sources 0", a blank numbered line, a zero-height sidebar — only the rail handles it); focusing an inline marker reflows the paragraph (border-in-layout again); copy confirmation is visual-only and unannounced; disabled sidebar rows compound two dimming mechanisms to ~1.42:1; the dither field `setState`s every frame (~484 circles at 208², ~2 700 at 500² — several concurrent generations will jank); rail ticks abut at 0 px so a pointer sweep re-fires the spring cascade continuously; the preview card is `IgnorePointer` but `renderPreview`'s docs don't say so; `_AgentDisclosure` and the ~180-line highlighter are duplicated byte-identical between citations/diff and code block/diff — **and the two diff-language branches have already diverged** (different colours for `+`, `@@` handled in one copy only); the sidebar neither scrolls nor documents that the consumer must provide the viewport; `copyText` makes consumers re-serialise a diff the widget already holds (control silently disappears if forgotten); `filename`/`file` typed as `Object?`; `itemSize` vs deprecated `trackExtent`; `defaultActiveId` never reconciled in `didUpdateWidget` and selection fallback fires no `onActiveChange`.

### Genuinely good (protect)
The syntax palette (Shiki `github-*-high-contrast`, verified 7.2–13.4:1 light / 8.1–11.9:1 dark, a real light/dark split); `AspectRatio`-reserved image frames — zero layout shift across five phases, the hardest streamed-content problem solved correctly; redundant diff encoding structure (signed markers, Unicode minus, tabular gutters); `preview_rail`'s reduced-motion split (snap movement, keep fade) — the template for fixing the rest; the sidebar's near-native tree keyboard model (needs only a visible ring); the `_CitationAnchors` registry (hash-links done right, with post-frame retry and prefix-scoped cleanup); streaming `liveRegion`s + `ExcludeSemantics` on decoration; load-bearing layout comments that will stop regressions.

---

## Prioritized roadmap

### Fix now (P0 + gate)
1. **Restore compile at HEAD** — replace `LucideIcons.history` (`wallet_card/search_bar.dart:286`); nothing else is verifiable in CI until this lands.
2. **`BeuiToolApproval` trust pass** (one file): details open by default when parameters exist; actions through `BeuiButton` (keyboard + focus); a severity tier; `ignoring: !visible` on the exiting action row. (A1–A4)
3. **Failure honesty**: distinct error affordance in `BeuiStreamingResponse` + a `stopped` status; an error state for `BeuiAgentActivity`. (C1, C13, A20)
4. **Focus ring**: a dedicated ≥3:1 `focusRing` colour role; paint rings outside layout. Fixes six call sites across three clusters. (C2, R6)
5. **`BeuiFileDiff` horizontal scroll / wrap**; **preview-rail touch + labels**; **keyboard for the composer menus and `BeuiFileUpload`**; **width clamp in `BeuiMessageBubble` + a `BeuiChatApp` breakpoint**. (R1, R2, I2, I14, C3)

### Next (P1 themes, batched by root cause)
- **Contrast batch**: stop alpha-multiplying information-bearing `mutedForeground`; lift light-mode status badge foregrounds to a 700-tier; fix outline/danger bubbles, gutters, citation domains, placeholders. One sweep, one review. (T3)
- **Announcement batch**: hold `liveRegion` through terminal transitions; announce Copied/Sent; collapse the transcript to one debounced live region; button semantics on interactive bubbles. (T7, C6, C7)
- **Streaming-follow batch**: `jumpTo` when growth outpaces animation; user-pinned escape + "jump to latest" pill; heightFactor on the actions reveal. (T5, C4, C5, C10, R7)
- **Hit-slop batch**: 44 px hit areas over existing visuals, library-wide. (T9)
- **`BeuiAgentTheme` colour roles** (`BeuiAgentStatusColors` + `BeuiAgentStrings`), consumed by all five agent widgets; reconcile with `BeuiColors.success/warning/destructive`. (A36, A37, A27)
- **Composer product gap**: attachment chip rail + `onAttachmentRemoved` + widened `onSubmit`; real `progress` on attachment items; cancel-in-flight. (I11–I13)
- **Reduced-motion conformance pass** on the agent disclosures, citations, and image reveal using the existing `motionFor` channel split. (T4)

### Then (P2 / systemic)
- Extract one shared `BeuiAgentDisclosure` and one highlighter; unify refusal vocabulary and `defaultOpen` policy; single press-scale token. (T8)
- Scroll affordances: fades + "N more lines" on capped viewports; rail pitch compression. (T6)
- Gallery pass: error/stopped/variant routes, remove dead controls and token-bypassing overrides, keyboard-correct demo patterns. (T10)
- Test gate: adopt `meetsGuideline` (contrast + labeled-tap-target) per the spec, add dark-mode and keyboard matrices, goldens for the conversation/agent clusters, and spec Part B rows for the agent components. (T11)
- RTL sweep (directional alignment/borders/insets) and the localization surface. (C17, A27)

---

## Appendix — verification notes

- **Resolved contradiction:** one auditor claimed 20+ suites use `matchesSemantics`; another claimed zero. Orchestrator grep confirms: 12 suites call `tester.ensureSemantics()` and 17 files assert via `find.bySemanticsLabel`, but there are **0** occurrences of `matchesSemantics`/`meetsGuideline`/`textContrastGuideline`/`labeledTapTargetGuideline` under `test/`. The "no guideline gate" claim stands; the "20+ suites" claim referred to semantics *enabling*, not guideline assertions.
- **Compile break verified:** `LucideIcons.history` is referenced at `lib/src/motion/wallet_card/search_bar.dart:286`; the resolved `flutter_lucide` is 1.31.0 (pubspec constraint `>=1.11.0 <2.0.0`) and its icon file defines no `history` constant. `flutter test` fails to load at HEAD.
- **Independently corroborated findings** (found by ≥2 agents without shared context): the 1.3:1 `ring`-as-focus-ring token; disabled scrollbars with no affordance; reduced-motion hard cuts in disclosures; sub-44 px targets; alpha-multiplied `mutedForeground` contrast failures; streaming auto-follow fighting the reader.
- **Limits of this audit:** code-and-goldens only — the example app was not run, so timing *feel* (as opposed to token values) and real screen-reader output were not empirically tested. No golden exists for any conversation-core or agent-cluster component, so those clusters had no rendered-pixel evidence available.
