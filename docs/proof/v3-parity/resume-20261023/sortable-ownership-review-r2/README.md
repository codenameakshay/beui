# Sortable ownership review

Independent review accepts the bounded handle ownership correction. Original reviewer probes pass10/10; final focused non-golden tests pass36/36; unchanged-dependency reactivation passes1/1. The same final tests against the broken input produce29 passes and7 failures. Tests ran on Flutter3.47.1/Dart3.13.1.

Production SHA-256: `083f0b5b6a479d249c14050713186b23418ce449710d4e7f03f715a834994c98`.
Test SHA-256: `1480670bd61883ef1a7deb14eb6add4050cf72b161767a4fe04ba06bae3666ad`.

This accepts Undo eligibility, restored-item focus and per-mounted-handle ownership at the widget layer. Native reordering still loses focus during Flutter semantics DOM moves. Uninterrupted keyboard input remains broken. No exact parity, golden, screen-reader or native60 acceptance is implied.

Upstream issue: https://github.com/flutter/flutter/issues/194550 . Read-only research found no supported fix in inspected3.47.1 through3.47.8 or main457d49bc600142ecb927f382cf20a728af186ea7. A framework/engine repair still needs independent implementation and native verification. Diagnostic layouts that remove drag support are not production alternatives.
