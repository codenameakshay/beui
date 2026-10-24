# Final analysis and formatting gates

User step 3: whole-tree flutter analyze passes after excluding docs/proof/** through analysis_options.yaml. Archived fixtures were not modified. The four flagged non-archive Dart files were formatted with the installed SDK. Package formatting checks 414 files with zero changes; example formatting checks 158 with zero changes.

The formatter does not honor analyzer exclusions. Package CI now checks lib, test and tool explicitly; the separate example job still checks its entire tree. This preserves archived source bytes rather than rewriting proof inputs. Prior hosted PR26 failures were formatting; their logs are retained. Hosted results for this change remain pending.

No behavioral implementation or golden change is included. Root dart format . still visits archived fixtures and is not the CI command. Whole-tree analysis remains the CI analysis command.
