# Required route videos and verdicts

All 19 required routes have a hash-verified candidate screenshot recording. Every verdict remains unverified for exact parity. A dispatched action is not proof of the expected visible result. `scope.json` preserves the complete audit-derived route, public-widget, example, and state inventory.

The [round2 video and flow report](round2/README.md) adds labeled repairs, paired card/feedback/chips flows, held down/move/up footage, observed Flutter reduced motion and secondary-example footage.
It preserves the following round1 index and its failures. No original obligation is relabeled as complete.

The first five rows use `recovered-dark`. Other rows use `recovered-expanded`. The final Market Card recording uses `recovered-focus-ring`. Each recording directory has `capture.mp4`, untouched `original-frames`, `timeline.json`, `environment.json`, and the actual config. Adjacent logs preserve failures. The MP4 is derived from timestamped PNGs without interpolation.

| Required route | Public widgets covered by route | Candidate video | Exercised protocol | Remaining evidence gaps |
| --- | --- | --- | --- | --- |
| Card Folder | BeuiCardFolder | [Video](recovered-dark/candidate-card-folder/capture.mp4) | Privacy reveal and hide, pointer open, Enter, leave | Nonzero image and motion diagnostics. Light, effective reduced motion, overflow menu, exact focus and timing comparison remain. |
| Morphing Tabs | BeuiMorphingTabs | [Video](recovered-dark/candidate-morphing-tabs/capture.mp4) | General hover and selection, arrow reversal, close Archive, leave | Drag reorder, all close policies, themes, effective reduced motion, paired focus and exit measurements remain. |
| Prediction Market Card | BeuiPredictionMarketCard | [Final video](recovered-focus-ring/candidate-prediction-market-card/capture.mp4) | Celtics to Lakers hover, payout hover, leave, Lakers click and Enter, update odds | Exact payout placement and text timing, bookmark, all examples, light and effective reduced motion remain. |
| Number | BeuiDigitSwap, BeuiAnimatedNumber, BeuiNumberTicker | [Video](recovered-dark/candidate-number/capture.mp4) | Repeated Digit Swap Animate and Enter | Footage shows Digit Swap only. Animated Number, Number Ticker, all formatting, light and reduced-motion states remain. |
| Text Animation | BeuiTextScramble, BeuiChromaticTextReveal, BeuiTextReveal, BeuiTextShimmer, BeuiTextCascade | [Video](recovered-dark/candidate-text-animation/capture.mp4) | Next phrase, interruption, repeat, Enter | Footage shows Scramble only. Other four widgets and all examples remain. Exact randomized glyph comparison is not established. |
| Project Folder | BeuiProjectFolder | [Video](recovered-expanded/candidate-project-folder/capture.mp4) | Hover, leave, click, Escape | All file previews, drag, keyboard entry, themes, reduced motion, and matching source motion remain. |
| Notification Stack | BeuiNotificationStack | [Video](recovered-expanded/candidate-notification-stack/capture.mp4) | Hover, leave, expand, Tab | Dismissal, action callbacks, all stack sizes and matching source focus remain. |
| Dynamic Island | BeuiDynamicIsland | [Video](recovered-expanded/candidate-dynamic-island/capture.mp4) | Call, Timer, Music, Dismiss | All variants, interruptions, source trajectories, themes, and reduced motion remain. |
| Availability Scheduler | BeuiAvailabilityScheduler | [Video](recovered-expanded/candidate-availability-scheduler/capture.mp4) | Add Monday range, copy menu, Escape | Copy selection, disabled days, range editing, validation and exact overlay geometry remain. |
| Morphing Search | BeuiMorphingSearch, BeuiMorphingSearchChips | [Video](recovered-expanded/candidate-morphing-search/capture.mp4) | Open, type folder, ArrowDown, Enter, Escape | Both source examples, query reset, shortcut entry, selection outcome and matched transition measurement remain. Chips has a separate row. |
| Morphing Search Chips | BeuiMorphingSearchChips | [Video](recovered-expanded/candidate-morphing-search-chips/capture.mp4) | Focus, type dark, Enter, Escape | Chip removal, suggestion selection, persistence, no-results, all source examples and exact motion remain. |
| Prediction Market | BeuiPredictionMarket, BeuiPredictionMarketCard | [Video](recovered-expanded/candidate-prediction-market/capture.mp4) | Listing CTA hover transfer, leave, odds update | Footage shows listing. The independently installable trade ticket and submit flow are not certified. |
| Wallet Card | BeuiWalletCard | [Video](recovered-expanded/candidate-wallet-card/capture.mp4) | Hide and show balance, account, Escape, balance update | Account selection, chart hover, actions, animated readout, themes and reduced motion remain. |
| Bloom Menu | BeuiBloomMenu | [Video](recovered-expanded/candidate-bloom-menu/capture.mp4) | Open, Escape, reopen, outside click | Each item action, focus trap, keyboard traversal, touch and exact enter and exit timing remain. |
| Feedback Widget | BeuiFeedbackWidget | [Video](recovered-expanded/candidate-feedback-widget/capture.mp4) | Open, Escape, reopen, Tab | Complete rating and text submit, success, repeated submission, themes and reduced motion remain. |
| Dock | BeuiDock | [Video](recovered-expanded/candidate-dock/capture.mp4) | Home to Music to Settings hover, leave, click, Tab | Grouped variants, separators, active pill, exact pointer-follow and tooltip text timing remain. |
| Knockout Bracket | BeuiKnockoutBracket, BeuiKnockoutWheel | [Video](recovered-expanded/candidate-knockout-bracket/capture.mp4) | Final fixture hover, leave, click, Tab | Footage shows bracket. Wheel, fixture data replacement, all examples and keyboard semantics remain. |
| Signup Form | BeuiSignUpForm | [Video](recovered-expanded/candidate-signup-form/capture.mp4) | Rest and two Tab events only | Recovered video is not a form-flow test. Earlier action attempts remain in before and after interaction reports. Valid submit, validation, reveal, focus, light and reduced motion remain. |
| Infinite Masonry | BeuiInfiniteMasonry | [Video](recovered-expanded/candidate-infinite-masonry/capture.mp4) | Rest and pointer movement only | Recorder lacks wheel events. This is not scrolling proof. Virtualization, image load, scroll reversal, all examples and reduced motion remain. |

## Reference and before videos

The preserved first seven source and baseline sequences are in `before/interactions/{reference,candidate}/<slug>/interaction.webm`. Expanded block sequences are in `before-expanded-actions/interactions/{reference,candidate}/<slug>/interaction.webm`. Reports retain locator and navigation errors.

The valid source component routes are `/components/motion/dock`, `/components/motion/number`, and `/components/motion/text-animation`. Their corrected rest references are under `before-motion-routes/reference`. Invalid attempts are listed in [Invalid and inconclusive captures](INVALID-CAPTURES.md).

Recovered source action videos for Card Folder, Morphing Tabs, Market Card, Number, and Text Animation are `recovered-dark/reference-<slug>/capture.mp4`. Their deployed revision is unknown. Their local source checkout is pinned separately.

## Labeled change videos

- [Card Folder](change-videos/card-folder.mp4).
- [Morphing Tabs](change-videos/morphing-tabs.mp4).
- [Market Card before and final focus-ring implementation](change-videos-focus-ring/prediction-market-card.mp4).
- [Digit Swap](change-videos/number.mp4).
- [Text Scramble](change-videos/text-animation.mp4).

The viewing edit retains the complete original baseline recording, including page loading, before showing the repaired capture. It labels the different stage wrapper. The manifests verify exact input and output frame-count totals. These edits are not synchronized image or motion comparisons.
