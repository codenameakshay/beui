# Integrated component verification

Root suite:2609 passes and56 golden failures. Failure identities exactly match the previous calendar integration run, with no new or removed failures. Gallery:66 passes. Goldens ran unsuppressed and were not updated.

The six source/test hashes in the input manifest remained unchanged through both runs. These inputs contain reviewed Sortable, FileTree and MultiSelect repairs. Native fixture captures were isolated component builds, not this combined gallery build; no combined native, hosted-CI or exact-parity claim follows from these tests.
