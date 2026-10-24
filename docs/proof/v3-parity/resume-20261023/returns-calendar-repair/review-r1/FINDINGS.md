# Independent review round one

Three demonstrated P2 findings block acceptance of the first patch:

- Old cell disposal unconditionally deletes a replacement cell's same-key focus registration. Identity-guarded removal passes the isolated reproduction.
- Temporary GlobalKey reparenting deactivates retained cells and incorrectly drops focus. Original passes; first patch fails.
- Duplicate year rows now throw duplicate-key errors. Original renders and public API does not require unique years. Pinned source duplicate-year behavior is not established.

Whole-widget teardown and external focus preservation checks pass. Original before archive and first patch native evidence remain valid within their narrower forward-traversal scope. These findings are not contradicted by the existing regression tests or the parent292-pass chart gate with goldens disabled.
