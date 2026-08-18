"""Balances the extra nesting level added by the hit-target hoist."""


def patch(path, pairs):
    s = open(path).read()
    for old, new in pairs:
        assert old in s, f"{path}: {old[:100]!r}"
        s = s.replace(old, new, 1)
    open(path, "w").write(s)
    print("patched", path)


patch(
    "lib/src/motion/ai_sidebar.dart",
    [
        (
            """            ),
            // The semantics node sits *outside* the IgnorePointer, so the
            // action stays available to assistive technology even in the frame
            // where the glyph is invisible to a pointer.
            // Outermost, so the 44px slop clears the 28px paint. The
            // semantics node sits inside it but outside the IgnorePointer, so
            // the action survives the frame where the glyph is invisible.
            child: BeuiMinHitTarget(""",
            """            ),
            // Outermost, so the 44px slop clears the 28px paint. The semantics
            // node sits inside it but outside the IgnorePointer, so the action
            // stays available to assistive technology even in the frame where
            // the glyph is invisible to a pointer.
            child: BeuiMinHitTarget(""",
        ),
        (
                    """                  ),
                ),
              ),
            ),
          )
        : const SizedBox(width: 28, height: 28);""",
                    """                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox(width: 28, height: 28);""",
        ),
    ],
)

patch(
    "lib/src/motion/_viewport_follow.dart",
    [
        (
            """                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Opacity is kept under reduced motion; only the 4px rise is dropped.""",
            """                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Opacity is kept under reduced motion; only the 4px rise is dropped.""",
        )
    ],
)
