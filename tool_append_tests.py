"""Appends a block of test groups inside an existing suite's main().

Temporary scaffolding for the UX-remediation work; deleted once the tests land.
Usage: python3 tool_append_tests.py <test_file> <block_file>
"""

import sys

target, block = sys.argv[1], sys.argv[2]
source = open(target).read().rstrip()
addition = open(block).read()

assert source.endswith("}"), "expected the suite to end with main()'s brace"
source = source[: source.rfind("}")] + addition
open(target, "w").write(source)
print(f"appended {len(addition)} chars to {target}")
