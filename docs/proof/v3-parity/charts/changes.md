# Chart change text

These captions describe the implementation changes for the parent's before/after video assembly. They are not parity verdicts.

| Widget | Before | After | Video |
| --- | --- | --- | --- |
| Candlestick | No price-axis ticks or pointer-price readout. Geometry uses a 58px gutter and 78% price region. | Five midpoint ticks, 64px gutter, source price/volume allocation, horizontal pointer crosshair and price tag. Click takes focus. Blur, keyboard, and exit clear pointer state. Pause/Resume and Step drive source trades. | `after-final/candlestick-chart/interaction.webm` |
| Bump | Dots and end labels add the top inset twice and miss their paths. Five ranks use a 300px plot. | Source 560 by 240 viewBox geometry aligns paths, dots, and labels. Markers have source outlines. Tooltip adds previous rank and Up/Down/No change. Shuffle keeps rank permutations. | `after-final/bump-chart/interaction.webm` |
| Donut | Rounded caps cover the intended arc gaps. Demo selection does not report filtering. | Cap-aware arc insets preserve the gaps. Plan selection reports filtering and clears on repeated selection. | `after-final/donut-chart/interaction.webm` |
| Volume profile | Value area grows beyond its target and excludes empty edge bins at 100%. Session tabs are absent. | Expansion stops before overshoot, resolves ties by distance then higher price, and includes all bins at 100%. Today/Previous/Week use source observation arrays. | `after-final/volume-profile/interaction.webm` |
| Status bar | Only one history and no source replay or incident controls. | API and Website histories, Replay, Simulate incident, and Resolve incident. The incident changes the final three API observations. | `after-final/status-bar/interaction.webm` |
| Liquidity heatmap | Initial market price and band formula differ from the source. No Resimulate action. | Source phase-zero observations and a Resimulate action update the phase while retaining snapshot IDs. | `after-final/liquidity-heatmap/interaction.webm` |
| Order book | Static snapshot and no source live controls or selection readout. | Live depth updates at 950ms, Pause/Resume, Step, and selected-price readout with stable quote identities. | `after-final/order-book/interaction.webm` |
| Heat calendar | Demo forces a cyan color absent from the source. | Demo uses the chart's source-default accent. | `after-final/heat-calendar/interaction.webm` |
| Treemap | No slice change. | Audit and recordings only. | `after-final/treemap/interaction.webm` |
| Composition | No slice change. | Audit and recordings only. | `after-final/composition-chart/interaction.webm` |
| Funnel | No slice change. | Audit and recordings only. | `after-final/funnel-chart/interaction.webm` |
| Returns calendar | No slice change. | Audit and recordings only. | `after-final/returns-calendar/interaction.webm` |
| Price target fan | No slice change. | Audit and recordings only. | `after-final/price-target-fan/interaction.webm` |

For each row, the corresponding baseline is `before/<slug>/interaction.webm` and the live source is `reference/<slug>/interaction.webm`. All final recordings use the existing fixed-coordinate script and inherit the limitations in `README.md`. They are not evidence that every captioned action occurred in the recording. The dedicated recovery worker must record the missing semantic actions and add visible captions to the final comparison videos.
